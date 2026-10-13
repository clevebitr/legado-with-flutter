import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';

/// Applies one `crypto.*` binding call from the sandbox (`docs/dev/book-source.md` §6).
///
/// The four operations are pure computation, which is why §6 lists them as **sync**
/// bindings: the worker answers them inside its own isolate and JavaScript never
/// waits for the UI isolate. [operation] is the name used on the JS side; the result
/// is the value JavaScript receives.
///
/// `null` means “no value”: an unknown operation, or base64 that cannot be decoded or
/// is not UTF-8 afterwards. The prelude turns that into a JS `Error` instead of a
/// silently wrong string, which is what C-SRC-4 asks for at a binding boundary.
String? applyCryptoOperation(String operation, String value) =>
    switch (operation) {
      'md5' => md5.convert(utf8.encode(value)).toString(),
      'sha1' => sha1.convert(utf8.encode(value)).toString(),
      'base64Encode' => base64Encode(utf8.encode(value)),
      'base64Decode' => _decodeBase64(value),
      _ => null,
    };

/// Decodes base64 to text, or `null` when the input is not valid base64 / UTF-8.
///
/// Upstream (`java`-backed `crypto.base64Decode`) throws on malformed input; here the
/// throw happens on the JS side (see [applyCryptoOperation]) so the engine behaviour
/// stays out of it.
String? _decodeBase64(String value) {
  try {
    return utf8.decode(base64Decode(value));
  } on FormatException {
    return null;
  }
}

/// The binding name of `http.*` in a [JsHostCall] (`docs/dev/book-source.md` §6).
const String jsHttpBinding = 'http';

/// The binding name of `parse.*` in a [JsHostCall] (`docs/dev/book-source.md` §6).
const String jsParseBinding = 'parse';

/// The binding name of `java.*` (`docs/dev/book-source.md` §6).
///
/// Unlike [jsHttpBinding] and [jsParseBinding] it is **not** a [JsHostCall]: the worker
/// answers `java.put` / `java.get` inside its own isolate — that is what keeps them
/// synchronous (§6) and keeps the runtime's state out of `globalThis` (ADR-0030 §决策 4).
/// The name lives here so the prelude and the worker cannot drift apart.
const String jsJavaBinding = 'java';

/// One binding call the worker forwards to the host isolate (§6).
///
/// `http.*` and `parse.*` are the two bindings a rule **must** `await` (ADR-0029
/// §决策 3), because neither can be answered inside the worker: the request layer and the
/// rule engine both live on the host. The worker therefore forwards the call as this
/// envelope and leaves the script's Promise pending until a [JsHostReply] names the same
/// [callId] back.
///
/// [args] is what the sandbox passed, exactly as the prelude serialised it: the bridge is
/// the one that validates it (see [decodeJsHttpRequest] / [decodeJsParseRequest]), so the
/// worker stays a transport.
final class JsHostCall {
  /// Creates a host call.
  const JsHostCall({
    required this.callId,
    required this.binding,
    required this.args,
  });

  /// The per-job call number the reply has to name.
  final int callId;

  /// [jsHttpBinding] or [jsParseBinding].
  final String binding;

  /// The arguments the sandbox passed, unvalidated.
  final Object? args;

  /// The envelope the worker sends to the bridge.
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'host',
    'callId': callId,
    'binding': binding,
    'args': args,
  };

  /// Reads an envelope the worker sent, or `null` when it is malformed.
  static JsHostCall? fromJson(Map<String, Object?> message) {
    final Object? callId = message['callId'];
    final Object? binding = message['binding'];
    if (callId is! int || binding is! String) {
      return null;
    }

    return JsHostCall(callId: callId, binding: binding, args: message['args']);
  }
}

/// The host's answer to one [JsHostCall] (§6).
///
/// A **success** resolves the script's Promise with [value]. A **rejection**
/// ([JsHostReply.rejected]) rejects it with [message] and leaves the job's outcome to the
/// script, which is what a transport failure is: a rule may catch it and try the next
/// mirror. A **fatal** failure ([JsHostReply.fatal]) is one the job cannot survive — the
/// `parse.*` boundaries §6 registers, or the per-rule call quota — so the bridge fails the
/// job with [kind] / [rulePath] instead of letting the script turn it into a value
/// (C-SRC-4, ADR-0029 §决策 5).
final class JsHostReply {
  /// Creates a successful answer.
  const JsHostReply.success(this.callId, this.value)
    : isSuccess = true,
      fatal = false,
      kind = null,
      rulePath = null,
      message = null;

