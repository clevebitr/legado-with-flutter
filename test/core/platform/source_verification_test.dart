import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_log_printer.dart';

/// A URL the tests construct their value objects with (runtime, not `const`).
// ignore: prefer_const_declarations  const folding hides the line from lcov
final String _challengeUrl = 'https://source.test/challenge';

void main() {
  group('SourceVerificationRequest', () {
    test('new_whenCalled_keepsEveryField', () {
      // 运行时构造（值来自局部变量，保持非 const）：`const` 构造会被编译期折叠，
      // 覆盖率看不到构造那一行（M14 记过的坑）。
      // ignore: prefer_const_declarations
      final String title = '验证';
      // ignore: prefer_const_constructors
      final SourceVerificationRequest request = SourceVerificationRequest(
        sourceUrl: 'https://source.test',
        sourceName: '测试源',
        url: _challengeUrl,
        title: title,
      );

      expect(request.refetchAfterSuccess, isTrue);
      expect(request.html, isNull);
      expect(request.url, _challengeUrl);
    });
  });

  group('SourceVerificationOutcome', () {
    test('new_whenCalled_keepsBothFields', () {
      // ignore: prefer_const_declarations
      final String body = '<html></html>';
      // ignore: prefer_const_constructors
      final SourceVerificationOutcome outcome = SourceVerificationOutcome(
        url: _challengeUrl,
        body: body,
      );

      expect(outcome.url, _challengeUrl);
      expect(outcome.body, body);
    });
  });

  group('UnboundSourceVerification', () {
    test('isSupported_whenNothingIsBound_answersFalse', () {
      expect(const UnboundSourceVerification().isSupported, isFalse);
    });

    test('verify_whenNothingIsBound_answersALocatableFailure', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundSourceVerification verification = UnboundSourceVerification(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<SourceVerificationOutcome> result = await verification
          .verify(
            const SourceVerificationRequest(
              sourceUrl: 'https://source.test',
              sourceName: '测试源',
              url: 'https://source.test/challenge',
              title: '验证',
            ),
          );

      expect(
        (result as ParseFailure<SourceVerificationOutcome>).kind,
        ParseFailureKind.unsupportedRule,
      );
      expect(result.rulePath, 'java.startBrowser');
      expect(printer.events.single.message, contains('verification page'));
    });

    test('imageCode_whenNothingIsBound_answersALocatableFailure', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundSourceVerification verification = UnboundSourceVerification(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<String> result = await verification.imageCode(
        sourceUrl: 'https://source.test',
        sourceName: '测试源',
        imageUrl: 'https://source.test/code.jpg',
        title: '验证码',
      );

      expect(
        (result as ParseFailure<String>).kind,
        ParseFailureKind.unsupportedRule,
      );
      expect(result.rulePath, 'java.getVerificationCode');
    });
  });
}
