import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/source_budget.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_clock.dart';

/// A budget that answers immediately with [value] while in budget.
Future<ParseResult<String>> _answer(String value) async =>
    ParseSuccess<String>(value);

void main() {
  group('SourceBudget', () {
    test('remaining_givenAFreshBudget_isTheWholeLimit', () {
      final FakeClock clock = FakeClock();

      expect(
        SourceBudget(const Duration(seconds: 60), clock: clock).remaining,
        const Duration(seconds: 60),
      );
    });

    test('remaining_givenTimeSpent_shrinksAndNeverGoesNegative', () {
      final FakeClock clock = FakeClock();
      final SourceBudget budget = SourceBudget(
        const Duration(seconds: 60),
        clock: clock,
      );

      clock.advance(const Duration(seconds: 20));
      expect(budget.remaining, const Duration(seconds: 40));
      expect(budget.isExpired, isFalse);

      clock.advance(const Duration(minutes: 5));
      expect(budget.remaining, Duration.zero);
      expect(budget.isExpired, isTrue);
    });

    test('run_givenAnAnswerWithinBudget_returnsItUnchanged', () async {
      final SourceBudget budget = SourceBudget(
        const Duration(seconds: 60),
        clock: FakeClock(),
      );

      final ParseResult<String> result = await budget.run(
        () => _answer('ok'),
        rulePath: 'searchUrl',
      );

      expect((result as ParseSuccess<String>).data, 'ok');
    });

    test('run_givenAPlannedFailure_returnsTheFailureNotATimeout', () async {
      final SourceBudget budget = SourceBudget(
        const Duration(seconds: 60),
        clock: FakeClock(),
      );

      final ParseResult<String> result = await budget.run(
        () async => failureAt<String>(
          kind: ParseFailureKind.notFound,
          rulePath: 'ruleToc',
        ),
        rulePath: 'searchUrl',
      );

      // 预算只决定「等多久」，不决定「成不成」：源自己的失败原样穿过去。
      expect((result as ParseFailure<String>).kind, ParseFailureKind.notFound);
      expect(result.rulePath, 'ruleToc');
    });

    test('run_givenAnExhaustedBudget_answersATimeoutWithoutCalling', () async {
      final FakeClock clock = FakeClock();
      final SourceBudget budget = SourceBudget(
        const Duration(seconds: 60),
        clock: clock,
      );
      clock.advance(const Duration(seconds: 61));
      var called = false;

      final ParseResult<String> result = await budget.run(() async {
        called = true;

        return _answer('never');
      }, rulePath: 'ruleContent');

      expect(called, isFalse);
      expect(
        (result as ParseFailure<String>).kind,
        ParseFailureKind.networkTimeout,
      );
      expect(result.rulePath, 'ruleContent');
    });

    test('run_givenAnOperationThatOutlivesTheBudget_answersATimeout', () async {
      // 1 ms 是真实计时器，不是 sleep：操作永远不完成，`run` 必须自己收尾（ADR-0049）。
      final SourceBudget budget = SourceBudget(
        const Duration(milliseconds: 1),
        clock: FakeClock(),
      );

      final ParseResult<String> result = await budget.run(
        () => Completer<ParseResult<String>>().future,
        rulePath: 'searchUrl',
      );

      expect(
        (result as ParseFailure<String>).kind,
        ParseFailureKind.networkTimeout,
      );
      expect(result.rulePath, 'searchUrl');
    });
  });
}
