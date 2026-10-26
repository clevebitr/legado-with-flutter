// 私有字段不能做具名初始化形参（Dart 限制），两个可选端口只能手写赋值；
// prefer_initializing_formals 在这里是误报。
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_lib.dart';
import 'package:flutter_reader/core/js/js_sync_call.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/source_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_reader/core/platform/user_messages.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';

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

/// The marker of a job that needed more synchronous fetches than the pass limit allows.
const String _jsReplayMarker = 'js:replay';

// 验证答案按 `op + url` 记忆；NUL 不会出现在两者里，拼不出两项相撞的键。
const String _answerKeySeparator = '\u0000';

/// Longest chain of binding calls one rule may make.
///
/// Only calls that cross to the host count; `crypto.*` is answered in the worker. A synchronous
/// replay fetch starts a new pass, so the quota is per pass rather than per job
/// (ADR-0076 §决策 1).
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
    SourceVerification? verification,
    WebPageFetcher? webPages,
    CookieManager? cookies,
    SourceVariableStore? sourceVariables,
    UserMessages userMessages = const UnboundUserMessages(),
    this._timeout = defaultJsTimeout,
    this._killGrace = defaultJsKillGrace,
    this._memoryLimit = defaultJsMemoryLimitBytes,
    this._maxBindingCalls = defaultJsMaxBindingCalls,
  }) : _verification = verification,
       _webPages = webPages,
       _cookies = cookies,
       _sourceVariables = sourceVariables,
       _userMessages = userMessages;

  final AppLogger _logger;
  final JsWorkerLauncher _launch;
  final HttpClient _http;
  final JsVariableStore _variables;
  final Duration _timeout;
  final Duration _killGrace;
  final int _memoryLimit;
  final int _maxBindingCalls;
  final SourceVerification? _verification;
  final WebPageFetcher? _webPages;
  final CookieManager? _cookies;
  final SourceVariableStore? _sourceVariables;
  final UserMessages _userMessages;

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
      verification: _verification,
      webPages: _webPages,
      cookies: _cookies,
      sourceVariables: _sourceVariables,
      userMessages: _userMessages,
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
    required this._verification,
    required this._webPages,
    required CookieManager? cookies,
    required SourceVariableStore? sourceVariables,
    required UserMessages userMessages,
  }) : _cookies = cookies,
       _sourceVariables = sourceVariables,
       _userMessages = userMessages {
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
  final SourceVerification? _verification;
  final WebPageFetcher? _webPages;
  final CookieManager? _cookies;
  final SourceVariableStore? _sourceVariables;
  final UserMessages _userMessages;

  /// Milliseconds the job's wall clock spent on something other than its own CPU.
  ///
  /// The budget protects the CPU, not the network and not the user: waiting for a human
  /// (ADR-0068 §决策 5) and waiting for a page that a synchronous `java.*` call forced
  /// (ADR-0076 §决策 1) are both subtracted from `elapsedMs`, so neither can be mistaken for a
  /// runaway script.
  int _budgetPausedMs = 0;

  // 一趟重放里已经弹过的窗 / 已经贴过的消息（ADR-0076 §决策 1/4）。
  final Map<String, Object?> _verifyAnswers = <String, Object?>{};
  final Set<String> _toasts = <String>{};

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
    _budgetPausedMs = 0;
    _verifyAnswers.clear();
    _toasts.clear();
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

    // 先落地脚本的 java.put 与 source.setVariable 写入（上游写入立即生效），再决定 job 的答案。
    final JsJob? job = _inFlightJob;
    if (job != null) {
      _variables.merge(job.source.url, decodeJsVariables(message['variables']));
      // 每源变量是**持久**的（ADR-0076 §决策 1）：交给 store 去写穿，失败只记 warning。
      _sourceVariables?.merge(
        job.source.url,
        decodeJsVariables(message['sourceVariables']),
      );
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

    // 库脚本（`jsLib`）坏了要能和规则自己的错区分开：两者的修法完全不同（ADR-0078 S1）。
    if (message['libError'] == true) {
      _logger.warning('The source jsLib failed: field=$_field');
      _completeInFlight(
        failureAt<Object?>(
          kind: ParseFailureKind.parseFailed,
          rulePath: '$_field:$jsLibMarker',
        ),
      );

      return;
    }

    // 重放超限是一个**自己的**边界：把「这条规则重放不了」告诉调用方，而不是报成 js:timeout 或
    // 一个看不出所以然的 js:error（ADR-0076 §决策 1 的后果）。
    if (message['replayLimit'] == true) {
      _logger.warning(
        'JS rule needed more replay passes than the limit: field=$_field',
      );
      _completeInFlight(
        failureAt<Object?>(
          kind: ParseFailureKind.parseFailed,
          rulePath: '$_field:$_jsReplayMarker',
        ),
      );

      return;
    }

    // 中断和脚本异常都表现为 isError，用耗时区分：跑满预算才算超时。
    final int elapsedMs = _intField(message, 'elapsedMs') ?? 0;
    final Object? error = message['error'];
    // 等用户 / 等同步取页的时间不计入超时判定：跑满预算才叫超时（ADR-0068 §决策 5）。
    final int activeMs = elapsedMs - _budgetPausedMs;
    if (activeMs >= _timeout.inMilliseconds) {
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
    // toast 是一次性 UI 事件，不占额度也不受预算影响：规则已经跑了，消息要么贴要么不贴。
    if (call.binding == jsToastBinding) {
      _serveToast(call);

      return;
    }
    // 同步族取页等的是网络，不是规则自己的 CPU（ADR-0076 §决策 1），所以得像验证族那样免额度。
    if (call.binding != jsVerifyBinding && _countCall()) {
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
      case jsVerifyBinding:
        unawaited(_serveVerify(call));
      case jsSyncBinding:
        unawaited(_serveSync(call));
      default:
        // 白名单外的频道显式拒绝，不静默返回 undefined。
        _reply(
          JsHostReply.rejected(call.callId, 'unknown binding: ${call.binding}'),
        );
    }
  }

  // 验证族（ADR-0068 §决策 5）：这些调用等的是人，因此等的时候**不打表**。
  //
  // 上游的 Rhino 可以同步阻塞线程；本仓的沙箱不能让 QuickJS 停下来等宿主，所以这三个名字返回
  // Promise（规则里要 `await`，差异登记在 `book-source.md` §6）。等待期间：
  // * 每规则的调用额度不扣（它数的是 CPU 侧的往返）；
  // * 硬预算暂停，完成后重新计时（预算保护的是 CPU，不是人的耐心）；
  // * 等掉的时间从 `elapsedMs` 里减掉，否则 3 分钟的验证会被判成 `js:timeout`。
  //
  // 重放层落地以后多一条：同一次 `op+url` 的答案在本 job 内记下来（`_verifyAnswers`），
  // 下一趟重放**不再弹窗**，直接答上次的答案——否则一个 `java.ajax` 就要把验证码问用户两次
  // （ADR-0076 §决策 4）。
  Future<void> _serveVerify(JsHostCall call) async {
    final JsVerifyRequest? request = decodeJsVerifyRequest(call.args);
    if (request == null) {
      _reply(JsHostReply.rejected(call.callId, 'malformed verification call'));

      return;
    }
    final JsJob? job = _inFlightJob;
    if (job == null) {
      _reply(JsHostReply.rejected(call.callId, 'no job is running'));

      return;
    }
    final String sourceUrl = job.source.url;
    final String sourceName = job.source.name;
    final String url = request.url;
    final Map<String, String>? headers = _headersOrNull(job.sourceHeaders);
    final String answerKey =
        '${request.operation.name}$_answerKeySeparator$url';

    // 重放的那一趟：上次已经问过用户了。
    if (_verifyAnswers.containsKey(answerKey)) {
      _reply(JsHostReply.success(call.callId, _verifyAnswers[answerKey]));

      return;
    }

    // `startBrowser` 上游返回 void：先答复再慢慢开页面，规则不会被它挡住。
    final SourceVerification? verification = _verification;
    if (request.operation == JsVerifyOperation.startBrowser) {
      _verifyAnswers[answerKey] = '';
      _reply(JsHostReply.success(call.callId, ''));
      if (verification != null && verification.isSupported) {
        unawaited(
          verification.verify(
            SourceVerificationRequest(
              sourceUrl: sourceUrl,
              sourceName: sourceName,
              url: url,
              title: request.title ?? sourceName,
              headers: headers,
              html: request.html,
            ),
          ),
        );
      }

      return;
    }

    final DateTime startedAt = DateTime.now();
    _budget?.cancel();
    ParseResult<Object?>? reply;
    if (request.operation == JsVerifyOperation.webView) {
      final WebPageFetcher? fetcher = _webPages;
      if (fetcher == null || !fetcher.isSupported) {
        reply = const ParseFailure<Object?>(
          kind: ParseFailureKind.unsupportedRule,
          rulePath: 'java.webView',
        );
      } else {
        final ParseResult<FetchedWebPage> page = await fetcher.fetch(
          url: url,
          headers: headers,
          rulePath: '$_field:webView',
          javaScript: request.script,
        );
        reply = switch (page) {
          ParseSuccess<FetchedWebPage>(:final FetchedWebPage data) =>
            ParseSuccess<Object?>(data.body),
          ParseFailure<FetchedWebPage>(
            :final ParseFailureKind kind,
            :final String rulePath,
          ) =>
            ParseFailure<Object?>(kind: kind, rulePath: rulePath),
        };
      }
    } else if (verification == null || !verification.isSupported) {
      reply = ParseFailure<Object?>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'java.${request.operation.name}',
      );
    } else if (request.operation == JsVerifyOperation.imageCode) {
      final ParseResult<String> code = await verification.imageCode(
        sourceUrl: sourceUrl,
        sourceName: sourceName,
        imageUrl: url,
        title: request.title ?? sourceName,
      );
      reply = switch (code) {
        ParseSuccess<String>(:final String data) => ParseSuccess<Object?>(data),
        ParseFailure<String>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ) =>
          ParseFailure<Object?>(kind: kind, rulePath: rulePath),
      };
    } else {
      final ParseResult<SourceVerificationOutcome> outcome = await verification
          .verify(
            SourceVerificationRequest(
              sourceUrl: sourceUrl,
              sourceName: sourceName,
              url: url,
              title: request.title ?? sourceName,
              headers: headers,
              html: request.html,
              refetchAfterSuccess: request.refetchAfterSuccess,
            ),
          );
      reply = switch (outcome) {
        ParseSuccess<SourceVerificationOutcome>(
          :final SourceVerificationOutcome data,
        ) =>
          ParseSuccess<Object?>(<String, Object?>{
            'url': data.url,
            'body': data.body,
          }),
        ParseFailure<SourceVerificationOutcome>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ) =>
          ParseFailure<Object?>(kind: kind, rulePath: rulePath),
      };
    }
    _budgetPausedMs += DateTime.now().difference(startedAt).inMilliseconds;
    if (_inFlight != null) {
      // 等完之后重新给满预算：脚本接下来还有它自己的那一份执行时间。
      _budget = Timer(_timeout + _killGrace, _onBudgetExpired);
    }
    if (_inFlightJob != job || _fatalFailure != null) {
      _reply(JsHostReply.rejected(call.callId, 'the job already failed'));

      return;
    }

    switch (reply) {
      case ParseSuccess<Object?>(:final Object? data):
        // 记住答案：重放的那一趟不再问用户，而且答得一模一样（ADR-0076 §决策 4）。
        _verifyAnswers[answerKey] = data;
        _reply(JsHostReply.success(call.callId, data));
      case ParseFailure<Object?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        // 验证失败（用户取消 / 要登录 / 平台不支持）是**整个 job 的答案**：脚本吞掉它只会得到
        // 一个没有正文的页面，而 UI 需要看到 cancelled / loginRequired（ADR-0068 §决策 10）。
        _failJobFatally(
          kind: kind,
          rulePath: rulePath,
          message: 'verification failed: ${kind.name}',
          callId: call.callId,
        );
    }
  }

  /// An empty header map and “no headers” are the same thing for a request.
  static Map<String, String>? _headersOrNull(Map<String, String>? headers) =>
      headers == null || headers.isEmpty ? null : headers;

  /// Serves one **synchronous** call the worker could not answer from its replay cache.
  ///
  /// The worker raises a sentinel on a miss, waits for this answer, stores it and runs the script
  /// again from its first line (ADR-0076 §决策 1); the script therefore never sees a Promise where
  /// upstream hands it a value.
  ///
  /// Two budget decisions live here:
  /// * a fetch starts a **new pass**, so the per-rule call quota restarts — otherwise sixteen
  ///   passes of a rule that also calls `http.*` would run out of quota for no reason;
  /// * the hard budget is paused while the page is in flight and the wait is subtracted from
  ///   `elapsedMs`: the budget protects the CPU, not the network.
  ///
  /// A transport failure is answered as a **rejection**, not as a fatal failure: upstream's
  /// `java.ajax` throws, so the rule's own `try` / `catch` (a mirror URL, a second attempt) still
  /// works. The worker caches the failure, which is what stops a replay loop.
  Future<void> _serveSync(JsHostCall call) async {
    final JsSyncRequest? request = decodeJsSyncRequest(call.args);
    if (request == null) {
      _reply(JsHostReply.rejected(call.callId, 'malformed synchronous call'));

      return;
    }
    final JsJob? job = _inFlightJob;
    if (job == null) {
      _reply(JsHostReply.rejected(call.callId, 'no job is running'));

      return;
    }

    _bindingCalls = 0;
    final DateTime startedAt = DateTime.now();
    _budget?.cancel();
    final ParseResult<Object?> reply = await _answerSync(request, job);
    _budgetPausedMs += DateTime.now().difference(startedAt).inMilliseconds;
    if (_inFlight != null) {
      _budget = Timer(_timeout + _killGrace, _onBudgetExpired);
    }
    if (_inFlightJob != job || _fatalFailure != null) {
      _reply(JsHostReply.rejected(call.callId, 'the job already failed'));

      return;
    }

    switch (reply) {
      case ParseSuccess<Object?>(:final Object? data):
        _reply(JsHostReply.success(call.callId, data));
      case ParseFailure<Object?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        _logger.warning(
          'Synchronous JS fetch failed: field=$rulePath kind=${kind.name}',
        );
        _reply(JsHostReply.rejected(call.callId, kind.name));
    }
  }

  /// Performs one synchronous call and answers what the script will receive.
  Future<ParseResult<Object?>> _answerSync(
    JsSyncRequest request,
    JsJob job,
  ) async {
    final String sourceId = job.source.url;
    switch (request.operation) {
      case JsSyncOperation.ajax:
        final ParseResult<HttpResponse> response = await _http.get(
          request.url,
          rulePath: job.rulePath,
          headers: _headersOrNull(
            mergeJsHttpHeaders(job.sourceHeaders, request.headers),
          ),
          sourceId: sourceId.isEmpty ? null : sourceId,
        );

        return switch (response) {
          ParseSuccess<HttpResponse>(:final HttpResponse data) =>
            ParseSuccess<Object?>(data.body),
          ParseFailure<HttpResponse>(
            :final ParseFailureKind kind,
            :final String rulePath,
          ) =>
            ParseFailure<Object?>(kind: kind, rulePath: rulePath),
        };
      case JsSyncOperation.post:
      case JsSyncOperation.head:
        final Map<String, String> headers = mergeJsHttpHeaders(
          job.sourceHeaders,
          request.headers,
        );
        final ParseResult<HttpResponse> response =
            request.operation == JsSyncOperation.post
            ? await _http.post(
                request.url,
                rulePath: job.rulePath,
                body: request.body,
                headers: headers,
                sourceId: sourceId.isEmpty ? null : sourceId,
              )
            : await _http.head(
                request.url,
                rulePath: job.rulePath,
                headers: _headersOrNull(headers),
                sourceId: sourceId.isEmpty ? null : sourceId,
              );

        return switch (response) {
          ParseSuccess<HttpResponse>(:final HttpResponse data) =>
            ParseSuccess<Object?>(
              jsResponsePayload(
                url: data.url,
                body: data.body,
                code: data.statusCode,
                headers: data.headers,
              ),
            ),
          ParseFailure<HttpResponse>(
            :final ParseFailureKind kind,
            :final String rulePath,
          ) =>
            ParseFailure<Object?>(kind: kind, rulePath: rulePath),
        };
      case JsSyncOperation.getCookie:
      case JsSyncOperation.cookieGet:
        return _readCookie(request, job);
      case JsSyncOperation.cookieSet:
        return _writeCookie(request, job);
      case JsSyncOperation.cookieRemove:
        return _removeCookie(request, job);
    }
  }

  // 读 Cookie 走内存宗（`cookieHeaderFor` 同步），所以这一路真的不需要等。
  //
  // 地址不再校验：它已经是规则拼出来的字符串，`Uri.parse` 对任何字符串都能给出一个值，
  // 宗里没有匹配的域就答空——与浏览器一致，也不必为「畸形地址」留一条不可达分支。
  ParseResult<Object?> _readCookie(JsSyncRequest request, JsJob job) {
    final CookieManager? cookies = _cookies;
    if (cookies == null) {
      return _unsupportedSync('cookie.getCookie', job);
    }
    final String? header = cookies.cookieHeaderFor(Uri.parse(request.url));
    final String? key = request.key;
    if (key == null) {
      // 不带名字时上游答整条 Cookie 头；没有时答空串（规则常常直接拼进 header）。
      return ParseSuccess<Object?>(header ?? '');
    }

    return ParseSuccess<Object?>(cookieValueOf(header, key));
  }

  ParseResult<Object?> _writeCookie(JsSyncRequest request, JsJob job) {
    final CookieManager? cookies = _cookies;
    final String body = request.body ?? request.key ?? '';
    if (cookies == null) {
      return _unsupportedSync('cookie.setCookie', job);
    }
    final Uri url = Uri.parse(request.url);
    // `cookie.setCookie(url, value)` 可以传一对，也可以传整条 `a=1; b=2`：上游交给 CookieManager
    // 的就是后者，所以逐对交下去，而不是把第二对当成第一对的属性。
    final List<String> pairs = <String>[
      for (final String pair in body.split(';'))
        if (pair.contains('=')) pair.trim(),
    ];
    if (pairs.isEmpty) {
      return _unsupportedSync('cookie.setCookie', job);
    }
    for (final String pair in pairs) {
      cookies.storeFromResponse(url, <String>[pair]);
    }

    return const ParseSuccess<Object?>('');
  }

  ParseResult<Object?> _removeCookie(JsSyncRequest request, JsJob job) {
    final String? key = request.key;
    final CookieManager? cookies = _cookies;
    if (cookies == null || key == null || key.isEmpty) {
      return _unsupportedSync('cookie.removeCookie', job);
    }
    // 空值 + Max-Age=0 就是删除指令，CookieManager 与持久化层都认这个形状。
    cookies.storeFromResponse(Uri.parse(request.url), <String>[
      '$key=; Max-Age=0',
    ]);

    return const ParseSuccess<Object?>('');
  }

  ParseFailure<Object?> _unsupportedSync(String name, JsJob job) =>
      ParseFailure<Object?>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: '${job.rulePath}:$name',
      );

  // toast 是一次性 UI 事件：同一句在一个 job 里只贴一次（重放会把同一行再走一遍）。
  void _serveToast(JsHostCall call) {
    final JsToastRequest? request = decodeJsToastRequest(call.args);
    if (request == null) {
      _reply(JsHostReply.rejected(call.callId, 'malformed toast call'));

      return;
    }
    if (_toasts.add(request.message)) {
      _logger.info('[js:$_field] toast: ${_limitLogMessage(request.message)}');
      _userMessages.show(request.message);
    }
    _reply(JsHostReply.success(call.callId, ''));
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
    // 字节门（字体文件）：正文按 base64 交给脚本，绝不走文本解码。
    if (request.method == JsHttpMethod.getBytes) {
      final ParseResult<Uint8List> bytes = await _http.getBytes(
        request.url,
        rulePath: job.rulePath,
        headers: headers,
        sourceId: sourceId.isEmpty ? null : sourceId,
      );
      if (_inFlightJob != job) {
        return;
      }
      if (_fatalFailure != null) {
        _reply(JsHostReply.rejected(call.callId, 'the job already failed'));

        return;
      }
      switch (bytes) {
        case ParseSuccess<Uint8List>(:final Uint8List data):
          _reply(JsHostReply.success(call.callId, base64Encode(data)));
        case ParseFailure<Uint8List>(:final ParseFailureKind kind):
          _reply(JsHostReply.rejected(call.callId, kind.name));
      }

      return;
    }
    // `getBytes` 已在上面提前返回；剩下的两种动词就是 POST 与 GET。
    final ParseResult<HttpResponse> response =
        request.method == JsHttpMethod.post
        ? await _http.post(
            request.url,
            rulePath: job.rulePath,
            body: request.body,
            headers: headers,
            sourceId: sourceId.isEmpty ? null : sourceId,
          )
        : await _http.get(
            request.url,
            rulePath: job.rulePath,
            headers: headers,
            sourceId: sourceId.isEmpty ? null : sourceId,
          );

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
        _reply(
          JsHostReply.success(
            call.callId,
            request.wantsResponse
                ? <String, Object?>{
                    // 与 loginCheckJs 的响应对象同形（ADR-0068 增补）：worker 用
                    // __sandboxValue 把它变成 body 属性 + url()/code()/headers() 方法。
                    '__strResponse': true,
                    'body': data.body,
                    '__url': data.url,
                    '__code': data.statusCode,
                    '__headers': <String, String>{
                      for (final MapEntry<String, List<String>> entry
                          in data.headers.entries)
                        entry.key: entry.value.join(', '),
                    },
                  }
                : data.body,
          ),
        );
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
