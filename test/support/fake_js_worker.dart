import 'dart:async';
import 'dart:collection';

import 'package:flutter_reader/core/js/js_bridge.dart';

/// Hand-written [JsWorkerHandle] double: answers `evaluate` envelopes and records
/// everything the bridge sends (`docs/dev/testing.md` §4).
///
/// Only the public transport contract is faked — no engine internals — so the bridge's
/// queueing, budgets and rebuild policy stay unit-testable while the native edge
/// (`quickjs_worker.dart`) is allowlisted and covered by the integration test.
///
/// The scripts below are conventions, so a test can drive an outcome without racing the
/// worker's creation:
///
/// * `fail` → the job answers with a small elapsed time, i.e. a rule error;
/// * `runaway` → the job answers with a huge elapsed time, i.e. the engine interrupt;
/// * `hold` → the job is never answered, i.e. a worker that ignores its interrupt;
/// * anything else → the job echoes its own script back as the value.
final class FakeJsWorkerHandle implements JsWorkerHandle {
  /// Envelopes the bridge sent, in order.
  final List<Map<String, Object?>> sent = <Map<String, Object?>>[];

  /// How many times the bridge killed this worker.
  int killCount = 0;

  /// When true, `evaluate` envelopes are recorded but never answered.
  bool holdJobs = false;

  /// When false, the `close` envelope is recorded but not answered either.
  bool answerClose = true;

  final StreamController<Map<String, Object?>> _messages =
      StreamController<Map<String, Object?>>();
  final Queue<Map<String, Object?>> _results = Queue<Map<String, Object?>>();

  /// The elapsed time the `runaway` script reports: larger than any test budget.
  static const int runawayElapsedMs = 1000 * 1000;

  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  /// Queues the envelope the next answered `evaluate` replies with.
  void enqueueResult({
    bool ok = true,
    Object? value,
    String? error,
    int elapsedMs = 0,
    Map<String, String?>? variables,
  }) {
    _results.add(<String, Object?>{
      'type': 'result',
      'ok': ok,
      'value': value,
      'error': error,
      'elapsedMs': elapsedMs,
      // §6 的变量回报：worker 把整份按源变量表随结果一起交回（ADR-0034 §决策 1）。
      'variables': ?variables,
    });
  }

  /// Sends a raw envelope to the bridge, as the worker would.
  void emit(Map<String, Object?> message) {
    if (!_messages.isClosed) {
      _messages.add(message);
    }
  }

  /// Makes the worker look like it stopped: the bridge sees the stream end.
  void emitDone() {
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  /// Makes the worker's stream fail.
  void emitError(Object error) {
    if (!_messages.isClosed) {
      _messages.addError(error);
    }
  }

  @override
  void send(Map<String, Object?> message) {
    sent.add(message);
    switch (message['type']) {
      case 'evaluate':
        if (holdJobs) {
          return;
        }
        final Map<String, Object?>? result = _resultFor(message);
        if (result != null) {
          emit(result);
        }
      case 'close':
        if (answerClose) {
          emit(<String, Object?>{'type': 'closed'});
        }
    }
  }

  @override
  void kill() => killCount++;

  /// The result envelope the fake answers [message] with, or `null` for silence.
  Map<String, Object?>? _resultFor(Map<String, Object?> message) {
    if (_results.isNotEmpty) {
      return _results.removeFirst();
    }

    final Object? job = message['job'];
    final Object? script = job is Map ? job['script'] : null;
    switch (script) {
      case 'fail':
        return <String, Object?>{
          'type': 'result',
          'ok': false,
          'error': 'boom',
          'elapsedMs': 1,
        };
      case 'runaway':
        return <String, Object?>{
          'type': 'result',
          'ok': false,
          'error': 'interrupted',
          'elapsedMs': runawayElapsedMs,
        };
      case 'hold':
        return null;
      default:
        return <String, Object?>{'type': 'result', 'ok': true, 'value': script};
    }
  }
}
