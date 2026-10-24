import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';

/// Applies one `crypto.*` binding call from the sandbox.
///
/// Returns `null` for an unknown operation or input that cannot be decoded.
String? applyCryptoOperation(String operation, String value) =>
    switch (operation) {
      'md5' => md5.convert(utf8.encode(value)).toString(),
      'sha1' => sha1.convert(utf8.encode(value)).toString(),
      'base64Encode' => base64Encode(utf8.encode(value)),
      'base64Decode' => _decodeBase64(value),
      _ => null,
    };

// 畸形输入在这里返回 null，由 JS 侧抛出；调用方只需处理"没有值"。
String? _decodeBase64(String value) {
  try {
    return utf8.decode(base64Decode(value));
  } on FormatException {
    return null;
  }
}

/// The binding name of `http.*` in a [JsHostCall].
const String jsHttpBinding = 'http';

/// The binding name of `parse.*` in a [JsHostCall].
const String jsParseBinding = 'parse';

/// The binding name of `java.*`, which the worker answers inside its own isolate.
const String jsJavaBinding = 'java';

/// The binding name of the verification family (`java.startBrowser*`, `java.getVerificationCode`,
/// `java.webView*`).
///
/// These calls **wait for a human** (ADR-0068 §决策 5), so they travel on their own channel: the
/// bridge does not count them against the per-rule call quota and does not let the job's wall-clock
/// budget expire while one is outstanding.
const String jsVerifyBinding = 'verify';

/// The verbs the verification channel binds.
enum JsVerifyOperation {
  /// `java.startBrowser(url, title[, html])`: opens the page, answers immediately.
  startBrowser,

  /// `java.startBrowserAwait(url, title[, refetchAfterSuccess[, html]])`.
  startBrowserAwait,

  /// `java.getVerificationCode(imageUrl)`.
  imageCode,

  /// `java.webView(url[, js])` / `java.webViewGetString(url[, js])`.
  webView,
}

/// One validated verification call, decoded on the host isolate.
final class JsVerifyRequest {
  /// Creates a request.
  const JsVerifyRequest({
    required this.operation,
    required this.url,
    this.title,
    this.html,
    this.script,
    this.refetchAfterSuccess = true,
  });

  /// The verb the rule called.
  final JsVerifyOperation operation;

  /// The address to open (`startBrowser*`, `webView*`) or the image (`imageCode`).
  final String url;

  /// The page title the rule passed (`startBrowser*`); falls back to the source name.
  final String? title;

  /// An HTML document to show instead of loading [url] (`startBrowser`'s third argument).
  final String? html;

  /// The script to run inside the rendered page (`webView*`'s second argument).
  final String? script;

  /// Whether `startBrowserAwait` should re-fetch over HTTP once the user finishes.
  final bool refetchAfterSuccess;
}

/// Reads one verification call's arguments, or `null` when they are unusable.
///
/// The arguments are JSON: `{operation, url, title, html, script, refetchAfterSuccess}`.
JsVerifyRequest? decodeJsVerifyRequest(Object? args) {
  final Map<String, Object?>? call = _jsonObjectOf(args);
  if (call == null) {
    return null;
  }
  final JsVerifyOperation? operation = switch (call['operation']) {
    'startBrowser' => JsVerifyOperation.startBrowser,
    'startBrowserAwait' => JsVerifyOperation.startBrowserAwait,
    'imageCode' => JsVerifyOperation.imageCode,
    'webView' => JsVerifyOperation.webView,
    _ => null,
  };
  final Object? url = call['url'];
  if (operation == null || url is! String || url.isEmpty) {
    return null;
  }
  final Object? title = call['title'];
  final Object? html = call['html'];
  final Object? script = call['script'];
  final Object? refetch = call['refetchAfterSuccess'];
  if (title is! String? || html is! String? || script is! String?) {
    return null;
  }
  if (refetch is! bool?) {
    return null;
  }

  return JsVerifyRequest(
    operation: operation,
    url: url,
    title: title,
    html: html,
    script: script,
    refetchAfterSuccess: refetch ?? true,
  );
}

/// One binding call the worker forwards to the host isolate.
///
/// The script's Promise stays pending until a [JsHostReply] names the same
/// [callId].
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

/// The host's answer to one [JsHostCall].
///
/// A success resolves the script's Promise, a rejection rejects it, and a fatal
/// failure fails the whole job.
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

  /// Creates an answer that fails the whole job.
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

  /// The failure kind of a [fatal] answer; `null` otherwise.
  final ParseFailureKind? kind;

  /// The failing `rulePath` of a [fatal] answer.
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
  /// A `fatal` envelope without a usable kind is malformed, never guessed.
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

/// The verbs `http.*` binds.
///
/// There is a separate binding per verb, so `options.method` is not read.
enum JsHttpMethod {
  /// `http.get(url, options)`.
  get,

  /// `http.post(url, options)`.
  post,
}

/// One validated `http.*` call.
///
/// `options` only carries `headers` and, for [JsHttpMethod.post], `body`.
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

/// Reads one `http.*` call's arguments, or `null` when they are unusable.
///
/// The arguments are JSON: `{operation, url, options}`.
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

/// The verbs `java.*` binds.
enum JsJavaOperation {
  /// `java.put(key, value)`: writes the source's variable.
  put,

  /// `java.get(key)`: reads the source's variable.
  get,

  /// `java.timeFormat(time)`: formats a milliseconds timestamp.
  timeFormat,

  /// `java.encodeURI(str)`: Java's `URLEncoder.encode(str, "UTF-8")`.
  ///
  /// Unlike JavaScript's `encodeURI`, a space becomes `+`.
  encodeUri,
}

