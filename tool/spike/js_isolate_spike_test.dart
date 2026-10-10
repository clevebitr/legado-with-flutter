// SPIKE 1 (re-run, engine A) — Can `flutter_qjs_next` drive QuickJS from a
// background Isolate, and are the timeout / memory caps from ADR-0008 real?
//
// Deliberately NOT under `test/` so it never runs in CI: it needs the plugin's
// compiled native library. Unlike the previous engine, no source patch is
// required — the library is built by `flutter build windows`.
//
// Run on Windows:
//   flutter build windows --debug
//   FLUTTER_QJS_NEXT_LIBRARY="<repo>/build/windows/x64/runner/Debug/flutter_qjs_next_plugin.dll" \
//     flutter test tool/spike/js_isolate_spike_test.dart
//
// Run on Linux:
//   flutter build linux --debug
//   FLUTTER_QJS_NEXT_LIBRARY="<repo>/build/linux/x64/debug/bundle/lib/libflutter_qjs_next_plugin.so" \
//     flutter test tool/spike/js_isolate_spike_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_qjs_next/flutter_qjs.dart';
import 'package:flutter_test/flutter_test.dart';

/// A realistic Legado `@js:` rule: split a list, collapse whitespace, drop empties.
const String _legadoRule = r'''
(function () {
  var parts = String(result).split('###');
  var out = [];
  for (var i = 0; i < parts.length; i++) {
    var t = parts[i].replace(/\s+/g, ' ').trim();
    if (t.length > 0) { out.push(t); }
  }
  return JSON.stringify(out);
})()
''';

const String _sampleInput = '  第一章   开始  ###  第二章\n换行  ###\n\n###第三章   ';

/// JSON expected from [_legadoRule] applied to [_sampleInput].
const String _expected = '["第一章 开始","第二章 换行","第三章"]';

/// Budget given to each background isolate before it is killed.
const Duration _defaultBudget = Duration(seconds: 20);

