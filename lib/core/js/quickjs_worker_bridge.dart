import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';

/// Single-evaluation wall-clock budget (`docs/dev/book-source.md` §6).
const Duration defaultJsTimeout = Duration(seconds: 5);

/// Single-evaluation QuickJS heap limit (`docs/dev/book-source.md` §6).
const int defaultJsMemoryLimitBytes = 32 * 1024 * 1024;

/// Time the bridge waits past the runtime's own interrupt before killing the worker.
///
/// ADR-0030 §决策 3: the runtime interrupts the script itself and stays usable
/// afterwards (probe 07), so the kill is only the fallback for an interrupt that did
/// not work. Killing at the same instant would race the interrupt and throw away a
/// worker the engine could still answer from.
const Duration defaultJsKillGrace = Duration(seconds: 2);

/// Marks the `rulePath` of a JS failure that hit the wall-clock budget (§6).
const String _jsTimeoutMarker = 'js:timeout';

/// Marks the `rulePath` of a JS failure that came from the script itself (§6).
const String _jsErrorMarker = 'js:error';

/// Longest `log.*` message the bridge forwards (`docs/dev/book-source.md` §6).
///
/// A rule's diagnostic line is not a data channel: without a bound, `log.debug(result)`
/// on a 200 KB page would write 200 KB per chapter straight into the log sink, which
/// grows the privacy surface and the disk footprint together (C-SEC-4).
const int maxJsLogMessageLength = 2000;

/// [JsBridge] backed by **one resident worker isolate with one reused runtime**.
///
/// ADR-0030 §决策 1 fixes the shape: a single worker (created lazily on the first
/// `@js:` rule, released with the provider scope), one QuickJS runtime reused for
/// every evaluation, and a **FIFO queue** in front of it — so a caller over the
/// worker's capacity waits instead of failing, as C-SRC-9 requires. The capacity
/// itself is not part of the contract (ADR-0030 §决策 2).
///
/// Each job is dispatched with a JSON envelope and accounted from the moment it
/// starts, not from the moment it was queued (ADR-0030 §决策 3). Two budgets protect
/// the run: the runtime's own interrupt at `timeout` (`book-source.md` §6), and the
/// bridge's hard budget `timeout` + `killGrace`, which kills and rebuilds the worker
/// when the interrupt did not work.
///
/// The engine never leaves this file: the isolate, the native library and the JS
/// prelude live behind [JsWorkerLauncher], which is what keeps the queue, the budgets
/// and the rebuild policy unit-testable without the native library.
final class QuickJsWorkerBridge implements JsBridge {
  /// Creates a bridge that starts workers through `launch`.
  ///
  /// `timeout` is both the runtime's interrupt budget and the bridge's accounting
  /// budget; the launcher receives it, so the two can never disagree.
  QuickJsWorkerBridge({
    required this._logger,
    required this._launch,
    this._timeout = defaultJsTimeout,
    this._killGrace = defaultJsKillGrace,
    this._memoryLimit = defaultJsMemoryLimitBytes,
  });

  final AppLogger _logger;
  final JsWorkerLauncher _launch;
  final Duration _timeout;
  final Duration _killGrace;
  final int _memoryLimit;

  final Queue<_PendingJob> _pending = Queue<_PendingJob>();
  _WorkerSession? _session;
  bool _pumping = false;
  bool _disposed = false;

  @override
  Future<ParseResult<Object?>> evaluate(JsJob job) {
    if (_disposed) {
      return Future<ParseResult<Object?>>.value(
        _cancelledFailure(job.rulePath),
      );
    }

    final _PendingJob pending = _PendingJob(job);
    _pending.add(pending);
    unawaited(_pump());

    return pending.completer.future;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    final _WorkerSession? session = _session;
    _session = null;
    // 排队中的 job 由 [_pump] 在在途 job 结束后按 `_disposed` 逐个取消：队列总有一个
    // 正在跑的 [_pump] 在推进，所以这里不需要（也不该）再单独清一次队列。
    await session?.close();
  }

  /// Runs queued jobs one at a time, in call order (ADR-0030 §决策 3).
  ///
  /// A job that fails does not stop the queue: only the worker is replaced, on the
  /// next job that needs it.
  Future<void> _pump() async {
    if (_pumping) {
      return;
    }
    _pumping = true;
    try {
      while (_pending.isNotEmpty) {
        final _PendingJob pending = _pending.removeFirst();
        // dispose 之后不再拉起新 worker（ADR-0030 §决策 6 的作用域生命周期），
        // 否则一个已释放的桥会给排队中的 job 又开一个隔离体。
        if (_disposed) {
          pending.completer.complete(_cancelledFailure(pending.job.rulePath));
          continue;
        }
        pending.completer.complete(await _run(pending.job));
      }
    } finally {
      _pumping = false;
    }
  }

