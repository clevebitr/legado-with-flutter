import 'package:flutter_reader/core/error/parse_result.dart';

/// A page rendered by a real WebView: the final [url] and its `outerHTML` [body].
final class FetchedWebPage {
  /// Creates a fetched page.
  const FetchedWebPage({required this.url, required this.body});

  /// The final URL, after redirects.
  final String url;

  /// The rendered HTML.
  final String body;
}

/// The HTTP verb a WebView request uses.
enum WebPageRequestMethod {
  /// A plain page load.
  get,

  /// A load whose payload is the rule's rendered body.
  post,
}

/// Loads a page in the platform's WebView for sources that ask for `,{webView:…}`.
abstract interface class WebPageFetcher {
  /// Whether this platform can render a page in a WebView.
  bool get isSupported;

  /// Loads [url] and returns the rendered page.
  ///
  /// [body] is the rule's rendered payload and is ignored for [WebPageRequestMethod.get].
  Future<ParseResult<FetchedWebPage>> fetch({
    required String url,
    Map<String, String>? headers,
    required String rulePath,
    WebPageRequestMethod method = WebPageRequestMethod.get,
    String? body,
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
    WebPageRequestMethod method = WebPageRequestMethod.get,
    String? body,
  }) async => const ParseFailure<FetchedWebPage>(
    kind: ParseFailureKind.unsupportedRule,
    rulePath: 'webView',
  );
}