  /// Creates an answer that rejects the script's Promise but not the job.
  const JsHostReply.rejected(this.callId, this.message)
    : isSuccess = false,
      value = null,
      fatal = false,
      kind = null,
      rulePath = null;

  /// Creates an answer that fails the whole job (`js:parse-scope`, `js:quota`).
  const JsHostReply.fatal({
    required this.callId,
    required this.kind,
    required this.rulePath,
    required this.message,
  }) : isSuccess = false,
       value = null,
       fatal = true;

  /// The call this answers.
  final int callId;

  /// Whether the call produced a value.
  final bool isSuccess;

  /// The value the script's Promise resolves with, for a success.
  final Object? value;

  /// Whether the failure has to fail the job, not just the script's Promise.
  final bool fatal;

  /// The failure kind a [fatal] answer fails the job with; `null` otherwise.
  final ParseFailureKind? kind;

  /// The failing `rulePath` (field plus §6's marker) of a [fatal] answer.
  final String? rulePath;

  /// The JS-facing error text of a failure.
  final String? message;

  /// The envelope the bridge sends back to the worker.
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'hostResult',
    'callId': callId,
    'ok': isSuccess,
    'value': value,
    'fatal': fatal,
    'kind': kind?.name,
    'rulePath': rulePath,
    'message': message,
  };

  /// Reads an envelope the bridge sent, or `null` when it is malformed.
  ///
  /// A `fatal` envelope without a usable [kind] is treated as malformed rather than
  /// guessed: the worker never invents a failure kind.
  static JsHostReply? fromJson(Map<String, Object?> message) {
    final Object? callId = message['callId'];
    if (callId is! int) {
      return null;
    }
    if (message['ok'] == true) {
      return JsHostReply.success(callId, message['value']);
    }

    final String text =
        _stringField(message, 'message') ?? 'unknown host failure';
    if (message['fatal'] != true) {
      return JsHostReply.rejected(callId, text);
    }

    final ParseFailureKind? kind = _kindByName(
      _stringField(message, 'kind') ?? '',
    );
    final String? rulePath = _stringField(message, 'rulePath');
    if (kind == null || rulePath == null) {
      return null;
    }

    return JsHostReply.fatal(
      callId: callId,
      kind: kind,
      rulePath: rulePath,
      message: text,
    );
  }
}

/// The verbs `http.*` binds (§6).
///
/// §6 fixes a separate binding per verb, so `options.method` is not read: the binding a
/// rule called is the verb it gets.
enum JsHttpMethod {
  /// `http.get(url, options)`.
  get,

  /// `http.post(url, options)`.
  post,
}

/// One validated `http.*` call (§6).
///
/// `options` only carries `headers` and — for [JsHttpMethod.post] — `body`; every other
/// key is rejected by the prelude before the call is made, because silently dropping e.g.
/// `webView` would answer a different question than the rule asked.
final class JsHttpRequest {
  /// Creates a request.
  const JsHttpRequest({
    required this.method,
    required this.url,
    this.body,
    this.headers = const <String, String>{},
  });

  /// The verb the rule called.
  final JsHttpMethod method;

  /// The absolute-or-relative URL the rule asked for.
  final String url;

  /// The body of a POST; `null` for a GET or an empty form.
  final String? body;

  /// The headers the rule declared (`options.headers`).
  final Map<String, String> headers;
}