/// One validated `java.*` call, decoded in the worker isolate.
final class JsJavaRequest {
  /// Creates a request.
  const JsJavaRequest({required this.operation, this.key, this.value});

  /// The verb the rule called.
  final JsJavaOperation operation;

  /// The variable name of a [JsJavaOperation.put] / [JsJavaOperation.get].
  final String? key;

  /// The argument the rule passed; `null` clears the variable on a write.
  final Object? value;
}

/// Reads one `java.*` call's arguments, or `null` when they are unusable.
///
/// The arguments are JSON: `{operation, key, value}`.
JsJavaRequest? decodeJsJavaRequest(Object? args) {
  final Map<String, Object?>? call = _jsonObjectOf(args);
  if (call == null) {
    return null;
  }
  final JsJavaOperation? operation = switch (call['operation']) {
    'put' => JsJavaOperation.put,
    'get' => JsJavaOperation.get,
    'timeFormat' => JsJavaOperation.timeFormat,
    'encodeUri' => JsJavaOperation.encodeUri,
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
    case JsJavaOperation.encodeUri:
      if (value is! String) {
        return null;
      }

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

/// Applies one `java.*` call and returns a JSON envelope.
///
/// A `null` value on a write clears the variable; a read of an unwritten variable
/// answers an empty string.
String applyJsJavaCall(
  Map<String, String?> variables,
  Object? args, {
  Map<String, String> named = const <String, String>{},
}) {
  final JsJavaRequest? call = decodeJsJavaRequest(args);
  if (call == null) {
    return '{"ok":false}';
  }

  switch (call.operation) {
    case JsJavaOperation.get:
      // 解码器保证 `get` 带 String 键；这里再窄一次，避免把契约破损静默变成读空串。
      final String? readKey = call.key;
      if (readKey == null) {
        return '{"ok":false}';
      }

      return jsonEncode(<String, Object?>{
        'ok': true,
        // 上游优先序：内置键（bookName / title）先答，再查变量表。
        'value': named[readKey] ?? variables[readKey] ?? '',
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
    case JsJavaOperation.encodeUri:
      return jsonEncode(<String, Object?>{
        'ok': true,
        'value': javaEncodeUri(call.value as String),
      });
  }
}

/// Reads the `bookName` and `title` built-in keys a job carries.
///
/// They stay apart from the variable snapshot so `java.put` cannot hijack them.
Map<String, String> decodeJsNamedContext(Map<String, Object?> fields) {
  final Map<String, String> named = <String, String>{};
  _putName(named, 'bookName', fields['bookName']);
  _putName(named, 'title', fields['chapterTitle']);

  return named;
}

void _putName(Map<String, String> named, String key, Object? value) {
  if (value is String && value.isNotEmpty) {
    named[key] = value;
  }
}

/// Encodes [value] the way Java's `URLEncoder.encode(value, "UTF-8")` does.
///
/// `A-Za-z0-9` and `-_.*` stay, a space becomes `+`, everything else `%XX`.
String javaEncodeUri(String value) {
  final StringBuffer buffer = StringBuffer();

  for (final int byte in utf8.encode(value)) {
    if (byte == 0x20) {
      buffer.write('+');
    } else if (_formSafeBytes.contains(byte)) {
      buffer.write(String.fromCharCode(byte));
    } else {
      buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }

  return buffer.toString();
}

// Java 表单编码不转义的字节：A-Za-z0-9 加上 -_.*。
final Set<int> _formSafeBytes = <int>{
  for (int code = 0x30; code <= 0x39; code++) code,
  for (int code = 0x41; code <= 0x5A; code++) code,
  for (int code = 0x61; code <= 0x7A; code++) code,
  0x2A, // *
  0x2D, // -
  0x2E, // .
  0x5F, // _
};

/// Formats the timestamp of one `java.timeFormat` call, or `null` when unreadable.
///
/// The argument is a milliseconds timestamp; the output is `yyyy/MM/dd HH:mm` in
/// the device's local zone.
String? formatJsTimestamp(Object? value) {
  final num? number = switch (value) {
    final int millis => millis,
    final double millis => millis,
    // JS 传字符串时前奏原样送来，数字则保持数字，所以两种都要认。
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

/// Formats [instant] as `yyyy/MM/dd HH:mm`.
String formatTimestamp(DateTime instant) {
  final String month = '${instant.month}'.padLeft(2, '0');
  final String day = '${instant.day}'.padLeft(2, '0');
  final String hour = '${instant.hour}'.padLeft(2, '0');
  final String minute = '${instant.minute}'.padLeft(2, '0');

  return '${instant.year}/$month/$day $hour:$minute';
}

// DateTime.fromMillisecondsSinceEpoch 超出自身范围会抛 RangeError，先挡住。
const int _maxDateTimeMilliseconds = 8640000000000000;

/// Reads the variable table a job or a result carries, ignoring unusable entries.
///
/// A `null` value is kept: that is how a script clears a variable.
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

/// Reads one `parse.*` call's arguments, or `null` when they are unusable.
///
/// `parse.getString` and `parse.getElements` differ only in
/// [JsParseRequest.wantsList].
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

/// Merges the book source's own headers under the rule's own.
Map<String, String> mergeJsHttpHeaders(
  Map<String, String>? sourceHeaders,
  Map<String, String> ruleHeaders,
) => <String, String>{...?sourceHeaders, ...ruleHeaders};

// 沙箱参数是解码后的 JSON，这里统一拒绝非字符串键的层级。
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

ParseFailureKind? _kindByName(String name) {
  for (final ParseFailureKind kind in ParseFailureKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }

  return null;
}

String? _stringField(Map<String, Object?> message, String key) {
  final Object? value = message[key];

  return value is String ? value : null;
}
