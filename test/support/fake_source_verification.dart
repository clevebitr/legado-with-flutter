import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';

/// Hand-written [SourceVerification] double (`docs/dev/testing.md` §4).
///
/// The real port pushes a page and waits for a human, so every test that only needs the
/// **plumbing** — which URL was opened, what the caller does with the answer — overrides it
/// here instead of pumping a WebView.
final class FakeSourceVerification implements SourceVerification {
  /// The outcome [verify] answers with.
  ParseResult<SourceVerificationOutcome> outcome =
      const ParseSuccess<SourceVerificationOutcome>(
        SourceVerificationOutcome(
          url: 'https://example-novel.test/after',
          body: '<p>solved</p>',
        ),
      );

  /// The answer [imageCode] gives.
  ParseResult<String> code = const ParseSuccess<String>('A7bC');

  /// Every verification request, in order.
  final List<SourceVerificationRequest> requests =
      <SourceVerificationRequest>[];

  /// Every captcha image asked for, in order.
  final List<String> captchas = <String>[];

  /// Whether the platform can show a page (a test can turn it off).
  bool supported = true;

  /// How many times [verify] was called.
  int get verifyCount => requests.length;

  @override
  bool get isSupported => supported;

  @override
  Future<ParseResult<SourceVerificationOutcome>> verify(
    SourceVerificationRequest request,
  ) async {
    requests.add(request);

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

    return code;
  }
}