  /// Runs one job on a live worker, starting (or rebuilding) it when needed.
  Future<ParseResult<Object?>> _run(JsJob job) async {
    try {
      final _WorkerSession session = await _currentSession();

      return await session.run(job);
    } on IsolateSpawnException catch (error, stackTrace) {
      // 隔离体起不来（进程资源耗尽）：按 §6 报 js:error，不把异常抛给调用方（C-ERR-1）。
      _logger.warning(
        'JS worker could not start: field=${job.rulePath}',
        describeError(error),
        stackTrace,
      );

      return failureAt<Object?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: '${job.rulePath}:$_jsErrorMarker',
      );
    }
  }

  /// Returns the live worker, replacing one that was killed (ADR-0030 §决策 3).
  Future<_WorkerSession> _currentSession() async {
    final _WorkerSession? session = _session;
    if (session != null && !session.isDead) {
      return session;
    }
    if (session != null) {
      _session = null;
      await session.close();
    }

    final JsWorkerHandle handle = await _launch(
      timeout: _timeout,
      memoryLimit: _memoryLimit,
    );
    final _WorkerSession created = _WorkerSession(
      handle: handle,
      logger: _logger,
      timeout: _timeout,
      killGrace: _killGrace,
    );
    _session = created;

    return created;
  }
}

/// The failure a job gets when it is dropped instead of run (C-ERR-1).
///
/// The path stays the bare field: a cancellation is not a script error, so it carries no
/// `js:*` marker — §6 leaves the trigger itself to §7 (review F3).
ParseFailure<Object?> _cancelledFailure(String rulePath) =>
    failureAt<Object?>(kind: ParseFailureKind.cancelled, rulePath: rulePath);

/// One queued evaluation and the caller waiting on it.
final class _PendingJob {
  _PendingJob(this.job);

  final JsJob job;
  final Completer<ParseResult<Object?>> completer =
      Completer<ParseResult<Object?>>();
}

/// One live worker plus the bookkeeping of the job it is running.
///
/// The session owns the *per-job* budgets: it sends the envelope, waits for the
/// matching result and hands the job's failure to it. The FIFO ordering lives in
/// [QuickJsWorkerBridge], because only the queue can decide what comes next.
final class _WorkerSession {
  _WorkerSession({
    required this._handle,
    required this._logger,
    required this._timeout,
    required this._killGrace,
  }) {
    _subscription = _handle.messages.listen(
      _onMessage,
      onDone: _onWorkerDone,
      onError: _onWorkerError,
    );
  }

  final JsWorkerHandle _handle;
  final AppLogger _logger;
  final Duration _timeout;
  final Duration _killGrace;

  late final StreamSubscription<Map<String, Object?>> _subscription;
  final Completer<void> _closed = Completer<void>();

  Completer<ParseResult<Object?>>? _inFlight;
  String? _inFlightRulePath;
  Timer? _budget;
  bool _dead = false;

  /// Whether the bridge has to replace this worker before the next job.
  bool get isDead => _dead;

  /// Dispatches [job] and waits for its result.
  ///
  /// The budget is started here, not when the job was queued, so a job that waited
  /// behind others is not charged for the wait (ADR-0030 §决策 3).
  Future<ParseResult<Object?>> run(JsJob job) {
    final Completer<ParseResult<Object?>> completer =
        Completer<ParseResult<Object?>>();
    _inFlight = completer;
    _inFlightRulePath = job.rulePath;
    _handle.send(<String, Object?>{'type': 'evaluate', 'job': job.toJson()});
    _budget = Timer(_timeout + _killGrace, _onBudgetExpired);

    return completer.future;
  }

  /// Releases the worker, giving it a chance to free the native runtime first.
  ///
  /// `Isolate.kill` does not run destructors, so killing a healthy worker would leak
  /// the QuickJS heap; the worker therefore gets a bounded moment to answer `closed`
  /// and is killed only if it does not.
  Future<void> close() async {
    _dead = true;
    _budget?.cancel();
    _budget = null;
    final Completer<ParseResult<Object?>>? inFlight = _inFlight;
    if (inFlight != null) {
      final String rulePath = _inFlightRulePath ?? 'js';
      _inFlight = null;
      _inFlightRulePath = null;
      inFlight.complete(_cancelledFailure(rulePath));
    }

    if (!_closed.isCompleted) {
      _handle.send(<String, Object?>{'type': 'close'});
      await _closed.future.timeout(_killGrace, onTimeout: () {});
    }

    await _subscription.cancel();
    _handle.kill();
  }