/// Reads one `http.*` call's arguments, or `null` when they are unusable (§6).
///
/// The arguments are the prelude's, so they are JSON: `{operation, url, options}`. A verb
/// or a URL that is not there, mid-type arguments, or headers that are not a flat string
/// map are all “malformed”, which the bridge answers with a rejected Promise rather than a
/// silent empty body.
JsHttpRequest? decodeJsHttpRequest(Object? args) {
  final Map<String, Object?>? call = _jsonObjectOf(args);
  if (call == null) {
    return null;
  }
  final JsHttpMethod? method = switch (call['operation']) {
    'get' => JsHttpMethod.get,
    'post' => JsHttpMethod.post,
    _ => null,
  };
  final Object? url = call['url'];
  if (method == null || url is! String || url.isEmpty) {
    return null;
  }

  final Object? rawOptions = call['options'];
  final Map<String, Object?>? options = rawOptions == null
      ? const <String, Object?>{}
      : _jsonObjectOf(rawOptions);
  if (options == null) {
    return null;
  }
  final Map<String, String>? headers = _headersOf(options['headers']);
  if (headers == null) {
    return null;
  }
  final Object? body = options['body'];
  if (body is! String?) {
    return null;
  }

  return JsHttpRequest(method: method, url: url, body: body, headers: headers);
}

/// The verbs `java.*` binds (`docs/dev/book-source.md` §6, matrix #17).
///
/// An unknown verb is answered with `ok:false` and the prelude turns that into a JS `Error`,
/// which is the explicit boundary C-SRC-4 asks for at a binding boundary.
enum JsJavaOperation {
  /// `java.put(key, value)`: writes the source's variable.
  put,

  /// `java.get(key)`: reads the source's variable.
  get,

  /// `java.timeFormat(time)`: formats a **milliseconds** timestamp (`book-source.md` §6).
  timeFormat,
}

/// One validated `java.*` call, decoded in the worker isolate (§6).
final class JsJavaRequest {
  /// Creates a request.
  const JsJavaRequest({required this.operation, this.key, this.value});

  /// The verb the rule called.
  final JsJavaOperation operation;

  /// The variable name of a [JsJavaOperation.put] / [JsJavaOperation.get].
  final String? key;

  /// The argument the rule passed.
  ///
  /// For a [JsJavaOperation.put] it is the value to write (`null` clears the variable); for
  /// [JsJavaOperation.timeFormat] it is the timestamp the rule asked to format, **not**
  /// coerced here, because a number and a numeric string are both legal and the type itself
  /// decides whether the call can be answered (`book-source.md` §6).
  ///
  /// It stays `Object?` — the JS bridge boundary C-TYPE-1 allows — and every reader narrows
  /// it before use.
  final Object? value;
}

/// Reads one `java.*` call's arguments, or `null` when they are unusable (§6).
///
/// The arguments are the prelude's, so they are JSON: `{operation, key, value}`. A missing or
/// non-string key on `put` / `get` and an unknown verb are "malformed", which the prelude
/// answers with a JS `Error` rather than a silent `undefined`. `timeFormat`'s argument is
/// deliberately **not** type-checked here: an unusable timestamp is a failed *call*, not a
/// malformed envelope, and [applyJsJavaCall] turns it into the same `ok:false`.
JsJavaRequest? decodeJsJavaRequest(Object? args) {
  final Map<String, Object?>? call = _jsonObjectOf(args);
  if (call == null) {
    return null;
  }
  final JsJavaOperation? operation = switch (call['operation']) {
    'put' => JsJavaOperation.put,
    'get' => JsJavaOperation.get,
    'timeFormat' => JsJavaOperation.timeFormat,
    _ => null,
  };
  if (operation == null) {
    return null;
  }

  final Object? key = call['key'];
  final Object? value = call['value'];
  switch (operation) {
    case JsJavaOperation.timeFormat:
      return JsJavaRequest(operation: operation, value: value);
    case JsJavaOperation.get:
      if (key is! String) {
        return null;
      }

      return JsJavaRequest(operation: operation, key: key);
    case JsJavaOperation.put:
      if (key is! String || value is! String?) {
        return null;
      }

      return JsJavaRequest(operation: operation, key: key, value: value);
  }
}

