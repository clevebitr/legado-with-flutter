import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_reader/core/js/source_info_map.dart';
import 'package:flutter_reader/core/js/source_login_header.dart';
import 'package:flutter_reader/core/js/source_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/platform/external_url_opener.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_reader/core/platform/user_messages.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_http_client.dart';
import '../../support/fake_js_worker.dart';
import '../../support/fake_log_printer.dart';

/// Bridge under test plus the doubles it talks to.
typedef _Fixture = ({
  QuickJsWorkerBridge bridge,
  FakeLogPrinter printer,
  List<FakeJsWorkerHandle> workers,
  FakeHttpClient http,
  JsVariableStore variables,
  SourceVariableStore sourceVariables,
  SourceLoginHeaderStore loginHeaders,
  SourceInfoMapStore infoMaps,
  _FakeExternalUrlOpener opener,
  InMemoryCookieManager cookies,
  _FakeUserMessages messages,
  _FakeVerification verification,
  _FakeWebPages webPages,
});

/// Builds a bridge whose launcher hands out [FakeJsWorkerHandle]s.
///
/// The budgets are injectable (and the timeout tests push them into the millisecond
/// range) because `docs/dev/testing.md` §6 forbids waiting for the real five seconds.
/// [maxBindingCalls] is injectable for the same reason: §6's default of twenty would
/// force a test to make twenty calls to see the quota.
_Fixture _buildBridge({
  Duration timeout = const Duration(seconds: 5),
  Duration killGrace = const Duration(seconds: 2),
  int maxBindingCalls = defaultJsMaxBindingCalls,
  JsVariableStore? variables,
  SourceVariableStore? sourceVariables,
  SourceLoginHeaderStore? loginHeaders,
  SourceInfoMapStore? infoMaps,
  _FakeExternalUrlOpener? opener,
  InMemoryCookieManager? cookies,
  bool bindCookies = true,
  void Function(FakeJsWorkerHandle worker)? configure,
  _FakeVerification? verification,
  _FakeWebPages? webPages,
}) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final List<FakeJsWorkerHandle> workers = <FakeJsWorkerHandle>[];
  final FakeHttpClient http = FakeHttpClient();
  final JsVariableStore store = variables ?? JsVariableStore();
  final SourceVariableStore sourceStore =
      sourceVariables ?? SourceVariableStore();
  final SourceLoginHeaderStore loginHeaderStore =
      loginHeaders ?? SourceLoginHeaderStore();
  final SourceInfoMapStore infoMapStore = infoMaps ?? SourceInfoMapStore();
  final _FakeExternalUrlOpener fakeOpener = opener ?? _FakeExternalUrlOpener();
  final InMemoryCookieManager cookieJar = cookies ?? InMemoryCookieManager();
  final _FakeUserMessages messages = _FakeUserMessages();
  final _FakeVerification fakeVerification =
      verification ?? _FakeVerification();
  final _FakeWebPages fakePages = webPages ?? _FakeWebPages();

  return (
    bridge: QuickJsWorkerBridge(
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      launch: ({required Duration timeout, required int memoryLimit}) async {
        final FakeJsWorkerHandle worker = FakeJsWorkerHandle();
        // 配置在 worker 收到第一个 job 之前发生，所以测试可以预置它要回的回复。
        configure?.call(worker);
        workers.add(worker);

        return worker;
      },
      http: http,
      variables: store,
      timeout: timeout,
      killGrace: killGrace,
      maxBindingCalls: maxBindingCalls,
      verification: fakeVerification,
      webPages: fakePages,
      cookies: bindCookies ? cookieJar : null,
      sourceVariables: sourceStore,
      loginHeaders: loginHeaderStore,
      infoMaps: infoMapStore,
      externalUrlOpener: fakeOpener,
      androidId: 'test-install-id',
      userMessages: messages,
    ),
    printer: printer,
    workers: workers,
    http: http,
    variables: store,
    sourceVariables: sourceStore,
    loginHeaders: loginHeaderStore,
    infoMaps: infoMapStore,
    opener: fakeOpener,
    cookies: cookieJar,
    messages: messages,
    verification: fakeVerification,
    webPages: fakePages,
  );
}

/// A job whose script decides what the fake worker answers (see [FakeJsWorkerHandle]).
JsJob _job({
  String script = 'result',
  String rulePath = 'searchRule.name',
  JsParseEvaluator? parseEvaluator,
  Map<String, String>? sourceHeaders,
  String? jsLib,
}) => JsJob(
  script: script,
  rulePath: rulePath,
  baseUrl: 'https://example-novel.test/search',
  page: 2,
  source: _sourceInfo(),
  result: 'raw',
  sourceHeaders: sourceHeaders,
  parseEvaluator: parseEvaluator,
  jsLib: jsLib,
);

/// The envelope a host call of binding [binding] travels in.
Map<String, Object?> _hostCall(int callId, String binding, Object? args) =>
    <String, Object?>{
      'type': 'host',
      'callId': callId,
      'binding': binding,
      'args': args,
    };

/// The `hostResult` envelopes [worker] was sent, in order.
List<Map<String, Object?>> _replies(FakeJsWorkerHandle worker) =>
    <Map<String, Object?>>[
      for (final Map<String, Object?> envelope in worker.sent)
        if (envelope['type'] == 'hostResult') envelope,
    ];

/// The sandbox view of the corpus source.
///
/// [group] is a parameter on purpose: a `const` construction is evaluated at compile
/// time, which would leave [JsSourceInfo]'s constructor line unmeasured by the coverage
/// gate (ADR-0019).
JsSourceInfo _sourceInfo([String group = '测试分组']) =>
    JsSourceInfo(name: '示例书源', url: 'https://example-novel.test', group: group);

/// The script of one `evaluate` envelope the fake received.
Object? _scriptOf(Map<String, Object?> envelope) {
  final Object? job = envelope['job'];

  return job is Map ? job['script'] : null;
}

/// Ends the in-flight `hold` job so a test does not wait for the bridge's budget.
///
/// The bridge's timers are the only thing left running once a test has seen its reply; folding the
/// ending into one place keeps the suite free of five-second waits (`docs/dev/testing.md` §8).
Future<ParseResult<Object?>> _finish(
  FakeJsWorkerHandle worker,
  Future<ParseResult<Object?>> call,
) {
  worker.emit(<String, Object?>{
    'type': 'result',
    'ok': true,
    'value': 'done',
    'elapsedMs': 0,
  });

  return call;
}

/// Returns the failure of [result], failing the test when it succeeded.
ParseFailure<Never> _failure(ParseResult<Object?> result) => switch (result) {
  ParseFailure<Object?>(:final ParseFailureKind kind, :final String rulePath) =>
    ParseFailure<Never>(kind: kind, rulePath: rulePath),
  ParseSuccess<Object?>() => fail('Expected a failure.'),
};

/// Records what a rule asked a human for (`docs/dev/testing.md` §4).
final class _FakeVerification implements SourceVerification {
  /// The outcome `verify` answers with.
  ParseResult<SourceVerificationOutcome> outcome =
      const ParseSuccess<SourceVerificationOutcome>(
        SourceVerificationOutcome(
          url: 'https://example-novel.test/after',
          body: '<p>solved</p>',
        ),
      );

  /// The answer `imageCode` gives.
  ParseResult<String> code = const ParseSuccess<String>('A7bC');

  /// Every request the bridge passed on, in order.
  final List<SourceVerificationRequest> requests =
      <SourceVerificationRequest>[];

  /// Every image captcha asked for, in order.
  final List<String> captchas = <String>[];

  /// Whether the platform can show a page (a test can turn it off).
  bool supported = true;

  /// When set, `verify` / `imageCode` wait for it before answering (job-end races).
  Future<void>? gate;

  @override
  bool get isSupported => supported;

  @override
  Future<ParseResult<SourceVerificationOutcome>> verify(
    SourceVerificationRequest request,
  ) async {
    requests.add(request);
    final Future<void>? waiting = gate;
    if (waiting != null) {
      await waiting;
    }

    return outcome;
  }

  @override
  Future<ParseResult<String>> imageCode({
    required String sourceUrl,
    required String sourceName,
    required String imageUrl,
    required String title,
  }) async {
    captchas.add(imageUrl);
    final Future<void>? waiting = gate;
    if (waiting != null) {
      await waiting;
    }

    return code;
  }
}

/// Records the messages a rule asked the UI to show (`java.toast`).
final class _FakeUserMessages implements UserMessages {
  /// Every message, in order.
  final List<String> messages = <String>[];

  @override
  void show(String message) => messages.add(message);
}

/// Records what `java.openUrl` asked to open (the real one shows a dialog).
final class _FakeExternalUrlOpener implements ExternalUrlOpener {
  /// Every `(url, sourceName)` the bridge handed over, in order.
  final List<(String, String)> opened = <(String, String)>[];

  /// What [open] answers; the bridge ignores it, a test may assert it was awaited.
  bool answer = true;

  @override
  Future<bool> open(String url, {String sourceName = ''}) async {
    opened.add((url, sourceName));

    return answer;
  }
}

/// Serves rendered pages for `java.webView` (the real one is a WebView).
final class _FakeWebPages implements WebPageFetcher {
  /// The body every render answers with.
  String body = '<div>rendered</div>';

