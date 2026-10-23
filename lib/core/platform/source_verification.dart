import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';

/// One 「人机验证」 the user has to solve.
final class SourceVerificationRequest {
  /// Creates a verification request.
  const SourceVerificationRequest({
    required this.sourceUrl,
    required this.sourceName,
    required this.url,
    required this.title,
    this.headers,
    this.html,
    this.refetchAfterSuccess = true,
  });

  /// `bookSourceUrl` of the source that asked.
  final String sourceUrl;

  /// The source's display name.
  final String sourceName;

  /// The address the user has to open and solve.
  final String url;

  /// The page title.
  final String title;

  /// The source's request headers.
  final Map<String, String>? headers;

  /// An HTML document to show instead of loading [url].
  final String? html;

  /// Whether to re-fetch the page over HTTP once the user finishes.
  final bool refetchAfterSuccess;
}

/// What a verification page hands back: the page the engine may parse.
final class SourceVerificationOutcome {
  /// Creates an outcome.
  const SourceVerificationOutcome({required this.url, required this.body});

  /// The final URL, after redirects.
  final String url;

  /// The page body: the refetched HTML, or the WebView's `outerHTML`.
  final String body;
}

/// Asks a human to solve a book source's anti-bot check.
abstract interface class SourceVerification {
  /// Whether this platform can show a verification page.
  bool get isSupported;

  /// Opens the browser for [request] and answers the page once the user confirms.
  ///
  /// Closing the page answers `cancelled`; one that never returns answers `networkTimeout`.
  Future<ParseResult<SourceVerificationOutcome>> verify(
    SourceVerificationRequest request,
  );

  /// Shows [imageUrl] and answers the text the user typed.
  Future<ParseResult<String>> imageCode({
    required String sourceUrl,
    required String sourceName,
    required String imageUrl,
    required String title,
  });
}

/// The answer when nothing bound [SourceVerification]: an observable failure, never a hang.
final class UnboundSourceVerification implements SourceVerification {
  /// Creates the unbound port; `_logger` receives the warning.
  // ignore: prefer_initializing_formals  可空形参没法用 this._logger 初始化
  const UnboundSourceVerification({AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;

  @override
  bool get isSupported => false;

  @override
  Future<ParseResult<SourceVerificationOutcome>> verify(
    SourceVerificationRequest request,
  ) async {
    _logger?.warning(
      'No SourceVerification is bound: the verification page did not open.',
    );

    return const ParseFailure<SourceVerificationOutcome>(
      kind: ParseFailureKind.unsupportedRule,
      rulePath: 'java.startBrowser',
    );
  }

  @override
  Future<ParseResult<String>> imageCode({
    required String sourceUrl,
    required String sourceName,
    required String imageUrl,
    required String title,
  }) async {
    _logger?.warning(
      'No SourceVerification is bound: the captcha dialog did not open.',
    );

    return const ParseFailure<String>(
      kind: ParseFailureKind.unsupportedRule,
      rulePath: 'java.getVerificationCode',
    );
  }
}