/// Applies one `java.*` call to a job's variable snapshot (`docs/dev/book-source.md` §6,
/// matrix #17) and answers the envelope the prelude reads.
///
/// The answer is **JSON text**, never a bare value: `java.put` has no value to return (§6
/// lists it as `void`), so `null` cannot mean “failed” the way it does for
/// [applyCryptoOperation]. The envelope says so explicitly — `{"ok":true,"value":…}` for a
/// read, `{"ok":true}` for a write, `{"ok":false}` for a malformed call — and the prelude
/// turns `ok:false` into a JS `Error` (C-SRC-4 at a binding boundary).
///
/// A `null` [JsJavaRequest.value] on a write **clears** the variable (upstream's
/// `putVariable(key, null)`, `RuleDataInterface.kt:8-14`); a read of a variable that was never
/// written answers an empty string, exactly like upstream's `AnalyzeRule.get`
/// (`AnalyzeRule.kt:812-825`), so a rule can concatenate it.
String applyJsJavaCall(Map<String, String?> variables, Object? args) {
  final JsJavaRequest? call = decodeJsJavaRequest(args);
  if (call == null) {
    return '{"ok":false}';
  }

  switch (call.operation) {
    case JsJavaOperation.get:
      // 解码器保证 `get` 带 String 键；这里再窄一次，是为了不把「契约被破坏」
      // 静默变成「读空串」（C-SRC-4：读不出来的调用就是失败）。
      final String? readKey = call.key;
      if (readKey == null) {
        return '{"ok":false}';
      }

      return jsonEncode(<String, Object?>{
        'ok': true,
        'value': variables[readKey] ?? '',
      });
    case JsJavaOperation.put:
      final String? writeKey = call.key;
      final Object? writeValue = call.value;
      if (writeKey == null || writeValue is! String?) {
        return '{"ok":false}';
      }
      variables[writeKey] = writeValue;

      return '{"ok":true}';
    case JsJavaOperation.timeFormat:
      final String? formatted = formatJsTimestamp(call.value);

      return formatted == null
          ? '{"ok":false}'
          : jsonEncode(<String, Object?>{'ok': true, 'value': formatted});
  }
}

/// Formats the timestamp one `java.timeFormat` call passed (`docs/dev/book-source.md` §6,
/// matrix #17), or `null` when the argument cannot be read as one.
///
/// The specification is upstream's `JsExtensions.timeFormat` (`:678`) plus
/// `AppConst.dateFormat` (`:40`): the argument is a **milliseconds** timestamp — a JS number
/// or a string that reads as one — the output is always `yyyy/MM/dd HH:mm`, and the zone is
/// the **device's local** one (`DateTime.fromMillisecondsSinceEpoch` is local by default,
/// like `FastDateFormat` reading the JVM default zone).
///
/// `null` means "this call cannot be answered": a missing / non-numeric / non-finite
/// argument, or a value outside Dart's own `DateTime` range. The caller turns that into
/// `ok:false`, which the prelude raises as a JS `Error` — the same loud boundary
/// [applyCryptoOperation] uses for base64 it cannot decode. A fractional number is truncated
/// towards zero, which is what a Java `(long)` conversion of a JS number does; a timestamp in
/// milliseconds never carries a fraction, so the choice cannot hide a wrong number.
String? formatJsTimestamp(Object? value) {
  final num? number = switch (value) {
    final int millis => millis,
    final double millis => millis,
    // JS 传字符串时前奏原样送过来（数字则保持数字），所以两种都要认。
    final String text => num.tryParse(text.trim()),
    _ => null,
  };
  if (number == null || (number is double && !number.isFinite)) {
    return null;
  }

  final num rounded = number is double ? number.truncate() : number;
  if (rounded > _maxDateTimeMilliseconds ||
      rounded < -_maxDateTimeMilliseconds) {
    return null;
  }

  return formatTimestamp(DateTime.fromMillisecondsSinceEpoch(rounded.toInt()));
}

/// Formats [instant] as `yyyy/MM/dd HH:mm`, the fixed pattern of `docs/dev/book-source.md` §6.
///
/// The zone is whatever [instant] carries: this is the pure half of the binding, so the
/// pattern can be pinned by a test without depending on the machine's locale or timezone.
String formatTimestamp(DateTime instant) {
  final String month = '${instant.month}'.padLeft(2, '0');
  final String day = '${instant.day}'.padLeft(2, '0');
  final String hour = '${instant.hour}'.padLeft(2, '0');
  final String minute = '${instant.minute}'.padLeft(2, '0');

  return '${instant.year}/$month/$day $hour:$minute';
}

/// Dart's `DateTime` range in milliseconds, i.e. ±100 000 000 days around the epoch.
///
/// It is checked before the conversion because `DateTime.fromMillisecondsSinceEpoch` reports
/// an out-of-range value as an `Error` (`RangeError`), which neither ADR-0022 nor C-ERR-2
/// allows this layer to catch — and an unanswerable timestamp is a failed call, not a crash.
const int _maxDateTimeMilliseconds = 8640000000000000;

