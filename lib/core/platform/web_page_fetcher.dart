import 'package:flutter_reader/core/error/parse_result.dart';

/// One page loaded by a real WebView (`docs/dev/book-source.md` §4.3, ADR-0056).
///
/// [url] is the final URL after redirects and [body] is the rendered `outerHTML`. A rule that
/// asked for `,{webView:…}` expects the DOM **after** the page's own scripts ran, which a plain
/// HTTP client cannot produce.
final class FetchedWebPage {
  /// Creates a fetched page.
  const FetchedWebPage({required this.url, required this.body});

  /// The final URL (after redirects).
  final String url;

  /// The rendered HTML.
  final String body;
}

/// Loads a page in the platform's WebView for sources that declare `,{webView:…}`
/// (`book-source.md` §4.3, ADR-0056).
///
/// The engine lives in `domain/` and a WebView needs the UI isolate, so the capability crosses
/// this port: the use case calls it, the composition root binds the platform implementation, and
/// a platform without a WebView answers [isSupported] `false` so the caller falls back to the
/// plain HTTP request.
abstract interface class WebPageFetcher {
  /// Whether this platform can render a page in a WebView.
  bool get isSupported;

  /// Loads [url] and returns the rendered HTML.
  ///
  /// [headers] are the source's own request headers; [rulePath] keeps a failure locatable
  /// (C-SRC-8).
  Future<ParseResult<FetchedWebPage>> fetch({
    required String url,
    Map<String, String>? headers,
    required String rulePath,
  });
}

/// The answer when no WebView is bound: unsupported, so the caller falls back to HTTP.
final class UnsupportedWebPageFetcher implements WebPageFetcher {
  /// Creates the unsupported port.
  const UnsupportedWebPageFetcher();

  @override
  bool get isSupported => false;

  @override
  Future<ParseResult<FetchedWebPage>> fetch({
    required String url,
    Map<String, String>? headers,
    required String rulePath,
  }) async => const ParseFailure<FetchedWebPage>(
    kind: ParseFailureKind.unsupportedRule,
    rulePath: 'webView',
  );
}
