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

/// Single-evaluation wall-clock budget.
const Duration defaultJsTimeout = Duration(seconds: 5);

/// Single-evaluation QuickJS heap limit.
const int defaultJsMemoryLimitBytes = 32 * 1024 * 1024;

/// Time the bridge waits past the runtime's own interrupt before killing.
///
/// The runtime interrupts a runaway script itself and stays usable, so the kill is
/// only the fallback for an interrupt that did not work.
const Duration defaultJsKillGrace = Duration(seconds: 2);

const String _jsTimeoutMarker = 'js:timeout';

const String _jsErrorMarker = 'js:error';

/// Longest `log.*` message the bridge forwards.
///
/// Without a bound, `log.debug(result)` on a large page would write the whole page
/// into the log sink.
const int maxJsLogMessageLength = 2000;

const String _jsQuotaMarker = 'js:quota';

/// Longest chain of binding calls one rule may make.
///
/// Only calls that cross to the host count; `crypto.*` is answered in the worker.
const int defaultJsMaxBindingCalls = 20;

/// [JsBridge] backed by one resident worker isolate with one reused runtime.
///
/// Jobs run in FIFO order under two budgets: the runtime's interrupt and a hard
/// kill-and-rebuild budget. The isolate itself stays behind [JsWorkerLauncher].
final class QuickJsWorkerBridge implements JsBridge {
  /// Creates a bridge that starts workers through `launch`.
  ///
  /// `timeout` is both the runtime's interrupt budget and the bridge's accounting
  /// budget; `maxBindingCalls` is the per-rule quota, counted here.
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
    // 排队中的 job 由 _pump 在在途 job 结束后按 _disposed 取消，这里不再清队列。
    await session?.close();
  }

  // 按调用顺序逐个执行排队 job；单个 job 失败不影响队列。
  Future<void> _pump() async {
    if (_pumping) {
      return;
    }
    _pumping = true;
    try {
      while (_pending.isNotEmpty) {
        final _PendingJob pending = _pending.removeFirst();
        // dispose 之后不再拉起新 worker，否则会给排队 job 又开一个隔离体。
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

  Future<ParseResult<Object?>> _run(JsJob job) async {
    try {
      final _WorkerSession session = await _currentSession();

      return await session.run(job);
    } on IsolateSpawnException catch (error, stackTrace) {
      // 隔离体起不来（进程资源耗尽）：报 js:error，不把异常抛给调用方。
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

// 被丢弃的 job 得到 cancelled，路径保持裸字段（不加 js:* 标记）。
ParseFailure<Object?> _cancelledFailure(String rulePath) =>
    failureAt<Object?>(kind: ParseFailureKind.cancelled, rulePath: rulePath);

final class _PendingJob {
  _PendingJob(this.job);

  final JsJob job;
  final Completer<ParseResult<Object?>> completer =
      Completer<ParseResult<Object?>>();
}

// 一个存活的 worker，加上当前 job 的预算、配额与绑定调用答复。
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

  // 下一个 job 之前是否需要换掉这个 worker。
  bool get isDead => _dead;

  // 在途 job 的字段路径；没有在途 job 时用中性值。
  String get _field => _inFlightJob?.rulePath ?? 'js';

  // 预算与配额从这里开始计时，排队等待的时间不计入。
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

  // 先让 worker 释放原生运行时再杀：Isolate.kill 不跑析构，直接杀会漏 QuickJS 堆。
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
        // 未知信封不静默丢弃：记 warning 后忽略。
        _logger.warning(
          'Ignoring an unknown JS worker message: type='
          '${_stringField(message, 'type') ?? 'missing'}',
        );
    }
  }

  void _onResult(Map<String, Object?> message) {
    if (_inFlight == null) {
      // 已被硬预算杀掉的 job 可能仍回一条结果：丢弃并留痕。
      _logger.debug('Ignoring a JS result that no job is waiting for');

      return;
    }

    // 先落地脚本的 java.put 写入（上游写入立即生效），再决定 job 的答案。
    final JsJob? job = _inFlightJob;
    if (job != null) {
      _variables.merge(job.source.url, decodeJsVariables(message['variables']));
    }

    // 边界失败已经定了答案，脚本自己写出的值不再算数。
    final ParseResult<Object?>? fatal = _fatalFailure;
    if (fatal != null) {
      _completeInFlight(fatal);

      return;
    }

    if (message['ok'] == true) {
      _completeInFlight(ParseSuccess<Object?>(message['value']));

      return;
    }

    // 中断和脚本异常都表现为 isError，用耗时区分：跑满预算才算超时。
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

  // 日志按字段打标，超长文本截断并标记，而不是静默丢掉尾巴。
  void _onLog(Map<String, Object?> message) {
    if (_fatalFailure != null) {
      // 这个 job 已定案，后续日志不再影响结果。
      return;
    }
    if (_inFlightJob != null && _countCall()) {
      // 额度含 log.*：狂写日志与递归 parse 一样会霸占 worker。
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

  void _onHostCall(Map<String, Object?> message) {
    final JsHostCall? call = JsHostCall.fromJson(message);
    if (call == null) {
      _logger.warning('Ignoring a malformed JS host call envelope');

      return;
    }
    if (_fatalFailure != null) {
      // 已定案的 job 不再花钱：剩下的调用只拒绝回答。
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
        // 白名单外的频道显式拒绝，不静默返回 undefined。
        _reply(
          JsHostReply.rejected(call.callId, 'unknown binding: ${call.binding}'),
        );
    }
  }

  // 传输失败只拒绝脚本的 Promise（规则可换镜像重试），不直接判 job 失败。
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
      // 请求回来时 job 已经结束：答复无处可去。
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

  // 内层规则失败就是 job 的失败，不允许脚本吞掉；没有页级 scope 也一样。
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

  // 记一次宿主调用；返回 true 表示这次已超出配额。
  bool _countCall() {
    _bindingCalls++;

    return _bindingCalls > _maxBindingCalls;
  }

  // 边界失败先记账、不立刻交付：脚本可能还在跑，运行时不能交给下一个 job。
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

  void _reply(JsHostReply reply) => _handle.send(reply.toJson());

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

  void _onWorkerError(Object error, StackTrace stackTrace) {
    _logger.warning(
      'JS worker message stream failed',
      describeError(error),
      stackTrace,
    );
    _onWorkerDone();
  }

  void _completeInFlight(ParseResult<Object?> result) {
    final Completer<ParseResult<Object?>>? inFlight = _inFlight;
    _budget?.cancel();
    _budget = null;
    _clearInFlight();
    if (inFlight != null && !inFlight.isCompleted) {
      inFlight.complete(result);
    }
  }

  void _clearInFlight() {
    _inFlight = null;
    _inFlightJob = null;
    _fatalFailure = null;
    _bindingCalls = 0;
  }
}

String? _stringField(Map<String, Object?> message, String key) {
  final Object? value = message[key];

  return value is String ? value : null;
}

String _limitLogMessage(String text) {
  if (text.length <= maxJsLogMessageLength) {
    return text;
  }
  final int dropped = text.length - maxJsLogMessageLength;

  return '${text.substring(0, maxJsLogMessageLength)}'
      '…[truncated $dropped chars]';
}

int? _intField(Map<String, Object?> message, String key) {
  final Object? value = message[key];

  return value is int ? value : null;
}