/// Reads the variable table a job or a result carries, ignoring anything unusable (§6,
/// matrix #16 / #17).
///
/// Both directions use the same shape: the host seeds a job with a snapshot and the worker
/// reports its table back ([applyJsJavaCall] fills it), so one reader serves both ends and
/// the two can never disagree about what a `null` means. A `null` **value** is kept —
/// `java.put(key, null)` is how a script clears a variable, and turning it into `''` would
/// make “cleared” and “written empty” indistinguishable (ADR-0034 §决策 1). A key that is
/// not a string or a value that is neither a string nor `null` is dropped rather than
/// coerced: the store only ever holds strings, and a stringified `null` would be
/// indistinguishable from a rule that wrote the text "null".
Map<String, String?> decodeJsVariables(Object? value) {
  if (value is! Map) {
    return <String, String?>{};
  }
  final Map<String, String?> variables = <String, String?>{};
  for (final MapEntry<Object?, Object?> entry in value.entries) {
    final Object? entryKey = entry.key;
    final Object? entryValue = entry.value;
    if (entryKey is String && entryValue is String?) {
      variables[entryKey] = entryValue;
    }
  }

  return variables;
}

/// Reads one `parse.*` call's arguments, or `null` when they are unusable (§6).
///
/// `parse.getString` and `parse.getElements` differ only in whether the caller wants every
/// match or the first value ([JsParseRequest.wantsList]); `doc` is passed through
/// unvalidated, because what counts as a page-level document is the engine's decision
/// (`js:parse-scope`).
JsParseRequest? decodeJsParseRequest(Object? args) {
  final Map<String, Object?>? call = _jsonObjectOf(args);
  if (call == null) {
    return null;
  }
  final bool? wantsList = switch (call['operation']) {
    'getString' => false,
    'getElements' => true,
    _ => null,
  };
  final Object? rule = call['rule'];
  final Object? doc = call['doc'];
  if (wantsList == null || rule is! String) {
    return null;
  }
  if (doc is! String?) {
    return null;
  }

  return JsParseRequest(rule: rule, wantsList: wantsList, doc: doc);
}

/// Merges the book source's own headers under the rule's own (`book-source.md` §2).
///
/// Upstream builds a JS request from the source (`AnalyzeUrl`), so a source that declares
/// a `Referer` expects it there too; a header the rule named itself wins (C-NET-4).
Map<String, String> mergeJsHttpHeaders(
  Map<String, String>? sourceHeaders,
  Map<String, String> ruleHeaders,
) => <String, String>{...?sourceHeaders, ...ruleHeaders};

/// Reads a JSON object with string keys, or `null` when [value] is not one.
///
/// The sandbox hands its arguments over as decoded JSON, so every level is either a
/// `String`-keyed map or not an object at all; reading them through this helper keeps the
/// decoders free of raw-map indexing (and of `dynamic` calls).
Map<String, Object?>? _jsonObjectOf(Object? value) {
  if (value is! Map) {
    return null;
  }
  final Map<String, Object?> fields = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in value.entries) {
    final Object? key = entry.key;
    if (key is! String) {
      return null;
    }
    fields[key] = entry.value;
  }

  return fields;
}

/// Reads a flat string map, or `null` when [value] is not one.
Map<String, String>? _headersOf(Object? value) {
  if (value == null) {
    return const <String, String>{};
  }
  final Map<String, Object?>? fields = _jsonObjectOf(value);
  if (fields == null) {
    return null;
  }
  final Map<String, String> headers = <String, String>{};
  for (final MapEntry<String, Object?> entry in fields.entries) {
    final Object? headerValue = entry.value;
    if (headerValue is! String) {
      return null;
    }
    headers[entry.key] = headerValue;
  }

  return headers;
}

/// Reads a `ParseFailureKind` by name, or `null` when the name is not one.
ParseFailureKind? _kindByName(String name) {
  for (final ParseFailureKind kind in ParseFailureKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }

  return null;
}

/// Reads a `String` field of an envelope, ignoring a value of another type.
String? _stringField(Map<String, Object?> message, String key) {
  final Object? value = message[key];

  return value is String ? value : null;
}
