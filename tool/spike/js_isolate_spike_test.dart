// SPIKE 1 — Can `flutter_js_plus` drive the QuickJS engine from a background
// Isolate, and can a runaway `@js:` rule be contained? These are the
// assumptions behind ADR-0008 and C-SRC-2.
//
// Deliberately NOT under `test/` so it never runs in CI: it needs the plugin's
// prebuilt native library on the loader path.
//
// Run on Windows:
//   PATH="$PATH:$HOME/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_js_plus-0.0.4/windows/shared" \
//     flutter test tool/spike/js_isolate_spike_test.dart
//
// Run on Linux:
//   LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$HOME/.pub-cache/hosted/pub.dev/flutter_js_plus-0.0.4/linux/shared" \
//     flutter test tool/spike/js_isolate_spike_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_js_plus/flutter_js.dart';
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
    final JavascriptRuntime runtime = getJavascriptRuntime(xhr: false);
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

  // Finding: passing `timeout` to QuickJsRuntime2 has NO effect — the script runs
  // until the isolate is killed. This test documents that limitation; the 5s
  // wall-clock budget required by ADR-0008 must be enforced by the caller.
  test('07_engineLevelTimeout_isIneffective_isolateKillIsRequired', () async {
    final Stopwatch sw = Stopwatch()..start();
    final Map<String, Object?> out = await _runInBackground(<String, Object?>{
      'mode': 'engine-timeout',
    }, budget: const Duration(seconds: 6));
    sw.stop();
    stdout.writeln(
      '  [engine-timeout] status=${out['status']} '
      'isError=${out['isError']} elapsed=${sw.elapsedMilliseconds}ms '
      'error=${out['error']}',
    );
    expect(
      out['status'],
      'killed',
      reason:
          'documents that the engine timeout does not abort the script; '
          'the caller-side isolate kill is the only containment',
    );
    expect(sw.elapsedMilliseconds, lessThan(10000));
  }, timeout: const Timeout(Duration(seconds: 40)));

  // Finding: the shipped quickjs_c_bridge.dll is older than the Dart code and
  // does not export `jsSetMemoryLimit`, so the 32MB cap from ADR-0008 (C-SRC-3)
  // cannot be enforced by this library.
  test('08_memoryLimitSymbol_missingFromShippedLibrary', () async {
    final Map<String, Object?> out = await _runInBackground(<String, Object?>{
      'mode': 'memory-limit',
    }, budget: const Duration(seconds: 15));
    stdout.writeln(
      '  [memory-limit] status=${out['status']} '
      'supported=${out['supported']} error=${out['error']}',
    );
    expect(out['status'], 'completed');
    expect(
      out['supported'],
      isFalse,
      reason:
          'documents the missing jsSetMemoryLimit symbol in the '
          'prebuilt native library',
    );
  }, timeout: const Timeout(Duration(seconds: 40)));
}

/// Runs the Legado rule once in the current isolate.
Map<String, Object?> _runRuleOnce(String input) {
  JavascriptRuntime? runtime;
  try {
    runtime = getJavascriptRuntime(xhr: false);
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
Map<String, Object?> _runBridgeOnce() {
  JavascriptRuntime? runtime;
  try {
    runtime = getJavascriptRuntime(xhr: false);
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

/// Drives a runaway script on the default runtime (no engine timeout).
void _runRunaway() {
  final JavascriptRuntime runtime = getJavascriptRuntime(xhr: false);
  runtime.evaluate('while (true) { var x = 1; }');
}

/// Probes the engine-level interrupt handler (timeout only; the shipped DLL
/// does not export the memory-limit symbol).
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

/// Probes whether the shipped native library exports `jsSetMemoryLimit`.
Map<String, Object?> _runMemoryLimitOnce() {
  try {
    final QuickJsRuntime2 runtime = QuickJsRuntime2(
      memoryLimit: 32 * 1024 * 1024,
    );
    runtime.dispose();
    return <String, Object?>{'supported': true, 'error': null};
  } on Object catch (error) {
    return <String, Object?>{'supported': false, 'error': '$error'};
  }
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

/// Reports a completed 'engine-timeout' job.
void _sendEngineTimeoutResult(SendPort send) {
  final Map<String, Object?> result = _runEngineTimeoutOnce();
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
      _sendEngineTimeoutResult(send);
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
  Duration budget = const Duration(seconds: 20),
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