/// Entry point; see the file header for how to run it.
void main() {
  test('01_control_rootIsolate_quickjsEvaluateWorks', () {
    final Map<String, Object?> out = _runRuleOnce(_sampleInput);
    stdout.writeln('  [root] value=${out['value']}');
    expect(out['ok'], isTrue, reason: 'error=${out['error']}');
    expect(out['value'], _expected);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('02_backgroundIsolate_canCreateRuntimeAndEvaluate', () async {
    final Map<String, Object?> out = await _runInBackground(<String, Object?>{
      'mode': 'rule',
    });
    stdout.writeln(
      '  [isolate] status=${out['status']} value=${out['value']} '
      'error=${out['error']}',
    );
    expect(out['status'], 'completed');
    expect(out['ok'], isTrue, reason: 'error=${out['error']}');
    expect(out['value'], _expected);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('03_backgroundIsolate_jsToDartBridgeWorks', () async {
    final Map<String, Object?> out = await _runInBackground(<String, Object?>{
      'mode': 'bridge',
    });
    stdout.writeln(
      '  [bridge] status=${out['status']} '
      'dartReceived=${out['dartReceived']} jsSawReturn=${out['jsSawReturn']} '
      'error=${out['error']}',
    );
    expect(out['status'], 'completed');
    expect(out['dartReceived'], 'ping');
    expect(out['jsSawReturn'], 'pong');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('03b_control_rootIsolate_jsToDartBridgeWorks', () {
    final Map<String, Object?> out = _runBridgeOnce();
    stdout.writeln(
      '  [bridge-root] dartReceived=${out['dartReceived']} '
      'jsSawReturn=${out['jsSawReturn']} error=${out['error']}',
    );
    expect(
      out['dartReceived'],
      'ping',
      reason: 'control: the JS->Dart bridge must work on the root isolate',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('04_backgroundIsolate_runawayScriptIsKillable', () async {
    final Stopwatch sw = Stopwatch()..start();
    final Map<String, Object?> out = await _runInBackground(<String, Object?>{
      'mode': 'runaway',
    }, budget: const Duration(seconds: 3));
    sw.stop();
    stdout.writeln(
      '  [runaway] status=${out['status']} '
      'elapsed=${sw.elapsedMilliseconds}ms',
    );
    expect(
      out['status'],
      'killed',
      reason: 'a runaway script must be killable, not hang the isolate',
    );
    expect(sw.elapsedMilliseconds, lessThan(8000));
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('05_afterKill_engineIsStillUsable', () async {
    final Map<String, Object?> out = await _runInBackground(<String, Object?>{
      'mode': 'rule',
    });
    stdout.writeln(
      '  [after-kill] status=${out['status']} value=${out['value']} '
      'error=${out['error']}',
    );
    expect(
      out['status'],
      'completed',
      reason: 'killing a runaway isolate must not poison the native library',
    );
    expect(out['value'], _expected);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('06_runtimeReuseCost_100Evaluations', () {
    final JavascriptRuntime runtime = getJavascriptRuntime();
    final Stopwatch sw = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      runtime.evaluate('var result = ${jsonEncode(_sampleInput)};');
      final JsEvalResult res = runtime.evaluate(_legadoRule);
      expect(res.isError, isFalse);
    }
    sw.stop();
    runtime.dispose();
    stdout.writeln(
      '  [perf] 100 evaluations in ${sw.elapsedMilliseconds}ms '
      '(${(sw.elapsedMilliseconds / 100).toStringAsFixed(2)}ms each)',
    );
    expect(sw.elapsedMilliseconds, lessThan(20000));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // ADR-0008 requires a 5s wall-clock budget. With this engine the timeout is a
  // first-class constructor argument; this probe checks whether it actually
  // aborts a runaway script (the previous engine's did not).
  test('07_engineLevelTimeout_abortsRunawayScript', () async {
    final Stopwatch sw = Stopwatch()..start();
    final Map<String, Object?> out = await _runInBackground(<String, Object?>{
      'mode': 'engine-timeout',
    }, budget: const Duration(seconds: 12));
    sw.stop();
    stdout.writeln(
      '  [engine-timeout] status=${out['status']} '
      'isError=${out['isError']} elapsed=${out['elapsed']}ms '
      'afterValue=${out['afterValue']} afterError=${out['afterError']} '
      'error=${out['error']}',
    );
    expect(
      out['status'],
      'completed',
      reason: 'the engine timeout must abort the script, not hang the isolate',
    );
    expect(
      out['isError'],
      isTrue,
      reason: 'expected the QuickJS interrupt handler to abort the script',
    );
    expect(out['elapsed'], lessThan(10000));
    expect(
      out['afterValue'],
      '2',
      reason: 'the runtime must remain usable after an aborted script',
    );
  }, timeout: const Timeout(Duration(seconds: 40)));

  // ADR-0008 requires a 32MB cap. Check that the limit is not only accepted but
  // actually enforced: allocating far more than the cap must raise a JS error.
  test('08_memoryLimit_isEnforced', () async {
    final Map<String, Object?> out = await _runInBackground(<String, Object?>{
      'mode': 'memory-limit',
    }, budget: const Duration(seconds: 20));
    stdout.writeln(
      '  [memory-limit] status=${out['status']} '
      'isError=${out['isError']} elapsed=${out['elapsed']}ms '
      'error=${out['error']}',
    );
    expect(out['status'], 'completed');
    expect(
      out['isError'],
      isTrue,
      reason: 'allocating beyond the memory limit must raise a JS error',
    );
  }, timeout: const Timeout(Duration(seconds: 45)));
}

/// Runs the Legado rule once in the current isolate.
Map<String, Object?> _runRuleOnce(String input) {
  JavascriptRuntime? runtime;
  try {
    runtime = getJavascriptRuntime();
    runtime.evaluate('var result = ${jsonEncode(input)};');
    final JsEvalResult res = runtime.evaluate(_legadoRule);
    if (res.isError) {
      return <String, Object?>{'ok': false, 'error': res.stringResult};
    }
    return <String, Object?>{'ok': true, 'value': res.stringResult};
  } on Object catch (error) {
    return <String, Object?>{'ok': false, 'error': '$error'};
  } finally {
    runtime?.dispose();
  }
}

/// Runs the JS -> Dart bridge probe once in the current isolate.
///
/// The message must be valid JSON: the bridge decodes it with `jsonDecode`.
Map<String, Object?> _runBridgeOnce() {
  JavascriptRuntime? runtime;
  try {
    runtime = getJavascriptRuntime();
    String? dartReceived;
    runtime.onMessage('SpikeBridge', (args) {
      dartReceived = '$args';
      return 'pong';
    });
    final JsEvalResult res = runtime.evaluate(
      "sendMessage('SpikeBridge', JSON.stringify('ping'))",
    );
    return <String, Object?>{
      'dartReceived': dartReceived,
      'jsSawReturn': res.stringResult,
    };
  } on Object catch (error) {
    return <String, Object?>{'error': '$error'};
  } finally {
    runtime?.dispose();
  }
}

/// Drives a runaway script on a default runtime (no engine timeout).
void _runRunaway() {
  final JavascriptRuntime runtime = getJavascriptRuntime();
  runtime.evaluate('while (true) { var x = 1; }');
}

/// Probes the engine-level interrupt handler: 2s budget, then reused.
Map<String, Object?> _runEngineTimeoutOnce() {
  final QuickJsRuntime2 runtime = QuickJsRuntime2(timeout: 2000);
  final Stopwatch sw = Stopwatch()..start();
  final JsEvalResult runaway = runtime.evaluate('while (true) { var x = 1; }');
  sw.stop();
  final JsEvalResult after = runtime.evaluate('1 + 1');
  runtime.dispose();
  return <String, Object?>{
    'isError': runaway.isError,
    'elapsed': sw.elapsedMilliseconds,
    'afterValue': after.stringResult,
    'afterError': after.isError,
  };
}

/// Probes whether an allocation beyond the 8MB cap raises a JS error.
Map<String, Object?> _runMemoryLimitOnce() {
  final QuickJsRuntime2 runtime = QuickJsRuntime2(
    timeout: 3000,
    memoryLimit: 8 * 1024 * 1024,
  );
  final Stopwatch sw = Stopwatch()..start();
  final JsEvalResult res = runtime.evaluate(
    'var chunks = [];'
    'while (true) { chunks.push(new Array(500000).fill("xxxxxxxxxx")); }',
  );
  sw.stop();
  runtime.dispose();
  return <String, Object?>{
    'isError': res.isError,
    'elapsed': sw.elapsedMilliseconds,
    'message': res.stringResult,
  };
}

/// Reports a completed 'rule' job.
void _sendRuleResult(SendPort send) {
  final Map<String, Object?> result = _runRuleOnce(_sampleInput);
  result['status'] = 'completed';
  send.send(result);
}

/// Reports a completed 'bridge' job.
void _sendBridgeResult(SendPort send) {
  final Map<String, Object?> result = _runBridgeOnce();
  result['status'] = 'completed';
  send.send(result);
}

/// Entry point of the background isolate.
void _isolateEntry(List<Object?> args) {
  final Object? port = args.isNotEmpty ? args.first : null;
  final Object? payload = args.length > 1 ? args[1] : null;
  if (port is! SendPort || payload is! Map) {
    return;
  }
  final SendPort send = port;
  final Map<String, Object?> job = payload.cast<String, Object?>();
  final Object? mode = job['mode'];
  try {
    if (mode == 'rule') {
      _sendRuleResult(send);
      return;
    }
    if (mode == 'bridge') {
      _sendBridgeResult(send);
      return;
    }
    if (mode == 'engine-timeout') {
      final Map<String, Object?> result = _runEngineTimeoutOnce();
      result['status'] = 'completed';
      send.send(result);
      return;
    }
    if (mode == 'memory-limit') {
      final Map<String, Object?> result = _runMemoryLimitOnce();
      result['status'] = 'completed';
      send.send(result);
      return;
    }
    if (mode == 'runaway') {
      _runRunaway();
      send.send(<String, Object?>{'status': 'unexpected-return'});
      return;
    }
    send.send(<String, Object?>{'status': 'bad-mode'});
  } on Object catch (error) {
    send.send(<String, Object?>{'status': 'threw', 'error': '$error'});
  }
}

/// Spawns a background isolate, runs one job, and kills it after [budget].
Future<Map<String, Object?>> _runInBackground(
  Map<String, Object?> job, {
  Duration budget = _defaultBudget,
}) async {
  final ReceivePort port = ReceivePort();
  final Completer<Map<String, Object?>> done =
      Completer<Map<String, Object?>>();
  final StreamSubscription<Object?> sub = port.listen((Object? message) {
    if (!done.isCompleted && message is Map) {
      done.complete(message.cast<String, Object?>());
    }
  });
  final Isolate isolate = await Isolate.spawn(_isolateEntry, <Object?>[
    port.sendPort,
    job,
  ]);
  final Timer timer = Timer(budget, () {
    if (!done.isCompleted) {
      isolate.kill(priority: Isolate.immediate);
      done.complete(<String, Object?>{'status': 'killed'});
    }
  });
  try {
    return await done.future;
  } finally {
    timer.cancel();
    await sub.cancel();
    port.close();
    isolate.kill(priority: Isolate.immediate);
  }
}
