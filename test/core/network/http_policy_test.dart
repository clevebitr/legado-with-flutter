import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HttpPolicy', () {
    test(
      'HttpPolicy_whenCreatedWithoutArguments_usesTheDocumentedDefaults',
      () {
        const HttpPolicy policy = HttpPolicy();

        expect(policy.timeout, const Duration(seconds: 15));
        expect(policy.maxRetries, 1);
        expect(policy.maxConcurrentRequestsPerSource, 3);
        expect(policy.userAgent, 'flutter_reader');
        expect(policy.allowPlainHttp, isFalse);
      },
    );

    test('HttpPolicy_whenRetriesAreNegative_throwsAssertionError', () {
      expect(() => HttpPolicy(maxRetries: -1), throwsAssertionError);
    });

    test('HttpPolicy_givenAConcurrencyBudget_keepsIt', () {
      const HttpPolicy policy = HttpPolicy(maxConcurrentRequestsPerSource: 8);

      expect(policy.maxConcurrentRequestsPerSource, 8);
    });

    test(
      'HttpPolicy_whenTheConcurrencyBudgetIsNotPositive_throwsAssertionError',
      () {
        expect(
          () => HttpPolicy(maxConcurrentRequestsPerSource: 0),
          throwsAssertionError,
        );
      },
    );
  });
}
