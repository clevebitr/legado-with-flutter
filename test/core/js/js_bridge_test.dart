import 'dart:isolate';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_js_worker.dart';
import '../../support/fake_log_printer.dart';

/// Bridge under test plus the doubles it talks to.
typedef _Fixture = ({
  QuickJsWorkerBridge bridge,
  FakeLogPrinter printer,
  List<FakeJsWorkerHandle> workers,
});

/// Builds a bridge whose launcher hands out [FakeJsWorkerHandle]s.
///
/// The budgets are injectable (and the timeout tests push them into the millisecond
/// range) because `docs/dev/testing.md` §6 forbids waiting for the real five seconds.
_Fixture _buildBridge({
  Duration timeout = const Duration(seconds: 5),
  Duration killGrace = const Duration(seconds: 2),
}) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final List<FakeJsWorkerHandle> workers = <FakeJsWorkerHandle>[];

  return (
    bridge: QuickJsWorkerBridge(
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      launch: ({required Duration timeout, required int memoryLimit}) async {
        final FakeJsWorkerHandle worker = FakeJsWorkerHandle();
        workers.add(worker);

        return worker;
      },
      timeout: timeout,
      killGrace: killGrace,
    ),
    printer: printer,
    workers: workers,
  );
}

/// A job whose script decides what the fake worker answers (see [FakeJsWorkerHandle]).
JsJob _job({String script = 'result', String rulePath = 'searchRule.name'}) =>
    JsJob(
      script: script,
      rulePath: rulePath,
      baseUrl: 'https://example-novel.test/search',
      page: 2,
      source: _sourceInfo(),
      result: 'raw',
    );

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
          contains('without a job in flight'),
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
  });
}
