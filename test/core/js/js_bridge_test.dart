import 'dart:async';
import 'dart:isolate';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
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
  void Function(FakeJsWorkerHandle worker)? configure,
}) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final List<FakeJsWorkerHandle> workers = <FakeJsWorkerHandle>[];
  final FakeHttpClient http = FakeHttpClient();
  final JsVariableStore store = variables ?? JsVariableStore();

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
    ),
    printer: printer,
    workers: workers,
    http: http,
    variables: store,
  );
}

/// A job whose script decides what the fake worker answers (see [FakeJsWorkerHandle]).
JsJob _job({
  String script = 'result',
  String rulePath = 'searchRule.name',
  JsParseEvaluator? parseEvaluator,
  Map<String, String>? sourceHeaders,
}) => JsJob(
  script: script,
  rulePath: rulePath,
  baseUrl: 'https://example-novel.test/search',
  page: 2,
  source: _sourceInfo(),
  result: 'raw',
  sourceHeaders: sourceHeaders,
  parseEvaluator: parseEvaluator,
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

/// Returns the failure of [result], failing the test when it succeeded.
ParseFailure<Never> _failure(ParseResult<Object?> result) => switch (result) {
  ParseFailure<Object?>(:final ParseFailureKind kind, :final String rulePath) =>
    ParseFailure<Never>(kind: kind, rulePath: rulePath),
  ParseSuccess<Object?>() => fail('Expected a failure.'),
};

void main() {
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
}
