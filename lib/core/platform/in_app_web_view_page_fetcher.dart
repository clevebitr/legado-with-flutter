// coverage:ignore-file
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';

/// How long a headless page may take before the fetch is reported as a timeout.
const Duration webViewTimeout = Duration(seconds: 20);

/// How long the page gets to run its own scripts after `onLoadStop`.
const Duration webViewSettle = Duration(milliseconds: 400);

/// [WebPageFetcher] backed by `flutter_inappwebview` (ADR-0056).
///
/// A **headless** WebView is created per request: it needs no widget, runs on the UI isolate and
/// is disposed as soon as the HTML is read. The page's scripts are given a short settle window
/// after `onLoadStop`, because sources such as `ting55` write the audio address from JavaScript.
///
/// Errors, timeouts and a missing WebView runtime all come back as [ParseResult] failures; the
/// caller falls back to a plain GET, so a platform without WebView2 (or a page that fails to
/// render) degrades instead of breaking the book source.
final class InAppWebViewPageFetcher implements WebPageFetcher {
  /// Creates the fetcher.
  const InAppWebViewPageFetcher({required this._logger});

  final AppLogger _logger;

  @override
  bool get isSupported => true;

  @override
  Future<ParseResult<FetchedWebPage>> fetch({
    required String url,
    Map<String, String>? headers,
    required String rulePath,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final Completer<FetchedWebPage> completer = Completer<FetchedWebPage>();
    late final HeadlessInAppWebView headless;
    Timer? timeout;

    Future<void> finish(FetchedWebPage page) async {
      if (completer.isCompleted) {
        return;
      }
      final String finalUrl =
          headless.webViewController?.getUrl().toString() ?? page.url;
      completer.complete(FetchedWebPage(url: finalUrl, body: page.body));
    }

    void fail(Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(url),
        headers: headers == null || headers.isEmpty ? null : headers,
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: false,
      ),
      onLoadStop: (InAppWebViewController controller, WebUri? loadedUrl) async {
        await Future<void>.delayed(webViewSettle);
        try {
          final String? html = await controller.getHtml();
          if (html == null || html.isEmpty) {
            fail(StateError('The WebView returned no HTML.'));
            return;
          }
          await finish(
            FetchedWebPage(url: loadedUrl?.toString() ?? url, body: html),
          );
        } on Exception catch (error, stackTrace) {
          _logger.warning(
            'Reading the WebView HTML failed: rule=$rulePath',
            error,
            stackTrace,
          );
          fail(error);
        }
      },
      onReceivedError: (controller, request, error) {
        _logger.warning(
          'WebView load failed: rule=$rulePath host=${Uri.tryParse(url)?.host ?? 'unknown'}',
        );
        fail(StateError('The WebView failed to load the page.'));
      },
    );

    timeout = Timer(webViewTimeout, () {
      _logger.warning('WebView timed out: rule=$rulePath');
      fail(TimeoutException('The WebView did not finish loading.'));
    });

    try {
      await headless.run();
      final FetchedWebPage page = await completer.future;
      return ParseSuccess<FetchedWebPage>(page);
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        'WebView fetch failed: rule=$rulePath',
        error,
        stackTrace,
      );
      return failureAt<FetchedWebPage>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'webView',
      );
    } finally {
      timeout.cancel();
      await headless.dispose();
    }
  }
}
