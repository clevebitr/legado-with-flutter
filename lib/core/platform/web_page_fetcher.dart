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
  /// [javaScript] is `webJs` / `java.webView(url, js)`: a script evaluated **inside** the rendered
  /// page whose string result becomes the body (ADR-0068 §决策 6). `null` returns the DOM.
  ///
  /// [delayTime] makes the port wait longer than its settle window before reading the page
  /// (`webViewDelayTime`), for sites that fill the page after the load event. [overrideUrlRegex]
  /// stops the load at the first navigation whose URL matches and answers that page
  /// (`overrideUrlRegex`), which is how a source that redirects to a result page is read.
  Future<ParseResult<FetchedWebPage>> fetch({
    required String url,
    Map<String, String>? headers,
    required String rulePath,
    WebPageRequestMethod method = WebPageRequestMethod.get,
    String? body,
    String? javaScript,
    Duration? delayTime,
    String? overrideUrlRegex,
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
    String? javaScript,
    Duration? delayTime,
    String? overrideUrlRegex,
  }) async => const ParseFailure<FetchedWebPage>(
    kind: ParseFailureKind.unsupportedRule,
    rulePath: 'webView',
  );
}
