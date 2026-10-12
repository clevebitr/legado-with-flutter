// coverage:ignore-file
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_qjs_next/flutter_qjs.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';

/// Starts the real worker: one dedicated isolate owning one **reused** QuickJS runtime
/// (`docs/dev/book-source.md` §6, ADR-0030 §决策 1).
///
/// This file is exempt from the coverage gate under ADR-0019's second category: it is
/// the only place that reaches the `flutter_qjs_next` native library, which cannot be
/// loaded from `flutter test`'s host VM (only a real device build provides it), so its
/// queueing and budget policy deliberately lives in
/// `quickjs_worker_bridge.dart` instead. **Its only automated verification is
/// `integration_test/js_bridge_test.dart`**, which runs it on Windows / Android with
/// the plugin built; how to run that is in `docs/dev/test-environment.md` §4.
///
/// The two budgets come from the bridge, never from here: the runtime interrupt
/// ([timeout]) and the heap limit ([memoryLimit]) are `book-source.md` §6's numbers,
/// defined once in `quickjs_worker_bridge.dart`.
Future<JsWorkerHandle> launchQuickJsWorker({
  required Duration timeout,
  required int memoryLimit,
}) async {
  final ReceivePort fromWorker = ReceivePort();
  final StreamController<Map<String, Object?>> messages =
      StreamController<Map<String, Object?>>();
  final Completer<SendPort> ready = Completer<SendPort>();

  final StreamSubscription<Object?> subscription = fromWorker.listen((
    Object? raw,
  ) {
    if (raw is! Map) {
      return;
    }
    final Map<String, Object?> message = Map<String, Object?>.from(raw);
    if (!ready.isCompleted && message['type'] == 'ready') {
      final Object? port = message['port'];
      if (port is SendPort) {
        ready.complete(port);
      }

      return;
    }
    if (!messages.isClosed) {
      messages.add(message);
    }
  });

  final Isolate isolate = await Isolate.spawn(_quickJsWorkerMain, <Object?>[
    fromWorker.sendPort,
    timeout.inMilliseconds,
    memoryLimit,
  ], debugName: 'js-worker');

  return _IsolateWorkerHandle(
    isolate: isolate,
    toWorker: await ready.future,
    fromWorker: fromWorker,
    subscription: subscription,
    messages: messages,
  );
}

/// One worker isolate as a [JsWorkerHandle].
final class _IsolateWorkerHandle implements JsWorkerHandle {
  _IsolateWorkerHandle({
    required this._isolate,
    required this._toWorker,
    required this._fromWorker,
    required this._subscription,
    required this._messages,
  });

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;
  final StreamSubscription<Object?> _subscription;
  final StreamController<Map<String, Object?>> _messages;

  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  @override
  void send(Map<String, Object?> message) => _toWorker.send(message);

  @override
  void kill() {
    _isolate.kill(priority: Isolate.immediate);
    _fromWorker.close();
    unawaited(_subscription.cancel());
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }
}

/// The worker's main loop: build the runtime once, then serve jobs until closed.
///
/// Deliberately free of `try`/`catch`: a native failure is an `Error`, which ADR-0022
/// forbids catching. An isolate that dies leaves the bridge's hard budget to notice,
/// kill (a no-op by then) and rebuild — which is exactly the fallback ADR-0030
/// §决策 3 describes.
Future<void> _quickJsWorkerMain(List<Object?> bootstrap) async {
  final Object? port = bootstrap.isNotEmpty ? bootstrap[0] : null;
  final Object? timeoutMs = bootstrap.length > 1 ? bootstrap[1] : null;
  final Object? memoryLimit = bootstrap.length > 2 ? bootstrap[2] : null;
  if (port is! SendPort || timeoutMs is! int || memoryLimit is! int) {
    return;
  }

  final ReceivePort fromBridge = ReceivePort();
  port.send(<String, Object?>{'type': 'ready', 'port': fromBridge.sendPort});

  final JavascriptRuntime runtime = getJavascriptRuntime(
    timeout: timeoutMs,
    memoryLimit: memoryLimit,
  );
  _installHostBindings(runtime, port);
  runtime.evaluate(_prelude);

  await for (final Object? raw in fromBridge) {
    if (raw is! Map) {
      continue;
    }
    final Map<String, Object?> envelope = Map<String, Object?>.from(raw);
    switch (envelope['type']) {
      case 'evaluate':
        _evaluate(runtime, envelope['job'], port);
      case 'close':
        runtime.dispose();
        port.send(<String, Object?>{'type': 'closed'});
        fromBridge.close();

        return;
    }
  }
}