  /// Routes one worker envelope.
  void _onMessage(Map<String, Object?> message) {
    switch (_stringField(message, 'type')) {
      case 'result':
        _onResult(message);
      case 'log':
        _onLog(message);
      case 'closed':
        if (!_closed.isCompleted) {
          _closed.complete();
        }
      default:
        // 未知信封不得静默丢弃（C-SRC-4 的同口径）：记 warning 后忽略。
        _logger.warning(
          'Ignoring an unknown JS worker message: type='
          '${_stringField(message, 'type') ?? 'missing'}',
        );
    }
  }

  /// Turns one result envelope into the caller's [ParseResult].
  void _onResult(Map<String, Object?> message) {
    if (_inFlight == null) {
      _logger.warning('JS worker answered without a job in flight');

      return;
    }

    if (message['ok'] == true) {
      _completeInFlight(ParseSuccess<Object?>(message['value']));

      return;
    }

    // 运行时中断与脚本异常都表现为 `isError`（探针 07），所以用 worker 报的耗时区分：
    // 跑满预算才算超时，否则是规则自己的错（§6 的 `js:timeout` / `js:error`）。
    final int elapsedMs = _intField(message, 'elapsedMs') ?? 0;
    final Object? error = message['error'];
    if (elapsedMs >= _timeout.inMilliseconds) {
      _completeInFlight(
        failureAt<Object?>(
          kind: ParseFailureKind.parseFailed,
          rulePath: '${_inFlightRulePath ?? 'js'}:$_jsTimeoutMarker',
        ),
      );

      return;
    }

    _logger.warning(
      'JS rule failed: field=${_inFlightRulePath ?? 'js'} '
      'error=${error == null ? 'unknown' : describeError(error)}',
    );
    _completeInFlight(
      failureAt<Object?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: '${_inFlightRulePath ?? 'js'}:$_jsErrorMarker',
      ),
    );
  }

  /// Forwards one `log.*` record, tagged with the field it came from (§6).
  ///
  /// The text is capped at [maxJsLogMessageLength] and the cut is marked, so the bound
  /// is visible instead of silently losing the tail.
  void _onLog(Map<String, Object?> message) {
    final String text = _limitLogMessage(
      _stringField(message, 'message') ?? '',
    );
    final String line = '[js:${_inFlightRulePath ?? 'js'}] $text';

    switch (_stringField(message, 'level')) {
      case 'debug':
        _logger.debug(line);
      case 'warn':
        _logger.warning(line);
      case 'error':
        _logger.error(line);
      default:
        _logger.info(line);
    }
  }

  /// Kills a worker that ignored its own interrupt and rebuilds on the next job.
  void _onBudgetExpired() {
    if (_inFlight == null) {
      return;
    }
    final String rulePath = _inFlightRulePath ?? 'js';
    _dead = true;
    _handle.kill();
    _logger.warning('JS worker killed at the hard budget: field=$rulePath');
    _completeInFlight(
      failureAt<Object?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: '$rulePath:$_jsTimeoutMarker',
      ),
    );
  }

  /// Fails the in-flight job when the worker stops answering for good.
  void _onWorkerDone() {
    _dead = true;
    if (!_closed.isCompleted) {
      _closed.complete();
    }
    if (_inFlight == null) {
      return;
    }
    final String rulePath = _inFlightRulePath ?? 'js';
    _logger.warning('JS worker stopped before answering: field=$rulePath');
    _completeInFlight(
      failureAt<Object?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: '$rulePath:$_jsErrorMarker',
      ),
    );
  }

  /// Keeps a stream error on the worker from becoming an unhandled async error.
  void _onWorkerError(Object error, StackTrace stackTrace) {
    _logger.warning(
      'JS worker message stream failed',
      describeError(error),
      stackTrace,
    );
    _onWorkerDone();
  }

  /// Completes the in-flight job with [result] and releases its budget.
  void _completeInFlight(ParseResult<Object?> result) {
    final Completer<ParseResult<Object?>>? inFlight = _inFlight;
    _budget?.cancel();
    _budget = null;
    _inFlight = null;
    _inFlightRulePath = null;
    if (inFlight != null && !inFlight.isCompleted) {
      inFlight.complete(result);
    }
  }
}

/// Reads a `String` field of an envelope, ignoring a value of another type.
String? _stringField(Map<String, Object?> message, String key) {
  final Object? value = message[key];

  return value is String ? value : null;
}

/// Caps one `log.*` message at [maxJsLogMessageLength], marking what was dropped.
String _limitLogMessage(String text) {
  if (text.length <= maxJsLogMessageLength) {
    return text;
  }
  final int dropped = text.length - maxJsLogMessageLength;

  return '${text.substring(0, maxJsLogMessageLength)}'
      '…[truncated $dropped chars]';
}

/// Reads an `int` field of an envelope, ignoring a value of another type.
int? _intField(Map<String, Object?> message, String key) {
  final Object? value = message[key];

  return value is int ? value : null;
}
