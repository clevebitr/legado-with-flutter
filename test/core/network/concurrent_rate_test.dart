import 'package:flutter_reader/core/network/concurrent_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseConcurrentRate', () {
    test('parseConcurrentRate_givenTwoIntegers_readsBothSides', () {
      final ConcurrentRateDeclaration declaration = parseConcurrentRate(
        '5/1000',
      );

      expect(declaration.isLimited, isTrue);
      expect(declaration.isInvalid, isFalse);
      expect(declaration.rate?.times, 5);
      expect(declaration.rate?.intervalMilliseconds, 1000);
    });

    test('parseConcurrentRate_givenASingleInteger_readsOnePerInterval', () {
      // 单个整数 x = 每 x 毫秒 1 次（ConcurrentRateLimiter.kt:36-45）。
      final ConcurrentRateDeclaration declaration = parseConcurrentRate('500');

      expect(declaration.rate?.times, 1);
      expect(declaration.rate?.intervalMilliseconds, 500);
    });

    test('parseConcurrentRate_givenSurroundingSpace_ignoresIt', () {
      // 与上游的唯一一处宽容差异：上游对原始子串调 `toInt()`，`"10 / 5"` 在那里抛异常。
      expect(parseConcurrentRate(' 10 / 5 ').rate?.times, 10);
      expect(parseConcurrentRate(' 10 / 5 ').rate?.intervalMilliseconds, 5);
    });

    test('parseConcurrentRate_givenNoGate_answersNone', () {
      // 缺失 / 空白 / `"0"` 都是「不限速」的拼法（ConcurrentRateLimiter.kt:52）。
      for (final String? declaration in <String?>[null, '', '   ', '0']) {
        final ConcurrentRateDeclaration parsed = parseConcurrentRate(
          declaration,
        );

        expect(parsed.isLimited, isFalse, reason: 'declaration=$declaration');
        expect(parsed.isInvalid, isFalse, reason: 'declaration=$declaration');
      }
    });

    test('parseConcurrentRate_givenNonIntegers_answersInvalid', () {
      for (final String declaration in <String>[
        'abc',
        '1.5/1000',
        '1/2/3',
        '/1000',
        '5/',
        '5/abc',
      ]) {
        final ConcurrentRateDeclaration parsed = parseConcurrentRate(
          declaration,
        );

        expect(parsed.isInvalid, isTrue, reason: 'declaration=$declaration');
        expect(parsed.rate, isNull, reason: 'declaration=$declaration');
      }
    });

    test('parseConcurrentRate_givenNonPositiveNumbers_answersInvalid', () {
      // ADR-0036 §决策 2：`n <= 0` / `m <= 0` / `x <= 0` 都是非法声明，忽略 + warning。
      for (final String declaration in <String>[
        '0/1000',
        '-1/1000',
        '5/0',
        '5/-1',
        '-5',
        '00',
      ]) {
        final ConcurrentRateDeclaration parsed = parseConcurrentRate(
          declaration,
        );

        expect(parsed.isInvalid, isTrue, reason: 'declaration=$declaration');
      }
    });

    test('parseConcurrentRate_givenAnInvalidDeclaration_explainsWhy', () {
      expect(parseConcurrentRate('abc').invalidReason, 'not an integer');
      expect(parseConcurrentRate('1/x').invalidReason, 'not two integers');
      expect(
        parseConcurrentRate('0/1').invalidReason,
        'times must be positive',
      );
      expect(
        parseConcurrentRate('1/0').invalidReason,
        'interval must be positive',
      );
    });

    test('ConcurrentRate_givenTheSameNumbers_isEqual', () {
      const ConcurrentRate one = ConcurrentRate(
        times: 2,
        intervalMilliseconds: 100,
      );

      expect(one, const ConcurrentRate(times: 2, intervalMilliseconds: 100));
      expect(
        one,
        isNot(const ConcurrentRate(times: 2, intervalMilliseconds: 101)),
      );
      expect(
        one.hashCode,
        const ConcurrentRate(times: 2, intervalMilliseconds: 100).hashCode,
      );
      expect(one.toString(), 'ConcurrentRate(2/100)');
    });
  });
}