  /// The script the caller asked for, in order.
  final List<String?> javaScripts = <String?>[];

  /// When true the render fails instead of answering a page.
  bool fail = false;

  @override
  bool get isSupported => true;

  @override
  Future<ParseResult<FetchedWebPage>> fetch({
    required String url,
    Map<String, String>? headers,
    required String rulePath,
    WebPageRequestMethod method = WebPageRequestMethod.get,
    String? body,
    String? javaScript,
    Duration? delayTime,
    String? overrideUrlRegex,
  }) async {
    javaScripts.add(javaScript);
    if (fail) {
      return const ParseFailure<FetchedWebPage>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'webView',
      );
    }

    return ParseSuccess<FetchedWebPage>(
      FetchedWebPage(url: url, body: this.body),
    );
  }
}

void main() {
  test('JsResponseView_toJson_marksTheSandboxResponse', () {
    const JsResponseView view = JsResponseView(
      url: 'https://example-novel.test/book/1',
      body: '<div>正文</div>',
      code: 203,
      headers: <String, String>{'content-type': 'text/html'},
    );

    expect(view.toJson(), <String, Object?>{
      jsResponseMarker: true,
      'body': '<div>正文</div>',
      '__url': 'https://example-novel.test/book/1',
      '__code': 203,
      '__headers': <String, String>{'content-type': 'text/html'},
    });
    // 注意：`url` / `code` / `headers` 是沙箱的方法名（上游 StrResponse），数据因此走 `__` 前缀。
    expect(const JsResponseView(url: 'u', body: 'b').toJson()['__code'], 200);
    expect(
      const JsJob(
        script: 'result',
        rulePath: 'loginCheckJs',
        baseUrl: 'https://example-novel.test/',
        page: 1,
        source: JsSourceInfo(name: 's', url: 'https://example-novel.test'),
        response: view,
      ).toJson()['response'],
      view.toJson(),
    );
  });

  test('JsBookInfo_toJson_keepsEveryField', () {
    const JsBookInfo book = JsBookInfo(
      name: '剑来',
      author: '烽火戏诸侯',
      bookUrl: 'https://example-novel.test/book/1',
      tocUrl: 'https://example-novel.test/book/1/toc',
      intro: '简介',
      kind: '玄幻',
    );

    expect(book.toJson(), <String, Object?>{
      'name': '剑来',
      'author': '烽火戏诸侯',
      'bookUrl': 'https://example-novel.test/book/1',
      'tocUrl': 'https://example-novel.test/book/1/toc',
      'intro': '简介',
      'kind': '玄幻',
    });
    expect(
      const JsJob(
        script: 'book.name',
        rulePath: 'tocRule.chapterUrl',
        baseUrl: 'https://example-novel.test/toc',
        page: 1,
        source: JsSourceInfo(name: 's', url: 'https://example-novel.test'),
        book: book,
      ).toJson()['book'],
      book.toJson(),
    );
  });

  group('QuickJsWorkerBridge', () {
    test('evaluate_givenAJob_returnsTheWorkerValue', () async {
      final _Fixture fixture = _buildBridge();

      final ParseResult<Object?> result = await fixture.bridge.evaluate(_job());

      expect(switch (result) {
        ParseSuccess<Object?>(:final Object? data) => data,
        ParseFailure<Object?>() => fail('Expected a success.'),
      }, 'result');
      // 懒创建：第一个 `@js:` 规则才拉起居子（ADR-0030 §决策 6）。
      expect(fixture.workers, hasLength(1));
      expect(fixture.workers.single.sent, hasLength(1));
      expect(fixture.workers.single.sent.single['type'], 'evaluate');
    });

    test('evaluate_givenConcurrentCalls_queuesThemInCallOrder', () async {
      final _Fixture fixture = _buildBridge();

      final Future<ParseResult<Object?>> first = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      final Future<ParseResult<Object?>> second = fixture.bridge.evaluate(
        _job(script: 'second'),
      );
      final Future<ParseResult<Object?>> third = fixture.bridge.evaluate(
        _job(script: 'third'),
      );

      await pumpEventQueue();
      // 单 worker + FIFO：只有第一个在跑，后两个排队等待，而不是 busy 失败（C-SRC-9）。
      expect(fixture.workers, hasLength(1));
      final FakeJsWorkerHandle running = fixture.workers.single;
      expect(running.sent, hasLength(1));

      // 后续 job 也保持不回答，才能观察到「排队 → 逐个派发」的顺序。
      running.holdJobs = true;
      running.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'first-value',
        'elapsedMs': 1,
      });
      expect(await first, isA<ParseSuccess<Object?>>());

      await pumpEventQueue();
      expect(running.sent, hasLength(2));
      expect(_scriptOf(running.sent[1]), 'second');

      running.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'second-value',
        'elapsedMs': 1,
      });
      expect(await second, isA<ParseSuccess<Object?>>());

      await pumpEventQueue();
      expect(running.sent, hasLength(3));
      expect(_scriptOf(running.sent[2]), 'third');

      running.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'third-value',
        'elapsedMs': 1,
      });
      expect(await third, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenAScriptThatThrows_reportsJsError', () async {
      final _Fixture fixture = _buildBridge();

      final ParseFailure<Never> failure = _failure(
        await fixture.bridge.evaluate(_job(script: 'fail')),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name:js:error');
    });

    test(
      'evaluate_givenAnInterruptedScript_reportsJsTimeoutAndKeepsTheWorker',
      () async {
        final _Fixture fixture = _buildBridge(
          timeout: const Duration(milliseconds: 50),
        );

        final ParseFailure<Never> failure = _failure(
          await fixture.bridge.evaluate(_job(script: 'runaway')),
        );

        expect(failure.rulePath, 'searchRule.name:js:timeout');
        // 探针 07 口径：引擎中断的是脚本，不是运行时——worker 不被杀，下一个 job 复用它。
        expect(fixture.workers.single.killCount, 0);
        expect(
          await fixture.bridge.evaluate(_job(script: 'again')),
          isA<ParseSuccess<Object?>>(),
        );
        expect(fixture.workers, hasLength(1));
      },
    );

    test('evaluate_givenAWorkerThatNeverAnswers_killsItAndRebuilds', () async {
      final _Fixture fixture = _buildBridge(
        timeout: const Duration(milliseconds: 20),
        killGrace: const Duration(milliseconds: 20),
      );

      final ParseFailure<Never> failure = _failure(
        await fixture.bridge.evaluate(_job(script: 'hold')),
      );

      // 引擎中断失效 → 硬预算 kill 兜底（ADR-0030 §决策 3），并在下一个 job 重建。
      expect(failure.rulePath, 'searchRule.name:js:timeout');
      expect(fixture.workers.single.killCount, 1);
      expect(
        await fixture.bridge.evaluate(_job(script: 'after-kill')),
        isA<ParseSuccess<Object?>>(),
      );
      expect(fixture.workers, hasLength(2));
    });

    test('evaluate_givenAWorkerThatStops_reportsAnErrorAndRebuilds', () async {
      final _Fixture fixture = _buildBridge();

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emitDone();

      final ParseFailure<Never> failure = _failure(await call);

      expect(failure.rulePath, 'searchRule.name:js:error');
      expect(
        await fixture.bridge.evaluate(_job(script: 'rebuilt')),
        isA<ParseSuccess<Object?>>(),
      );
      expect(fixture.workers, hasLength(2));
    });

    test(
      'evaluate_givenAWorkerStreamThatFails_keepsTheFailureInBand',
      () async {
        final _Fixture fixture = _buildBridge();

        final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
          _job(script: 'hold'),
        );
        await pumpEventQueue();
        fixture.workers.single.emitError(StateError('bridge broke'));

        expect(_failure(await call).kind, ParseFailureKind.parseFailed);
        expect(
          fixture.printer.events.map((LogEvent event) => event.message),
          contains(contains('JS worker message stream failed')),
        );
      },
    );

    test('evaluate_givenAWorkerThatCannotStart_reportsJsError', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final QuickJsWorkerBridge bridge = QuickJsWorkerBridge(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
        launch: ({required Duration timeout, required int memoryLimit}) async =>
            throw IsolateSpawnException('no resources'),
        http: FakeHttpClient(),
        variables: JsVariableStore(),
      );

      final ParseFailure<Never> failure = _failure(
        await bridge.evaluate(_job()),
      );

      expect(failure.rulePath, 'searchRule.name:js:error');
      expect(
        printer.events.map((LogEvent event) => event.message),
        contains(contains('JS worker could not start')),
      );
    });

    test('evaluate_givenLogRecords_tagsThemWithTheFieldAndLevel', () async {
      final _Fixture fixture = _buildBridge();

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(<String, Object?>{
        'type': 'log',
        'level': 'warn',
        'message': 'rule says hi',
      });
      worker.emit(<String, Object?>{
        'type': 'log',
        'level': 'debug',
        'message': 'detail',
      });
      worker.emit(<String, Object?>{
        'type': 'log',
        'level': 'error',
        'message': 'broke',
      });
      worker.emit(<String, Object?>{'type': 'log', 'message': 'no level'});
      await pumpEventQueue();

      // §6：log.* 必须自动带上 rulePath（C-SRC-8）。
      expect(
        fixture.printer.events.map((LogEvent event) => event.message),
        containsAll(<String>[
          '[js:searchRule.name] rule says hi',
          '[js:searchRule.name] detail',
          '[js:searchRule.name] broke',
          '[js:searchRule.name] no level',
        ]),
      );
      expect(
        fixture.printer.events.map((LogEvent event) => event.level),
        <Level>[Level.warning, Level.debug, Level.error, Level.info],
      );

      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
        'elapsedMs': 1,
      });
      await call;
    });

    test('evaluate_givenAnUnknownEnvelope_warnsAndKeepsWorking', () async {
      final _Fixture fixture = _buildBridge();

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(<String, Object?>{'type': 'unexpected'});
      worker.emit(<String, Object?>{'type': 'result', 'ok': true, 'value': 7});
      // 没有在途 job 的结果信封：记 warning，不得当成某个 job 的答案。
      worker.emit(<String, Object?>{'type': 'result', 'ok': true, 'value': 8});

      expect(await call, isA<ParseSuccess<Object?>>());
      expect(
        fixture.printer.events.map((LogEvent event) => event.message),
        containsAll(<Object>[
          contains('Ignoring an unknown JS worker message'),
          contains('no job is waiting for'),
        ]),
      );
    });

    test('evaluate_givenALongLogMessage_truncatesItAndMarksTheCut', () async {
      final _Fixture fixture = _buildBridge();

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'log',
        'level': 'info',
        'message': 'x' * 2500,
      });
      await pumpEventQueue();

      // F2：宿主侧上界（§6），截断处必须有可见标记，不能静默丢尾巴。
      const String prefix = '[js:searchRule.name] ';
      const String marker = '…[truncated 500 chars]';
      final String line = '${fixture.printer.events.last.message}';
      expect(line, startsWith(prefix));
      expect(line, endsWith(marker));
      expect(
        line.length,
        prefix.length + maxJsLogMessageLength + marker.length,
      );

      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      await call;
    });

    test(
      'dispose_givenQueuedJobs_completesThemAsCancelledAndKillsTheWorker',
      () async {
        final _Fixture fixture = _buildBridge();

        final Future<ParseResult<Object?>> running = fixture.bridge.evaluate(
          _job(script: 'hold'),
        );
        final Future<ParseResult<Object?>> queued = fixture.bridge.evaluate(
          _job(),
        );
        await pumpEventQueue();
        final FakeJsWorkerHandle worker = fixture.workers.single;

        await fixture.bridge.dispose();

        expect(_failure(await running).kind, ParseFailureKind.cancelled);
        // F3：取消不是脚本错误，因此只带字段路径、不带 `js:*` 标记。
        expect(_failure(await running).rulePath, 'searchRule.name');
        expect(_failure(await queued).kind, ParseFailureKind.cancelled);
        expect(_failure(await queued).rulePath, 'searchRule.name');
        expect(worker.killCount, 1);
        // dispose 之后的调用不再拉起 worker（ADR-0030 §决策 6 的作用域生命周期）。
        expect(
          _failure(await fixture.bridge.evaluate(_job())).kind,
          ParseFailureKind.cancelled,
        );
        expect(fixture.workers, hasLength(1));
      },
    );

    test(
      'dispose_givenACloseThatIsNeverAnswered_killsTheWorkerAnyway',
      () async {
        final _Fixture fixture = _buildBridge(
          killGrace: const Duration(milliseconds: 20),
        );

        final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
          _job(script: 'hold'),
        );
        await pumpEventQueue();
        final FakeJsWorkerHandle worker = fixture.workers.single;
        // 连 `close` 都不回话：优雅停机超时后仍必须 kill。
        worker.answerClose = false;
        worker.holdJobs = true;

        await fixture.bridge.dispose();

        expect(_failure(await call).kind, ParseFailureKind.cancelled);
        expect(worker.killCount, 1);
      },
    );

    test('evaluate_givenAnHttpGet_servesItThroughTheRequestLayer', () async {
      final _Fixture fixture = _buildBridge();
      fixture.http.serve('https://mirror.test/a', 'fresh body');

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(
          script: 'hold',
          sourceHeaders: const <String, String>{
            'Referer': 'https://book.test/',
          },
        ),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsHttpBinding, <String, Object?>{
          'operation': 'get',
          'url': 'https://mirror.test/a',
          'options': <String, Object?>{
            'headers': <String, Object?>{'X-Rule': '1'},
          },
        }),
      );
      await pumpEventQueue();

      // §6：http.* 经 core/network 代理（C-NET-1），书源自带的 header 在其下（C-NET-4），
      // 书源 URL 作为并发预算键（book-source.md §8）。
      expect(fixture.http.requestedUrls, <String>['https://mirror.test/a']);
      expect(fixture.http.requestedMethods, <String>['GET']);
      expect(fixture.http.requestedRulePaths, <String>['searchRule.name']);
      expect(fixture.http.requestedSourceIds, <String>[
        'https://example-novel.test',
      ]);
      expect(fixture.http.requestedHeaders.single, <String, String>{
        'Referer': 'https://book.test/',
        'X-Rule': '1',
      });
      expect(_replies(worker).single, containsPair('ok', true));
      expect(_replies(worker).single, containsPair('value', 'fresh body'));
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenAnHttpGetBytes_answersBase64', () async {
      // `java.queryTTF(url)` 的字节门：字体过文本解码就坏了，所以这条通道回 base64
      // （ADR-0068 增补决策 9）。
      final _Fixture fixture = _buildBridge();
      fixture.http.serveBytes('https://mirror.test/font.ttf', _fontBytes());

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsHttpBinding, <String, Object?>{
          'operation': 'getBytes',
          'url': 'https://mirror.test/font.ttf',
        }),
      );
      await pumpEventQueue();

      expect(fixture.http.requestedUrls, <String>[
        'https://mirror.test/font.ttf',
      ]);
      expect(_replies(worker).single['value'], base64Encode(_fontBytes()));
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenAnHttpRequestThatAsksForTheResponse_answersUrlCodeAndHeaders', () async {
      // `options.response` 要的是整个响应：重定向之后的地址只有响应里才有，
      // 而规则重发请求时需要的正是它（book-source.md §6）。
      final _Fixture fixture = _buildBridge();
      fixture.http.serve(
        'https://mirror.test/sscc/',
        'moved body',
        headers: const <String, List<String>>{
          'location': <String>['?9bdb14'],
        },
        finalUrl: 'https://mirror.test/sscc/?9bdb14',
      );

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(7, jsHttpBinding, <String, Object?>{
          'operation': 'post',
          'url': 'https://mirror.test/sscc/',
          'options': <String, Object?>{'body': 'q=1', 'response': true},
        }),
      );
      await pumpEventQueue();

      final Map<String, Object?> value =
          _replies(worker).single['value']! as Map<String, Object?>;
      expect(value['__strResponse'], isTrue);
      expect(value['body'], 'moved body');
      expect(value['__url'], 'https://mirror.test/sscc/?9bdb14');
      expect(value['__code'], 200);
      expect(value['__headers'], containsPair('location', '?9bdb14'));
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenAnHttpGetBytesThatFails_rejectsThePromise', () async {
      final _Fixture fixture = _buildBridge();
      fixture.http
        ..serveBytes('https://mirror.test/font.ttf', _fontBytes())
        ..failWith('https://mirror.test/font.ttf', ParseFailureKind.notFound);

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsHttpBinding, <String, Object?>{
          'operation': 'getBytes',
          'url': 'https://mirror.test/font.ttf',
        }),
      );
      await pumpEventQueue();

      // 传输失败只拒绝这条 Promise（规则可以换镜像），不判整个 job 死。
      expect(_replies(worker).single['ok'], isFalse);
      expect(_replies(worker).single['fatal'], isFalse);
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenAnHttpPost_sendsTheBodyAndMethod', () async {
      final _Fixture fixture = _buildBridge();
      fixture.http.serve('https://mirror.test/api', 'posted');

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(4, jsHttpBinding, <String, Object?>{
          'operation': 'post',
          'url': 'https://mirror.test/api',
          'options': <String, Object?>{'body': 'q=1'},
        }),
      );
      await pumpEventQueue();

      expect(fixture.http.requestedMethods, <String>['POST']);
      expect(fixture.http.requestedBodies, <String?>['q=1']);
      expect(_replies(worker).single, containsPair('value', 'posted'));
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenAnHttpFailure_rejectsTheScriptButNotTheJob', () async {
      final _Fixture fixture = _buildBridge();
      fixture.http.failWith(
        'https://mirror.test/a',
        ParseFailureKind.networkTimeout,
      );

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsHttpBinding, <String, Object?>{
          'operation': 'get',
          'url': 'https://mirror.test/a',
        }),
      );
      await pumpEventQueue();

      // 传输失败只拒绝脚本的 Promise（规则可以自己 catch 后改走镜像），不失败整个 job。
      expect(_replies(worker).single, containsPair('ok', false));
      expect(_replies(worker).single, containsPair('fatal', false));
      expect(
        _replies(worker).single,
        containsPair('message', 'networkTimeout'),
      );
      expect(worker.killCount, 0);

      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'caught',
      });
      expect(switch (await call) {
        ParseSuccess<Object?>(:final Object? data) => data,
        ParseFailure<Object?>() => fail('Expected a success.'),
      }, 'caught');
    });

    test(
      'evaluate_givenAMalformedHttpCall_rejectsItWithoutRequesting',
      () async {
        final _Fixture fixture = _buildBridge();

        final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
          _job(script: 'hold'),
        );
        await pumpEventQueue();
        final FakeJsWorkerHandle worker = fixture.workers.single;
        worker.emit(_hostCall(1, jsHttpBinding, 'not an object'));
        await pumpEventQueue();

        expect(fixture.http.requestedUrls, isEmpty);
        expect(
          _replies(worker).single,
          containsPair('message', 'malformed http call'),
        );
        worker.emit(<String, Object?>{
          'type': 'result',
          'ok': true,
          'value': 'done',
        });
        expect(await call, isA<ParseSuccess<Object?>>());
      },
    );

    test('evaluate_givenAnHttpCallAfterTheJobEnded_answersNothing', () async {
      final _Fixture fixture = _buildBridge();
      final Completer<void> gate = Completer<void>();
      fixture.http.onRequest = () => gate.future;
      fixture.http.serve('https://mirror.test/b', 'late body');

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsHttpBinding, <String, Object?>{
          'operation': 'get',
          'url': 'https://mirror.test/b',
        }),
      );
      await pumpEventQueue();
      expect(fixture.http.requestedUrls, hasLength(1));

      // 请求还在飞，job 已经结束（结果先到）：答复无处可去，也不得算到下一个 job 头上。
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());

      gate.complete();
      await pumpEventQueue();

      expect(_replies(worker), isEmpty);
    });

    test('evaluate_givenAByteCallAfterTheJobEnded_answersNothing', () async {
      // 与 GET 同一条规矩：请求还在飞时 job 已经结束，答复无处可去。
      final _Fixture fixture = _buildBridge();
      final Completer<void> gate = Completer<void>();
      fixture.http.onRequest = () => gate.future;
      fixture.http.serveBytes('https://mirror.test/font.ttf', _fontBytes());

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsHttpBinding, <String, Object?>{
          'operation': 'getBytes',
          'url': 'https://mirror.test/font.ttf',
        }),
      );
      await pumpEventQueue();
      expect(fixture.http.requestedUrls, hasLength(1));

      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());

      gate.complete();
      await pumpEventQueue();

      expect(_replies(worker), isEmpty);
    });

    test('evaluate_givenAnUnknownBinding_rejectsTheCall', () async {
      final _Fixture fixture = _buildBridge();

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(_hostCall(1, 'fs', <String, Object?>{}));
      await pumpEventQueue();

      // C-SRC-3 / C-SRC-4：白名单外的频道显式拒绝，不得静默返回 undefined。
      expect(
        _replies(worker).single,
        containsPair('message', 'unknown binding: fs'),
      );
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenAParseCall_answersWithTheRulesValue', () async {
      final _Fixture fixture = _buildBridge();
      final List<JsParseRequest> requests = <JsParseRequest>[];

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(
          script: 'hold',
          parseEvaluator: (JsParseRequest request) async {
            requests.add(request);

            return const ParseSuccess<Object?>('正文');
          },
        ),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(2, jsParseBinding, <String, Object?>{
          'operation': 'getString',
          'rule': 'id.c@text',
          'doc': 'raw',
        }),
      );
      await pumpEventQueue();

      expect(requests.single.rule, 'id.c@text');
      expect(requests.single.wantsList, isFalse);
      expect(requests.single.doc, 'raw');
      expect(_replies(worker).single, containsPair('value', '正文'));
      expect(worker.killCount, 0);
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenAParseFailure_failsTheJobOnceTheScriptStops', () async {
      final _Fixture fixture = _buildBridge();

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(
          script: 'hold',
          rulePath: 'contentRule.content',
          parseEvaluator: (JsParseRequest request) async => failureAt<Object?>(
            kind: ParseFailureKind.unsupportedRule,
            rulePath: 'contentRule.content:js:parse-scope',
          ),
        ),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsParseBinding, <String, Object?>{
          'operation': 'getString',
          'rule': 'id.c@text',
        }),
      );
      await pumpEventQueue();

      // 脚本可能还在跑，所以 worker 不被交给下一个 job：先回一条 fatal，答案等它停下来再交。
      expect(_replies(worker).single, containsPair('fatal', true));
      expect(worker.killCount, 0);

      // ADR-0029 §决策 5：边界必须显式失败且可定位，不被脚本吞掉——脚本自己写出的值（这里是
      // `caught`）不再算数。
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'caught',
      });
      final ParseFailure<Never> failure = _failure(await call);
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'contentRule.content:js:parse-scope');

      // 脚本已经停下来了，所以同一个 worker 可以继续用（不必重建）。
      expect(switch (await fixture.bridge.evaluate(_job())) {
        ParseSuccess<Object?>(:final Object? data) => data,
        ParseFailure<Object?>() => fail('Expected a success.'),
      }, 'result');
      expect(fixture.workers, hasLength(1));
    });

    test(
      'evaluate_givenAJobWithoutAParseEvaluator_failsWithTheScopeMarker',
      () async {
        final _Fixture fixture = _buildBridge();

        final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
          _job(script: 'hold'),
        );
        await pumpEventQueue();
        final FakeJsWorkerHandle worker = fixture.workers.single;
        worker.emit(
          _hostCall(1, jsParseBinding, <String, Object?>{
            'operation': 'getElements',
            'rule': 'class.odd',
          }),
        );
        await pumpEventQueue();
        expect(_replies(worker).single, containsPair('fatal', true));

        worker.emit(<String, Object?>{
          'type': 'result',
          'ok': true,
          'value': 'done',
        });
        final ParseFailure<Never> failure = _failure(await call);
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'searchRule.name:js:parse-scope');
      },
    );

    test('evaluate_givenAMalformedParseCall_rejectsItAndKeepsTheJob', () async {
      final _Fixture fixture = _buildBridge();

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(
          script: 'hold',
          parseEvaluator: (JsParseRequest request) async =>
              const ParseSuccess<Object?>(null),
        ),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(_hostCall(1, jsParseBinding, <String, Object?>{'rule': 1}));
      await pumpEventQueue();

      expect(
        _replies(worker).single,
        containsPair('message', 'malformed parse call'),
      );
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenAHostCallWithoutAJob_reportsIt', () async {
      final _Fixture fixture = _buildBridge();

      await fixture.bridge.evaluate(_job());
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsParseBinding, <String, Object?>{
          'operation': 'getString',
          'rule': 'id.c',
        }),
      );
      worker.emit(
        _hostCall(2, jsHttpBinding, <String, Object?>{
          'operation': 'get',
          'url': 'https://mirror.test/a',
        }),
      );
      await pumpEventQueue();

      // 两种绑定都属于已结束的 job：一个进不了致命路径（无 job 可杀），一个没有可归属的请求。
      expect(
        fixture.printer.events.map((LogEvent event) => event.message),
        contains(contains('no longer running')),
      );
      expect(
        _replies(worker).single,
        containsPair('message', 'no job is running'),
      );
      expect(fixture.http.requestedUrls, isEmpty);
    });

    test(
      'evaluate_givenAByteCallLandingAfterAFatalFailure_rejectsIt',
      () async {
        final _Fixture fixture = _buildBridge(maxBindingCalls: 3);
        final Completer<void> gate = Completer<void>();
        fixture.http.onRequest = () => gate.future;
        fixture.http.serveBytes('https://mirror.test/font.ttf', _fontBytes());

        final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
          _job(script: 'hold'),
        );
        await pumpEventQueue();
        final FakeJsWorkerHandle worker = fixture.workers.single;
        worker.emit(
          _hostCall(1, jsHttpBinding, <String, Object?>{
            'operation': 'getBytes',
            'url': 'https://mirror.test/font.ttf',
          }),
        );
        await pumpEventQueue();
        for (final String message in <String>['a', 'b', 'c']) {
          worker.emit(<String, Object?>{
            'type': 'log',
            'level': 'info',
            'message': message,
          });
        }
        await pumpEventQueue();
        expect(_replies(worker), isEmpty);

        // 字节回来时 job 已经定了：同样不得回答一个已经失败的 job。
        gate.complete();
        await pumpEventQueue();
        expect(_replies(worker).single['message'], 'the job already failed');

        worker.emit(<String, Object?>{
          'type': 'result',
          'ok': false,
          'error': 'js:quota',
        });
        await call;
      },
    );

    test(
      'evaluate_givenAnHttpCallLandingAfterAFatalFailure_rejectsIt',
      () async {
        final _Fixture fixture = _buildBridge(maxBindingCalls: 3);
        final Completer<void> gate = Completer<void>();
        fixture.http.onRequest = () => gate.future;
        fixture.http.serve('https://mirror.test/a', 'late body');

        final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
          _job(script: 'hold'),
        );
        await pumpEventQueue();
        final FakeJsWorkerHandle worker = fixture.workers.single;
        // 额度 3：先花在一条挂住的请求上，再被一波日志拖爆。
        worker.emit(
          _hostCall(1, jsHttpBinding, <String, Object?>{
            'operation': 'get',
            'url': 'https://mirror.test/a',
          }),
        );
        await pumpEventQueue();
        for (final String message in <String>['a', 'b', 'c']) {
          worker.emit(<String, Object?>{
            'type': 'log',
            'level': 'info',
            'message': message,
          });
        }
        await pumpEventQueue();
        expect(_replies(worker), isEmpty);

        // 请求回来时 job 已经定了：不得再回答一个已经失败的 job。
        gate.complete();
        await pumpEventQueue();
        expect(_replies(worker).single['message'], 'the job already failed');

        worker.emit(<String, Object?>{
          'type': 'result',
          'ok': true,
          'value': 'done',
        });
        expect(_failure(await call).rulePath, 'searchRule.name:js:quota');
      },
    );

    test(
      'evaluate_givenAParseCallLandingAfterAFatalFailure_rejectsIt',
      () async {
        final _Fixture fixture = _buildBridge(maxBindingCalls: 3);
        final Completer<void> gate = Completer<void>();

        final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
          _job(
            script: 'hold',
            parseEvaluator: (JsParseRequest request) async {
              await gate.future;

              return const ParseSuccess<Object?>('正文');
            },
          ),
        );
        await pumpEventQueue();
        final FakeJsWorkerHandle worker = fixture.workers.single;
        worker.emit(
          _hostCall(1, jsParseBinding, <String, Object?>{
            'operation': 'getString',
            'rule': 'id.c@text',
          }),
        );
        await pumpEventQueue();
        for (final String message in <String>['a', 'b', 'c']) {
          worker.emit(<String, Object?>{
            'type': 'log',
            'level': 'info',
            'message': message,
          });
        }
        await pumpEventQueue();

        // 嵌套规则算完时 job 已经定了：同样只拒绝，不再交付一个值。
        gate.complete();
        await pumpEventQueue();
        expect(_replies(worker).single['message'], 'the job already failed');

        worker.emit(<String, Object?>{
          'type': 'result',
          'ok': true,
          'value': 'done',
        });
        expect(_failure(await call).rulePath, 'searchRule.name:js:quota');
      },
    );

    test('evaluate_givenAMalformedHostEnvelope_warnsAndKeepsWorking', () async {
      final _Fixture fixture = _buildBridge();

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(<String, Object?>{'type': 'host', 'callId': 'nope'});
      await pumpEventQueue();

      expect(
        fixture.printer.events.map((LogEvent event) => event.message),
        contains(contains('malformed JS host call envelope')),
      );
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('evaluate_givenMoreBindingCallsThanTheQuota_failsTheJob', () async {
      final _Fixture fixture = _buildBridge(maxBindingCalls: 2);

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      for (int callId = 1; callId <= 2; callId++) {
        worker.emit(
          _hostCall(callId, jsHttpBinding, <String, Object?>{
            'operation': 'get',
            'url': 'https://mirror.test/a',
          }),
        );
      }
      await pumpEventQueue();
      expect(fixture.http.requestedUrls, hasLength(2));

      worker.emit(
        _hostCall(3, jsHttpBinding, <String, Object?>{
          'operation': 'get',
          'url': 'https://mirror.test/a',
        }),
      );
      await pumpEventQueue();

      // §6 的额度是每 job 的硬上限：超限的不是拒绝一个调用，而是这个 job 已经不可信
      // （脚本会被一条 fatal 回复告知，但答案等它停下来才交出去）。
      expect(_replies(worker).last['fatal'], true);
      expect(_replies(worker).last['rulePath'], 'searchRule.name:js:quota');
      expect(fixture.http.requestedUrls, hasLength(2));

      // 给完额度之后的调用只被拒绝（不再花钱）。
      worker.emit(
        _hostCall(4, jsHttpBinding, <String, Object?>{
          'operation': 'get',
          'url': 'https://mirror.test/a',
        }),
      );
      await pumpEventQueue();
      expect(fixture.http.requestedUrls, hasLength(2));
      expect(_replies(worker).last['message'], 'the job already failed');

      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      final ParseFailure<Never> failure = _failure(await call);
      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name:js:quota');
      expect(worker.killCount, 0);
    });

    test('evaluate_givenALogStorm_failsTheJobAtTheQuota', () async {
      final _Fixture fixture = _buildBridge(maxBindingCalls: 1);

      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(<String, Object?>{
        'type': 'log',
        'level': 'info',
        'message': 'first',
      });
      await pumpEventQueue();
      worker.emit(<String, Object?>{
        'type': 'log',
        'level': 'info',
        'message': 'second',
      });
      worker.emit(<String, Object?>{
        'type': 'log',
        'level': 'info',
        'message': 'third',
      });
      await pumpEventQueue();

      // §6 的额度**含 log.***，所以狂写日志与递归 parse 同等对待。
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
      });
      final ParseFailure<Never> failure = _failure(await call);
      expect(failure.rulePath, 'searchRule.name:js:quota');
      expect(worker.killCount, 0);
      expect(
        fixture.printer.events.map((LogEvent event) => event.message),
        contains('[js:searchRule.name] first'),
      );
      expect(
        fixture.printer.events.map((LogEvent event) => event.message),
        isNot(contains('[js:searchRule.name] second')),
      );
    });
  });

  group('variables', () {
    test('evaluate_givenAReportedVariable_writesItToTheStore', () async {
      final _Fixture fixture = _buildBridge(
        configure: (FakeJsWorkerHandle worker) => worker.enqueueResult(
          value: 'ok',
          variables: <String, String?>{'token': 'abc'},
        ),
      );

      await fixture.bridge.evaluate(_job());

      // worker 报回的变量按 job 的书源落表（ADR-0034 §决策 1）：
      // 这正是 `java.put` 在 JS 侧同步写完后的回程。
      expect(
        fixture.variables.read('https://example-novel.test', 'token'),
        'abc',
      );
    });

    test('evaluate_givenAClearedVariable_removesItFromTheStore', () async {
      final JsVariableStore store = JsVariableStore()
        ..write('https://example-novel.test', 'token', 'abc');
      final _Fixture fixture = _buildBridge(
        variables: store,
        configure: (FakeJsWorkerHandle worker) => worker.enqueueResult(
          value: 'ok',
          variables: <String, String?>{'token': null},
        ),
      );

      await fixture.bridge.evaluate(_job());

      // `java.put(key, null)` 是清掉变量（RuleDataInterface.kt:8-14），不是写成空串。
      expect(
        fixture.variables.read('https://example-novel.test', 'token'),
        isNull,
      );
    });

    test('evaluate_givenAMalformedVariableReport_ignoresIt', () async {
      final _Fixture fixture = _buildBridge(
        configure: (FakeJsWorkerHandle worker) {
          worker.holdJobs = true;
        },
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(_job());
      await pumpEventQueue();

      // 信封是传输层：非 map 或错类型的条目一律忽略，不猜也不崩（C-ERR-1）。
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'ok',
        'variables': 'nonsense',
      });
      expect(await call, isA<ParseSuccess<Object?>>());
      expect(fixture.variables.snapshot('https://example-novel.test'), isEmpty);

      final Future<ParseResult<Object?>> second = fixture.bridge.evaluate(
        _job(),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'ok',
        'variables': <Object?, Object?>{'a': 1, 2: 'b'},
      });
      expect(await second, isA<ParseSuccess<Object?>>());
      expect(fixture.variables.snapshot('https://example-novel.test'), isEmpty);
    });
  });
  group('verification channel', () {
    test(
      'startBrowserAwait_whenTheUserSolves_answersTheRefetchedPage',
      () async {
        final _Fixture fixture = _buildBridge();
        unawaited(fixture.bridge.evaluate(_job(script: 'hold')));
        await pumpEventQueue();
        final FakeJsWorkerHandle worker = fixture.workers.single;
        worker.emit(
          _hostCall(1, jsVerifyBinding, <String, Object?>{
            'operation': 'startBrowserAwait',
            'url': 'https://example-novel.test/challenge',
            'title': '验证',
          }),
        );
        await pumpEventQueue();

        // 请求带到端口的是书源身份与原标题；答案回到脚本的是一个 {url, body} 对象。
        expect(
          fixture.verification.requests.single.url,
          'https://example-novel.test/challenge',
        );
        expect(fixture.verification.requests.single.title, '验证');
        expect(
          fixture.verification.requests.single.sourceUrl,
          'https://example-novel.test',
        );
        final Map<String, Object?> reply = _replies(worker).single;
        expect(reply['ok'], isTrue);
        expect(reply['value'], <String, Object?>{
          'url': 'https://example-novel.test/after',
          'body': '<p>solved</p>',
        });
      },
    );

    test('startBrowser_whenCalled_answersImmediatelyAndOpensThePage', () async {
      final _Fixture fixture = _buildBridge();
      unawaited(fixture.bridge.evaluate(_job(script: 'hold')));
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsVerifyBinding, <String, Object?>{
          'operation': 'startBrowser',
          'url': 'https://example-novel.test/challenge',
        }),
      );
      await pumpEventQueue();

      // 上游的这个名字返回 void：规则不被页面挡住，页面照样打开。
      expect(_replies(worker).single, containsPair('ok', true));
      expect(fixture.verification.requests, hasLength(1));
    });

    test('imageCode_whenTheUserTypes_answersTheText', () async {
      final _Fixture fixture = _buildBridge();
      unawaited(fixture.bridge.evaluate(_job(script: 'hold')));
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsVerifyBinding, <String, Object?>{
          'operation': 'imageCode',
          'url': 'https://example-novel.test/code.jpg',
        }),
      );
      await pumpEventQueue();

      expect(
        fixture.verification.captchas.single,
        'https://example-novel.test/code.jpg',
      );
      expect(_replies(worker).single, containsPair('value', 'A7bC'));
    });

    test('webView_whenARuleAsks_answersTheRenderedBody', () async {
      final _Fixture fixture = _buildBridge();
      unawaited(fixture.bridge.evaluate(_job(script: 'hold')));
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsVerifyBinding, <String, Object?>{
          'operation': 'webView',
          'url': 'https://example-novel.test/page',
          'script': 'document.title',
        }),
      );
      await pumpEventQueue();

      expect(fixture.webPages.javaScripts.single, 'document.title');
      expect(
        _replies(worker).single,
        containsPair('value', '<div>rendered</div>'),
      );
    });

    test('verify_whenTheUserCancels_failsTheJobAsCancelled', () async {
      final _Fixture fixture = _buildBridge();
      fixture.verification.outcome =
          const ParseFailure<SourceVerificationOutcome>(
            kind: ParseFailureKind.cancelled,
            rulePath: 'java.startBrowser',
          );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsVerifyBinding, <String, Object?>{
          'operation': 'startBrowserAwait',
          'url': 'https://example-novel.test/challenge',
        }),
      );
      await pumpEventQueue();
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': 'rejected',
        'elapsedMs': 0,
      });

      // 取消是整次 job 的答案（ADR-0068 §决策 10），不是脚本自己的错。
      final ParseResult<Object?> result = await call;
      expect(
        (result as ParseFailure<Object?>).kind,
        ParseFailureKind.cancelled,
      );
    });

    test('startBrowserAwait_whenTheSourceHasHeaders_passesThemOn', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(
          script: 'hold',
          sourceHeaders: const <String, String>{'Referer': 'https://a.test/'},
        ),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsVerifyBinding, <String, Object?>{
          'operation': 'startBrowserAwait',
          'url': 'https://example-novel.test/challenge',
        }),
      );
      await pumpEventQueue();

      // 书源自己的 header 必须带给验证页（站点按 Referer/UA 决定放不放行）。
      expect(fixture.verification.requests.single.headers, <String, String>{
        'Referer': 'https://a.test/',
      });
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'ok',
      });
      await call;
    });

    test('verify_givenNoJobInFlight_rejectsTheCall', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      // 先让 job 结束，再让一条迟到的验证调用进来。
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'ok',
      });
      await call;
      worker.emit(
        _hostCall(2, jsVerifyBinding, <String, Object?>{
          'operation': 'imageCode',
          'url': 'https://example-novel.test/code.jpg',
        }),
      );
      await pumpEventQueue();

      expect(_replies(worker).single, containsPair('ok', false));
      expect(fixture.verification.captchas, isEmpty);
    });

    test('imageCode_whenTheUserCancels_failsTheJobAsCancelled', () async {
      final _Fixture fixture = _buildBridge();
      fixture.verification.code = const ParseFailure<String>(
        kind: ParseFailureKind.cancelled,
        rulePath: 'java.getVerificationCode',
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsVerifyBinding, <String, Object?>{
          'operation': 'imageCode',
          'url': 'https://example-novel.test/code.jpg',
        }),
      );
      await pumpEventQueue();
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': 'rejected',
        'elapsedMs': 0,
      });

      expect(
        ((await call) as ParseFailure<Object?>).kind,
        ParseFailureKind.cancelled,
      );
    });

    test('verify_whenTheJobEndsWhileTheUserIsAway_isRejected', () async {
      // 用户按「完成」之前 job 已经结束（脚本自己抛错）：答复无处可去，只能显式拒绝。
      final _Fixture fixture = _buildBridge();
      final Completer<void> gate = Completer<void>();
      fixture.verification.gate = gate.future;
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsVerifyBinding, <String, Object?>{
          'operation': 'imageCode',
          'url': 'https://example-novel.test/code.jpg',
        }),
      );
      await pumpEventQueue();
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'ok',
      });
      await call;
      gate.complete();
      await pumpEventQueue();

      expect(_replies(worker).last, containsPair('ok', false));
    });

    test('verify_givenMalformedArguments_rejectsTheCall', () async {
      final _Fixture fixture = _buildBridge();
      unawaited(fixture.bridge.evaluate(_job(script: 'hold')));
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;

      worker.emit(_hostCall(1, jsVerifyBinding, 'not an object'));
      await pumpEventQueue();

      expect(_replies(worker).single, containsPair('ok', false));
      expect(fixture.verification.requests, isEmpty);
    });

    test('webView_whenTheRendererFails_failsTheJob', () async {
      final _Fixture fixture = _buildBridge(
        webPages: _FakeWebPages()..fail = true,
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsVerifyBinding, <String, Object?>{
          'operation': 'webView',
          'url': 'https://example-novel.test/page',
        }),
      );
      await pumpEventQueue();
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': 'rejected',
        'elapsedMs': 0,
      });

      expect(
        ((await call) as ParseFailure<Object?>).kind,
        ParseFailureKind.unsupportedRule,
      );
    });

    test('verify_givenAnUnsupportedPlatform_failsAsUnsupportedRule', () async {
      final _Fixture fixture = _buildBridge();
      fixture.verification.supported = false;
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsVerifyBinding, <String, Object?>{
          'operation': 'startBrowserAwait',
          'url': 'https://example-novel.test/challenge',
        }),
      );
      await pumpEventQueue();
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': 'rejected',
        'elapsedMs': 0,
      });

      expect(
        ((await call) as ParseFailure<Object?>).kind,
        ParseFailureKind.unsupportedRule,
      );
    });
  });

  group('synchronous channel', () {
    test('syncAjax_whenARuleAsksForAPage_fetchesAndAnswersTheBody', () async {
      // 上游写 `java.ajax(url)` 直接拿正文：worker 未命中缓存时把这通电话打到这里。
      final _Fixture fixture = _buildBridge();
      fixture.http.serve('https://example-novel.test/chapter', '<p>x</p>');
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'ajax',
          'url': 'https://example-novel.test/chapter',
          'headers': <String, Object?>{
            'Referer': 'https://example-novel.test/',
          },
        }),
      );
      await pumpEventQueue();

      expect(
        _replies(worker).single['value'],
        '<p>x</p>',
        reason: '同步取页的答案就是正文本身',
      );
      expect(fixture.http.requestedMethods, <String>['GET']);
      expect(
        fixture.http.requestedHeaders.single,
        containsPair('Referer', 'https://example-novel.test/'),
      );
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('syncPost_whenARulePostsAForm_answersTheResponseView', () async {
      // 上游 `java.post(url, body, headers).header("Location")`：响应对象的形状与
      // `http.* {response:true}` / `loginCheckJs` 的 result 相同（ADR-0076 §决策 2）。
      final _Fixture fixture = _buildBridge();
      fixture.http.serve(
        'https://example-novel.test/sscc/',
        '',
        headers: <String, List<String>>{
          'location': <String>['?9bdb14'],
        },
        finalUrl: 'https://example-novel.test/sscc/?9bdb14',
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'post',
          'url': 'https://example-novel.test/sscc/',
          'body': 'keyword=x',
        }),
      );
      await pumpEventQueue();

      final Object? value = _replies(worker).single['value'];
      expect(value, isA<Map<String, Object?>>());
      final Map<String, Object?> response = value! as Map<String, Object?>;
      expect(response[jsResponseMarker], isTrue);
      expect(response['__url'], 'https://example-novel.test/sscc/?9bdb14');
      expect(response['__code'], 200);
      expect(
        (response['__headers']! as Map<String, Object?>)['location'],
        '?9bdb14',
      );
      expect(fixture.http.requestedMethods, <String>['POST']);
      expect(fixture.http.requestedBodies.single, 'keyword=x');
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('syncHead_whenARuleAsksForHeaders_usesTheHeadVerb', () async {
      final _Fixture fixture = _buildBridge();
      fixture.http.serve('https://example-novel.test/head', '');
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'head',
          'url': 'https://example-novel.test/head',
        }),
      );
      await pumpEventQueue();

      expect(fixture.http.requestedMethods, <String>['HEAD']);
      final Map<String, Object?> reply = _replies(fixture.workers.single)
          .single;
      expect(
        (reply['value']! as Map<String, Object?>)[jsResponseMarker],
        isTrue,
      );
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('syncAjax_whenTheFetchFails_rejectsTheCallButNotTheJob', () async {
      // 上游 `java.ajax` 失败是抛错：规则自己的 try/catch 换镜像仍然要能工作，所以这里只拒绝
      // 这一次调用（worker 会把失败也记进缓存，重放因此不会变成死循环）。
      final _Fixture fixture = _buildBridge();
      fixture.http.failWith(
        'https://example-novel.test/x',
        ParseFailureKind.networkFailed,
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'ajax',
          'url': 'https://example-novel.test/x',
        }),
      );
      await pumpEventQueue();

      expect(_replies(worker).single['ok'], isFalse);
      expect(_replies(worker).single['fatal'], isFalse);
      expect(_replies(worker).single['message'], 'networkFailed');

      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'mirror',
        'elapsedMs': 0,
      });
      expect(await call, isA<ParseSuccess<Object?>>());
    });

    test('syncCall_whenTheJobAlreadyEnded_isRejected', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'done',
        'elapsedMs': 0,
      });
      await call;
      worker.emit(
        _hostCall(2, jsSyncBinding, <String, Object?>{
          'operation': 'ajax',
          'url': 'https://example-novel.test/late',
        }),
      );
      await pumpEventQueue();

      // 没有在途 job：这通电话没有收件人，必须显式拒绝而不是静默。
      expect(_replies(worker).last['ok'], isFalse);
      expect(fixture.http.requestedUrls, isEmpty);
    });

    test('syncCall_whenTheArgumentsAreMalformed_isRejected', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{'operation': 'fetch'}),
      );
      await pumpEventQueue();

      expect(_replies(worker).single['message'], 'malformed synchronous call');
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });
  });

  group('cookies', () {
    test('getCookie_whenTheJarHasTheCookie_answersItsValue', () async {
      final _Fixture fixture = _buildBridge();
      fixture.cookies.storeFromResponse(
        Uri.parse('https://example-novel.test/'),
        <String>['token=abc123; Path=/'],
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'cookieGet',
          'url': 'https://example-novel.test/page',
          'key': 'token',
        }),
      );
      await pumpEventQueue();

      expect(_replies(worker).single['value'], 'abc123');
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('getCookie_withoutAName_answersTheWholeHeader', () async {
      // 上游 `cookie.getCookie(url)` 给的是整条 Cookie 头，规则常常直接拼进请求头。
      final _Fixture fixture = _buildBridge();
      fixture.cookies.storeFromResponse(
        Uri.parse('https://example-novel.test/'),
        <String>['a=1', 'b=2'],
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'getCookie',
          'url': 'https://example-novel.test/',
        }),
      );
      await pumpEventQueue();

      expect(_replies(fixture.workers.single).single['value'], 'a=1; b=2');
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('getCookie_givenNoJarEntry_answersAnEmptyHeader', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'getCookie',
          'url': 'https://example-novel.test/',
        }),
      );
      await pumpEventQueue();

      expect(_replies(fixture.workers.single).single['value'], '');
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('setCookie_givenSeveralPairs_storesEveryPair', () async {
      // `cookie.setCookie(url, 'a=1; b=2')` 是整条头；第二对不是第一对的属性。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'cookieSet',
          'url': 'https://example-novel.test/',
          'body': 'a=1; b=2',
        }),
      );
      await pumpEventQueue();

      expect(_replies(worker).single['ok'], isTrue);
      expect(
        fixture.cookies.cookieHeaderFor(
          Uri.parse('https://example-novel.test/'),
        ),
        'a=1; b=2',
      );
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('setCookie_givenGarbage_isRejectedAsUnsupported', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'cookieSet',
          'url': 'https://example-novel.test/',
          'body': 'no-equals-sign',
        }),
      );
      await pumpEventQueue();

      expect(
        _replies(fixture.workers.single).single['message'],
        ParseFailureKind.unsupportedRule.name,
      );
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('removeCookie_whenCalled_dropsIt', () async {
      final _Fixture fixture = _buildBridge();
      fixture.cookies.storeFromResponse(
        Uri.parse('https://example-novel.test/'),
        <String>['a=1', 'b=2'],
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'cookieRemove',
          'url': 'https://example-novel.test/',
          'key': 'a',
        }),
      );
      await pumpEventQueue();

      expect(
        fixture.cookies.cookieHeaderFor(
          Uri.parse('https://example-novel.test/'),
        ),
        'b=2',
      );
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('cookieVerbs_givenNoJarOrNoName_areRejectedAsUnsupported', () async {
      // 两种「做不到」：装配根没给 Cookie 宗，或者删除没给名字。两者都必须显式拒绝。
      final _Fixture fixture = _buildBridge(bindCookies: false);
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'cookieGet',
          'url': 'https://example-novel.test/',
          'key': 'token',
        }),
      );
      worker.emit(
        _hostCall(2, jsSyncBinding, <String, Object?>{
          'operation': 'cookieSet',
          'url': 'https://example-novel.test/',
          'body': 'a=1',
        }),
      );
      worker.emit(
        _hostCall(3, jsSyncBinding, <String, Object?>{
          'operation': 'cookieRemove',
          'url': 'https://example-novel.test/',
        }),
      );
      await pumpEventQueue();

      expect(
        _replies(worker).map((Map<String, Object?> reply) => reply['message']),
        everyElement(ParseFailureKind.unsupportedRule.name),
      );
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });
  });

  group('source variables', () {
    test('evaluate_givenAReportedSourceVariable_writesItToTheStore', () async {
      // `source.setVariable` 与 `java.put` 走同一条回传路径，但落的是持久表（ADR-0076 §决策 1）。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'v',
        'elapsedMs': 0,
        'sourceVariables': <String, String?>{'token': 'abc'},
      });
      await call;

      expect(
        fixture.sourceVariables.snapshot('https://example-novel.test'),
        <String, String>{'token': 'abc'},
      );
    });

    test('evaluate_givenAClearedSourceVariable_removesIt', () async {
      final _Fixture fixture = _buildBridge();
      fixture.sourceVariables.merge(
        'https://example-novel.test',
        <String, String?>{'token': 'abc'},
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'v',
        'elapsedMs': 0,
        'sourceVariables': <String, String?>{'token': null},
      });
      await call;

      expect(
        fixture.sourceVariables.snapshot('https://example-novel.test'),
        isEmpty,
      );
    });
  });

  group('login header', () {
    test('evaluate_sendsTheStoredHeaderWithTheJob', () async {
      // 登录头随 job 下传（worker 读不到库），所以桥发出的信封里必须带着它。
      final SourceLoginHeaderStore loginHeaders = SourceLoginHeaderStore(
        repository: InMemorySourceLoginHeaderRepository(),
      );
      await loginHeaders.ensureLoaded('https://example-novel.test');
      loginHeaders.put('https://example-novel.test', '{"Token":"t"}');
      final _Fixture fixture = _buildBridge(loginHeaders: loginHeaders);
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();

      expect(fixture.workers.single.sent.last['loginHeader'], '{"Token":"t"}');
      await _finish(fixture.workers.single, call);
    });

    test('evaluate_givenAReportedLoginHeader_writesItToTheStore', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'v',
        'elapsedMs': 0,
        'loginHeader': '{"Token":"t"}',
      });
      await call;

      expect(
        fixture.loginHeaders.snapshot('https://example-novel.test'),
        '{"Token":"t"}',
      );
    });

    test('evaluate_givenAReportedLoginHeader_mergesItsCookie', () async {
      // 上游 `putLoginHeader` 会把其中的 Cookie 并进宗；宗才是真正发 Cookie 的地方。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'v',
        'elapsedMs': 0,
        'loginHeader': '{"Cookie":"sid=1"}',
      });
      await call;

      expect(
        fixture.cookies.cookieHeaderFor(
          Uri.parse('https://example-novel.test/'),
        ),
        'sid=1',
      );
    });

    test('evaluate_withoutAReportedLoginHeader_writesNothing', () async {
      final SourceLoginHeaderRepository repository =
          InMemorySourceLoginHeaderRepository();
      final SourceLoginHeaderStore loginHeaders = SourceLoginHeaderStore(
        repository: repository,
      );
      final _Fixture fixture = _buildBridge(loginHeaders: loginHeaders);
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'v',
        'elapsedMs': 0,
      });
      await call;

      expect(await repository.read('https://example-novel.test'), isNull);
    });

    test('evaluate_givenAMalformedLoginHeader_logsAndKeepsGoing', () async {
      // 信封里的值只可能是字符串；万一不是，丢一个头总比丢整个 job 好，但要留痕。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'v',
        'elapsedMs': 0,
        'loginHeader': 7,
      });
      final ParseResult<Object?> result = await call;

      expect(result, isA<ParseSuccess<Object?>>());
      expect(
        fixture.printer.events.map((LogEvent event) => event.message),
        contains(contains('malformed login header')),
      );
    });
  });

  group('stage bindings', () {
    test('evaluate_givenAnInstallId_sendsItWithTheJob', () async {
      // `java.androidId` 是主机事实：job 自己不带，桥补进载荷（M25/S3b）。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();

      final Map<String, Object?> job =
          fixture.workers.single.sent.last['job']! as Map<String, Object?>;
      expect(job['androidId'], 'test-install-id');
      await _finish(fixture.workers.single, call);
    });

    test('evaluate_sendsTheInfoMapSnapshotWithTheJob', () async {
      final _Fixture fixture = _buildBridge();
      fixture.infoMaps.merge('https://example-novel.test', <String, String?>{
        'kind': '玄幻',
      });
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();

      expect(fixture.workers.single.sent.last['infoMap'], <String, String>{
        'kind': '玄幻',
      });
      await _finish(fixture.workers.single, call);
    });

    test('evaluate_givenAReportedInfoMap_mergesItBack', () async {
      // 规则里的 `infoMap.x = y` 由 worker 读回来、桥合并进 store，下一条规则就看得见。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'v',
        'elapsedMs': 0,
        'infoMap': <String, String>{'kind': '玄幻', 'page': '2'},
      });
      await call;

      expect(
        fixture.infoMaps.snapshot('https://example-novel.test'),
        <String, String>{'kind': '玄幻', 'page': '2'},
      );
    });

    test('evaluate_givenAnInfoMapWithAnUnusableValue_dropsIt', () async {
      // worker 只会发字符串，但信封是外部输入：非字符串按「删键」处理，不炸掉 job。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': true,
        'value': 'v',
        'elapsedMs': 0,
        'infoMap': <String, Object?>{'kind': 7},
      });
      final ParseResult<Object?> result = await call;

      expect(result, isA<ParseSuccess<Object?>>());
      expect(fixture.infoMaps.snapshot('https://example-novel.test'), isEmpty);
    });
  });

  group('connect and ajaxAll', () {
    test('connect_givenAPage_answersTheResponseObject', () async {
      final _Fixture fixture = _buildBridge();
      fixture.http.serve('https://example-novel.test/a', '<html>A');
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'connect',
          'url': 'https://example-novel.test/a',
        }),
      );
      await pumpEventQueue();

      // 第一次是哨兵：宿主取页并答复，重放后才拿到值。
      final Map<String, Object?> reply = _replies(worker).last;
      expect(reply['ok'], isTrue);
      final Map<Object?, Object?> value =
          reply['value']! as Map<Object?, Object?>;
      expect(value['body'], '<html>A');
      expect(value[jsResponseMarker], isTrue);
      await _finish(worker, call);
    });

    test('connect_givenAFailingPage_answersAResponseNotAFailure', () async {
      // 上游 `connect` 把失败吞成响应正文：规则靠 `code()` / `body` 自己判断。
      final _Fixture fixture = _buildBridge();
      fixture.http.failWith(
        'https://example-novel.test/a',
        ParseFailureKind.networkFailed,
      );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'connect',
          'url': 'https://example-novel.test/a',
        }),
      );
      await pumpEventQueue();

      final Map<String, Object?> reply = _replies(worker).last;
      expect(reply['ok'], isTrue);
      final Map<Object?, Object?> value =
          reply['value']! as Map<Object?, Object?>;
      expect(value['body'], contains('networkFailed'));
      await _finish(worker, call);
    });

    test('ajaxAll_givenEveryPage_answersOneResponseEach', () async {
      final _Fixture fixture = _buildBridge();
      fixture.http
        ..serve('https://example-novel.test/1', 'one')
        ..serve('https://example-novel.test/2', 'two');
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'ajaxAll',
          'urls': <String>[
            'https://example-novel.test/1',
            'https://example-novel.test/2',
          ],
        }),
      );
      await pumpEventQueue();

      final Map<String, Object?> reply = _replies(worker).last;
      expect(reply['ok'], isTrue);
      final List<Object?> values = reply['value']! as List<Object?>;
      expect(values, hasLength(2));
      expect((values.first! as Map<Object?, Object?>)['body'], 'one');
      await _finish(worker, call);
    });

    test('ajaxAll_givenOneBadPage_failsTheCall', () async {
      // 上游 `mapAsync` 不吞异常：一页失败整次调用抛错，规则自己 try/catch。
      final _Fixture fixture = _buildBridge();
      fixture.http
        ..serve('https://example-novel.test/1', 'one')
        ..failWith(
          'https://example-novel.test/2',
          ParseFailureKind.networkFailed,
        );
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsSyncBinding, <String, Object?>{
          'operation': 'ajaxAll',
          'urls': <String>[
            'https://example-novel.test/1',
            'https://example-novel.test/2',
          ],
        }),
      );
      await pumpEventQueue();

      final Map<String, Object?> reply = _replies(worker).last;
      expect(reply['ok'], isFalse);
      expect(reply['message'], ParseFailureKind.networkFailed.name);
      await _finish(worker, call);
    });
  });

  group('openUrl', () {
    test('openUrl_whenARuleAsks_handsTheAddressToThePort', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(
        _hostCall(1, jsOpenUrlBinding, <String, Object?>{
          'url': 'https://a.test/book/1',
        }),
      );
      await pumpEventQueue();

      expect(fixture.opener.opened.single.$1, 'https://a.test/book/1');
      expect(fixture.opener.opened.single.$2, '示例书源');
      expect(_replies(fixture.workers.single).single['ok'], isTrue);
      await _finish(fixture.workers.single, call);
    });

    test(
      'openUrl_givenAMalformedCall_isRejectedWithoutFailingTheJob',
      () async {
        final _Fixture fixture = _buildBridge();
        final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
          _job(script: 'hold'),
        );
        await pumpEventQueue();
        fixture.workers.single.emit(
          _hostCall(1, jsOpenUrlBinding, <String, Object?>{'url': ''}),
        );
        await pumpEventQueue();

        expect(fixture.opener.opened, isEmpty);
        expect(_replies(fixture.workers.single).single['ok'], isFalse);
        await _finish(fixture.workers.single, call);
      },
    );
  });

  group('toasts', () {
    test('toast_whenARuleAsks_showsItOnceAndLogsIt', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      worker.emit(
        _hostCall(1, jsToastBinding, <String, Object?>{
          'message': '请先登录',
          'long': false,
        }),
      );
      await pumpEventQueue();
      // 重放会把同一行再走一遍：同一句在一个 job 里只贴一次。
      worker.emit(
        _hostCall(2, jsToastBinding, <String, Object?>{
          'message': '请先登录',
          'long': true,
        }),
      );
      await pumpEventQueue();

      expect(fixture.messages.messages, <String>['请先登录']);
      expect(
        _replies(worker)
            .every((Map<String, Object?> reply) => reply['ok'] == true),
        isTrue,
      );
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });

    test('toast_givenAMalformedCall_isRejected', () async {
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(
        _hostCall(1, jsToastBinding, <String, Object?>{'message': '   '}),
      );
      await pumpEventQueue();

      expect(
        _replies(fixture.workers.single).single['message'],
        'malformed toast call',
      );
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });
  });

  group('jsLib', () {
    test('evaluate_givenAJobWithALibrary_carriesItIntoTheWorker', () async {
      // 库脚本由引擎解析后随 job 下发（ADR-0078 S1）：worker 只负责把它跑在规则之前。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        // `hold` 让假 worker 不自动答复：这两条用例要自己决定结果信封。
        _job(script: 'hold', jsLib: 'function sign() { return 1; }'),
      );
      await pumpEventQueue();

      final Object? job = fixture.workers.single.sent.single['job'];
      expect(
        (job! as Map<String, Object?>)['jsLib'],
        'function sign() { return 1; }',
      );
      await _finish(fixture.workers.single, call);
    });

    test('evaluate_givenALibraryFailure_failsAsJsLibNotJsError', () async {
      // 库坏了要和规则自己出错区分开：两者的修法完全不同。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold', jsLib: 'function () {'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': 'SyntaxError: unexpected token',
        'libError': true,
        'elapsedMs': 1,
      });

      final ParseFailure<Never> failure = _failure(await call);
      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name:js:lib');
    });
  });

  group('replay limits', () {
    test('evaluate_givenAReplayLimitReport_failsAsJsReplay', () async {
      // 超过 pass 上限是一个**自己的**边界：报 js:replay，而不是 js:timeout。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      fixture.workers.single.emit(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': 'replay limit exceeded',
        'replayLimit': true,
        'elapsedMs': 1,
      });

      final ParseFailure<Never> failure = _failure(await call);
      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name:js:replay');
    });
  });

  group('verification memory', () {
    test('imageCode_whenTheSameCallRepeats_asksTheUserOnlyOnce', () async {
      // 重放会把整条规则重跑：同一张验证码不能被问第二遍（ADR-0076 §决策 4）。
      final _Fixture fixture = _buildBridge();
      final Future<ParseResult<Object?>> call = fixture.bridge.evaluate(
        _job(script: 'hold'),
      );
      await pumpEventQueue();
      final FakeJsWorkerHandle worker = fixture.workers.single;
      for (int callId = 1; callId <= 2; callId++) {
        worker.emit(
          _hostCall(callId, jsVerifyBinding, <String, Object?>{
            'operation': 'imageCode',
            'url': 'https://example-novel.test/code.asp',
          }),
        );
        await pumpEventQueue();
      }

      expect(fixture.verification.captchas, <String>[
        'https://example-novel.test/code.asp',
      ]);
      expect(
        _replies(worker).map((Map<String, Object?> reply) => reply['value']),
        <Object?>['A7bC', 'A7bC'],
      );
      expect(
        await _finish(fixture.workers.single, call),
        isA<ParseSuccess<Object?>>(),
      );
    });
  });
}

/// A synthetic font's bytes, for the byte-door tests.
Uint8List _fontBytes() => Uint8List.fromList(<int>[
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x63,
  0x6D,
  0x61,
  0x70,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x1C,
  0x00,
  0x00,
  0x00,
  0x04,
]);
