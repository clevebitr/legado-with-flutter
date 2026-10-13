import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';

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

/// Marks the `rulePath` of a job that ran out of §6's per-rule call quota.
const String _jsQuotaMarker = 'js:quota';

/// Longest chain of binding calls one rule may make (`docs/dev/book-source.md` §6).
///
/// Only the calls that cross to the host count — `log.*`, `http.*`, `parse.*` — because a
/// `crypto.*` call is answered inside the worker and never reaches this layer. Counting it
/// here, next to the budgets, keeps the quota per job and unit-testable without a second
/// implementation inside the worker.
const int defaultJsMaxBindingCalls = 20;

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
///
/// It also owns the rules' variable store: `java.put` is answered **inside** the worker
/// (that is what makes it synchronous, §6), so the job reports its variables back and this
/// layer — the one that knows which source the job belongs to — applies them (ADR-0034
/// §决策 1).
final class QuickJsWorkerBridge implements JsBridge {
  /// Creates a bridge that starts workers through `launch`.
  ///
  /// `timeout` is both the runtime's interrupt budget and the bridge's accounting
  /// budget; the launcher receives it, so the two can never disagree. The `http` client is
  /// the only way a rule reaches the network (C-NET-1) and `maxBindingCalls` is §6's
  /// per-rule quota, counted here because this is the layer that sees every binding call.
  ///
  /// [JsVariableStore] is the same store the rule engine writes `@put:` into, so a
  /// variable a script wrote is visible to `@get:` / `{{name}}` of a later rule of the same
  /// source.
  QuickJsWorkerBridge({
    required this._logger,
    required this._launch,
    required this._http,
    required this._variables,
    this._timeout = defaultJsTimeout,
    this._killGrace = defaultJsKillGrace,
    this._memoryLimit = defaultJsMemoryLimitBytes,
    this._maxBindingCalls = defaultJsMaxBindingCalls,
  });

  final AppLogger _logger;
  final JsWorkerLauncher _launch;
  final HttpClient _http;
  final JsVariableStore _variables;
  final Duration _timeout;
  final Duration _killGrace;
  final int _memoryLimit;
  final int _maxBindingCalls;

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
      http: _http,
      variables: _variables,
      timeout: _timeout,
      killGrace: _killGrace,
      maxBindingCalls: _maxBindingCalls,
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
/// matching result, answers the binding calls the script makes on the way (`log.*` is
/// fire-and-forget, `http.*` / `parse.*` are the host round trips of §6) and hands the
/// job's failure to it. The FIFO ordering lives in [QuickJsWorkerBridge], because only
/// the queue can decide what comes next.
final class _WorkerSession {
  _WorkerSession({
    required this._handle,
    required this._logger,
    required this._http,
    required this._variables,
    required this._timeout,
    required this._killGrace,
    required this._maxBindingCalls,
  }) {
    _subscription = _handle.messages.listen(
      _onMessage,
      onDone: _onWorkerDone,
      onError: _onWorkerError,
    );
  }

  final JsWorkerHandle _handle;
  final AppLogger _logger;
  final HttpClient _http;
  final JsVariableStore _variables;
  final Duration _timeout;
  final Duration _killGrace;
  final int _maxBindingCalls;

  late final StreamSubscription<Map<String, Object?>> _subscription;
  final Completer<void> _closed = Completer<void>();

  Completer<ParseResult<Object?>>? _inFlight;
  JsJob? _inFlightJob;
  ParseResult<Object?>? _fatalFailure;
  Timer? _budget;
  int _bindingCalls = 0;
  bool _dead = false;

  /// Whether the bridge has to replace this worker before the next job.
  bool get isDead => _dead;

  /// The field path of the job in flight, or a neutral one when there is none.
  String get _field => _inFlightJob?.rulePath ?? 'js';

  /// Dispatches [job] and waits for its result.
  ///
  /// The budget is started here, not when the job was queued, so a job that waited
  /// behind others is not charged for the wait (ADR-0030 §决策 3). The per-rule call
  /// quota starts here too, for the same reason.
  Future<ParseResult<Object?>> run(JsJob job) {
    final Completer<ParseResult<Object?>> completer =
        Completer<ParseResult<Object?>>();
    _inFlight = completer;
    _inFlightJob = job;
    _bindingCalls = 0;
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
      final String rulePath = _field;
      _clearInFlight();
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
      case 'host':
        _onHostCall(message);
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
      // 已被硬预算杀掉的 job 可能仍会回一条结果（worker 正在被杀）：它不是协议错误，
      // 但也不能算给下一个 job，所以丢弃并留痕。
      _logger.debug('Ignoring a JS result that no job is waiting for');

      return;
    }

    // 脚本里 `java.put` 的写入先落地（上游的 put 是立即生效的，失败前写的也算），再决定
    // 这个 job 的答案（ADR-0034 §决策 1）。
    final JsJob? job = _inFlightJob;
    if (job != null) {
      _variables.merge(
        job.source.url,
        _reportedVariables(message['variables']),
      );
    }