/// Runs one job and reports its result envelope.
void _evaluate(JavascriptRuntime runtime, Object? job, SendPort toBridge) {
  if (job is! Map) {
    toBridge.send(<String, Object?>{
      'type': 'result',
      'ok': false,
      'error': 'malformed job',
      'elapsedMs': 0,
    });

    return;
  }

  final Map<String, Object?> fields = Map<String, Object?>.from(job);
  final Stopwatch stopwatch = Stopwatch()..start();
  final JsEvalResult result = runtime.evaluate(_evaluationSource(fields));
  stopwatch.stop();
  final int elapsedMs = stopwatch.elapsedMilliseconds;

  if (result.isError) {
    toBridge.send(<String, Object?>{
      'type': 'result',
      'ok': false,
      'error': result.stringResult,
      'elapsedMs': elapsedMs,
    });

    return;
  }

  final Map<String, Object?>? decoded = _decodeEnvelope(result.stringResult);
  if (decoded == null) {
    toBridge.send(<String, Object?>{
      'type': 'result',
      'ok': false,
      'error': 'unreadable result envelope',
      'elapsedMs': elapsedMs,
    });

    return;
  }

  toBridge.send(<String, Object?>{
    'type': 'result',
    'ok': decoded['ok'] == true,
    'value': decoded['value'],
    'error': decoded['error'],
    'elapsedMs': elapsedMs,
  });
}

/// Builds the script one job runs: the §6 variables, then the rule through the helper.
///
/// `eval` inside the helper is what gives the rule its **completion value** semantics:
/// `result.replace(...)` and `var x = 1; x + 1` both produce a value, so a source can
/// keep using either spelling. The script text is passed as a JSON string literal, so
/// nothing in the rule can break out of it.
String _evaluationSource(Map<String, Object?> fields) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('var baseUrl = ${jsonEncode(fields['baseUrl'])};')
    ..writeln('var result = ${jsonEncode(fields['result'])};')
    ..writeln('var page = ${jsonEncode(fields['page'])};')
    ..writeln('var source = Object.freeze(${jsonEncode(fields['source'])});')
    ..write('__runRule(${jsonEncode(_asString(fields['script']))})');

  return buffer.toString();
}

/// Reads one envelope field as a [String], or an empty string.
String _asString(Object? value) => value is String ? value : '';

/// Decodes the JSON envelope the sandbox helper returns, or `null` when it is not one.
///
/// A JS syntax error makes the helper itself unparsable, so this is the second place a
/// broken script surfaces; the caller reports both as `js:error`.
Map<String, Object?>? _decodeEnvelope(String raw) {
  try {
    final Object? decoded = jsonDecode(raw);

    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// Registers the two sync binding channels of `book-source.md` §6.
///
/// Both complete inside this isolate, which is why JavaScript gets a value rather than
/// a Promise (ADR-0029 §决策 3). `crypto.*` never throws: an unusable input answers
/// `null` and the prelude turns that into a JS `Error`, so no engine behaviour is
/// relied on.
void _installHostBindings(JavascriptRuntime runtime, SendPort toBridge) {
  runtime.onMessage('crypto', (args) {
    if (args is! Map) {
      return null;
    }
    final Object? operation = args['operation'];
    final Object? value = args['value'];
    if (operation is! String || value is! String) {
      return null;
    }

    return applyCryptoOperation(operation, value);
  });
  runtime.onMessage('log', (args) {
    if (args is! Map) {
      return null;
    }

    toBridge.send(<String, Object?>{
      'type': 'log',
      'level': args['level'],
      'message': args['message'],
    });

    return null;
  });
}

/// The sandbox surface: the §6 variables helper plus the sync `log.*` / `crypto.*`.
///
/// Every `sendMessage` payload is a `JSON.stringify` object: the bridge decodes it with
/// `jsonDecode` before the handler sees it (`tool/spike/README.md` §4), so a bare
/// string would not survive.
const String _prelude = r'''
globalThis.__runRule = function (scriptText) {
  var value;
  try {
    value = eval(scriptText);
  } catch (error) {
    return JSON.stringify({
      ok: false,
      error: (error && error.message) ? String(error.message) : String(error)
    });
  }
  if (value === undefined) {
    return JSON.stringify({ ok: true, value: null });
  }
  try {
    return JSON.stringify({ ok: true, value: value });
  } catch (error) {
    return JSON.stringify({ ok: true, value: String(value) });
  }
};

globalThis.__crypto = function (operation, value) {
  var result = sendMessage(
    'crypto',
    JSON.stringify({ operation: operation, value: String(value) })
  );
  if (result === null || result === undefined) {
    throw new Error('crypto.' + operation + ' failed');
  }
  return result;
};

globalThis.log = Object.freeze({
  debug: function (message) {
    sendMessage('log', JSON.stringify({ level: 'debug', message: String(message) }));
  },
  info: function (message) {
    sendMessage('log', JSON.stringify({ level: 'info', message: String(message) }));
  },
  warn: function (message) {
    sendMessage('log', JSON.stringify({ level: 'warn', message: String(message) }));
  },
  error: function (message) {
    sendMessage('log', JSON.stringify({ level: 'error', message: String(message) }));
  }
});

globalThis.crypto = Object.freeze({
  md5: function (value) { return __crypto('md5', value); },
  sha1: function (value) { return __crypto('sha1', value); },
  base64Encode: function (value) { return __crypto('base64Encode', value); },
  base64Decode: function (value) { return __crypto('base64Decode', value); }
});
''';