    // 致命边界已经决定了这个 job 的答案：脚本自己写出来的值不再算数（C-SRC-4）。
    final ParseResult<Object?>? fatal = _fatalFailure;
    if (fatal != null) {
      _completeInFlight(fatal);

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
          rulePath: '$_field:$_jsTimeoutMarker',
        ),
      );

      return;
    }

    _logger.warning(
      'JS rule failed: field=$_field '
      'error=${error == null ? 'unknown' : describeError(error)}',
    );
    _completeInFlight(
      failureAt<Object?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: '$_field:$_jsErrorMarker',
      ),
    );
  }

  /// Forwards one `log.*` record, tagged with the field it came from (§6).
  ///
  /// The text is capped at [maxJsLogMessageLength] and the cut is marked, so the bound
  /// is visible instead of silently losing the tail.
  void _onLog(Map<String, Object?> message) {
    if (_fatalFailure != null) {
      // 这个 job 已经定了，脚本接下来写什么都不再影响结果。
      return;
    }
    if (_inFlightJob != null && _countCall()) {
      // §6 的额度含 log.*：脚本狂写日志与递归 parse 一样会霸占 worker。
      _failJobFatally(
        kind: ParseFailureKind.parseFailed,
        rulePath: '$_field:$_jsQuotaMarker',
        message: 'the rule exceeded $_maxBindingCalls binding calls',
      );

      return;
    }

    final String text = _limitLogMessage(
      _stringField(message, 'message') ?? '',
    );
    final String line = '[js:$_field] $text';

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

  /// Answers one binding call that had to leave the worker isolate (`http.*` / `parse.*`).
  ///
  /// The script's Promise stays pending until this answers it, so every branch ends in a
  /// reply — or in [_failJobFatally], which decides the job and still tells the script, so
  /// no rule is left waiting on a Promise that never settles.
  void _onHostCall(Map<String, Object?> message) {
    final JsHostCall? call = JsHostCall.fromJson(message);
    if (call == null) {
      _logger.warning('Ignoring a malformed JS host call envelope');

      return;
    }
    if (_fatalFailure != null) {
      // 已经定案的 job 不再花钱：剩下的调用只拒绝回答。
      _reply(JsHostReply.rejected(call.callId, 'the job already failed'));

      return;
    }
    if (_countCall()) {
      _failJobFatally(
        kind: ParseFailureKind.parseFailed,
        rulePath: '$_field:$_jsQuotaMarker',
        message: 'the rule exceeded $_maxBindingCalls binding calls',
        callId: call.callId,
      );

      return;
    }

    switch (call.binding) {
      case jsHttpBinding:
        unawaited(_serveHttp(call));
      case jsParseBinding:
        unawaited(_serveParse(call));
      default:
        // 白名单外的频道：显式拒绝该调用（C-SRC-3），不静默返回 undefined。
        _reply(
          JsHostReply.rejected(call.callId, 'unknown binding: ${call.binding}'),
        );
    }
  }

  /// Runs one `http.*` call through the request layer (C-NET-1, §6).
  ///
  /// A transport failure **rejects the script's Promise** instead of failing the job: a
  /// rule may catch it and try a mirror, and the request layer has already logged the
  /// reason. The book source's own `header` field is applied under the rule's own
  /// headers (C-NET-4), and [JsSourceInfo.url] keys the same concurrency budget the page
  /// fetch spends (`book-source.md` §8), so a rule cannot dodge it.
  Future<void> _serveHttp(JsHostCall call) async {
    final JsHttpRequest? request = decodeJsHttpRequest(call.args);
    if (request == null) {
      _reply(JsHostReply.rejected(call.callId, 'malformed http call'));

      return;
    }
    final JsJob? job = _inFlightJob;
    if (job == null) {
      _reply(JsHostReply.rejected(call.callId, 'no job is running'));

      return;
    }

    final Map<String, String> headers = mergeJsHttpHeaders(
      job.sourceHeaders,
      request.headers,
    );
    final String sourceId = job.source.url;
    final ParseResult<HttpResponse> response = switch (request.method) {
      JsHttpMethod.get => await _http.get(
        request.url,
        rulePath: job.rulePath,
        headers: headers,
        sourceId: sourceId.isEmpty ? null : sourceId,
      ),
      JsHttpMethod.post => await _http.post(
        request.url,
        rulePath: job.rulePath,
        body: request.body,
        headers: headers,
        sourceId: sourceId.isEmpty ? null : sourceId,
      ),
    };

    if (_inFlightJob != job) {
      // 请求回来时 job 已经结束了（结果先到 / 硬预算杀掉）：答复已无处可去。
      return;
    }
    if (_fatalFailure != null) {
      _reply(JsHostReply.rejected(call.callId, 'the job already failed'));

      return;
    }

    switch (response) {
      case ParseSuccess<HttpResponse>(:final HttpResponse data):
        _reply(JsHostReply.success(call.callId, data.body));
      case ParseFailure<HttpResponse>(:final ParseFailureKind kind):
        _reply(JsHostReply.rejected(call.callId, kind.name));
    }
  }

  /// Runs one `parse.*` call through the engine's evaluator (§6).
  ///
  /// A nested rule's failure is the **job's** failure, not something the script may
  /// swallow: the engine reports the boundaries of §6 (`js:parse-scope`,
  /// `js:parse-recursion`) as `unsupportedRule`, and ADR-0029 §决策 5 requires them to be
  /// explicit. A job without an evaluator — an element-level scope — fails the same way.
  Future<void> _serveParse(JsHostCall call) async {
    final JsParseRequest? request = decodeJsParseRequest(call.args);
    if (request == null) {
      _reply(JsHostReply.rejected(call.callId, 'malformed parse call'));

      return;
    }
    final JsJob? job = _inFlightJob;
    final JsParseEvaluator? evaluator = job?.parseEvaluator;
    if (job == null || evaluator == null) {
      _failJobFatally(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: '$_field:$jsParseScopeMarker',
        message: 'parse.* needs the page scope',
        callId: call.callId,
      );

      return;
    }

    final ParseResult<Object?> parsed = await evaluator(request);
    if (_inFlightJob != job) {
      return;
    }
    if (_fatalFailure != null) {
      _reply(JsHostReply.rejected(call.callId, 'the job already failed'));

      return;
    }

    switch (parsed) {
      case ParseSuccess<Object?>(:final Object? data):
        _reply(JsHostReply.success(call.callId, data));
      case ParseFailure<Object?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        _failJobFatally(
          kind: kind,
          rulePath: rulePath,
          message: kind.name,
          callId: call.callId,
        );
    }
  }

  /// Counts one host call against §6's per-rule quota, `true` when it is the one over it.
  bool _countCall() {
    _bindingCalls++;

    return _bindingCalls > _maxBindingCalls;
  }

  /// Decides the job at a boundary the script may not swallow (§6).
  ///
  /// The answer is **recorded, not delivered**: the script is very likely still running (it was
  /// awaiting the call that failed), and the worker must not be handed to the next job while it
  /// is — two evaluations on one runtime would share `globalThis` and the engine's job queue.
  /// The recorded answer is therefore delivered when the worker reports the abandoned script's
  /// own result (or the hard budget gives up on it, in which case the job fails as a timeout).
  /// The script is told immediately (a fatal call rejects its Promise), so a rule that awaits it
  /// does not hang, and every further binding call is refused while the decision stands.
  void _failJobFatally({
    required ParseFailureKind kind,
    required String rulePath,
    required String message,
    int? callId,
  }) {
    if (_inFlight == null) {
      _logger.warning('A JS host call failed a job that was no longer running');

      return;
    }
    if (_fatalFailure != null) {
      return;
    }
    if (callId != null) {
      _reply(
        JsHostReply.fatal(
          callId: callId,
          kind: kind,
          rulePath: rulePath,
          message: message,
        ),
      );
    }
    _logger.warning(
      'JS job failed at a registered boundary: field=$rulePath '
      'kind=${kind.name}',
    );
    _fatalFailure = failureAt<Object?>(kind: kind, rulePath: rulePath);
  }

  /// Sends one answer back to the waiting script.
  void _reply(JsHostReply reply) => _handle.send(reply.toJson());

  /// Kills a worker that ignored its own interrupt and rebuilds on the next job.
  void _onBudgetExpired() {
    if (_inFlight == null) {
      return;
    }
    final String rulePath = _field;
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
    final String rulePath = _field;
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
    _clearInFlight();
    if (inFlight != null && !inFlight.isCompleted) {
      inFlight.complete(result);
    }
  }

  /// Forgets the job in flight: its budget, its call quota and the job itself.
  void _clearInFlight() {
    _inFlight = null;
    _inFlightJob = null;
    _fatalFailure = null;
    _bindingCalls = 0;
  }
}

/// Reads a `String` field of an envelope, ignoring a value of another type.
String? _stringField(Map<String, Object?> message, String key) {
  final Object? value = message[key];

  return value is String ? value : null;
}

/// Reads the variable map a worker reports back with a result (`book-source.md` §6).
///
/// A `null` value is kept: it is how a script spells “clear this variable”
/// (`java.put(key, null)`), and turning it into `''` would make cleared and empty
/// indistinguishable in the store. Anything that is not a string map is ignored rather
/// than fixed up — the envelope is transport, not a place to invent data.
Map<String, String?> _reportedVariables(Object? value) {
  if (value is! Map) {
    return const <String, String?>{};
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
