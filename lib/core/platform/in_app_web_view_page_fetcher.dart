// coverage:ignore-file
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';

/// How long a headless page may take before the fetch is reported as a timeout.
const Duration webViewTimeout = Duration(seconds: 20);

/// How long the page gets to run its own scripts after `onLoadStop`.
const Duration webViewSettle = Duration(milliseconds: 400);

/// [WebPageFetcher] backed by `flutter_inappwebview`.
///
/// A headless WebView is created per request and disposed once the HTML is read; errors, timeouts
/// and a missing WebView runtime all come back as [ParseResult] failures so the caller can fall
/// back to a plain GET.
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
    WebPageRequestMethod method = WebPageRequestMethod.get,
    String? body,
    String? javaScript,
    Duration? delayTime,
    String? overrideUrlRegex,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final Completer<FetchedWebPage> completer = Completer<FetchedWebPage>();
    late final HeadlessInAppWebView headless;
    Timer? timeout;

    Future<void> finish(FetchedWebPage page) async {
      if (completer.isCompleted) {
        return;
      }
      // `getUrl()` 返回 `Future<WebUri?>`：不 await 就把 Future 的 `toString()` 当地址记下来，
      // 真机日志里就是 `url=Instance of 'Future<WebUri?>'`，随后所有相对地址都拿它当基准。
      final WebUri? loaded = await headless.webViewController?.getUrl();
      final String finalUrl = loaded?.toString() ?? page.url;
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
        // POST 型 `webView` 要把 body 一起交给页面：结果页只在表单提交后才存在。
        method: method == WebPageRequestMethod.post ? 'POST' : 'GET',
        body: method == WebPageRequestMethod.post && body != null
            ? Uint8List.fromList(utf8.encode(body))
            : null,
        headers: headers == null || headers.isEmpty ? null : headers,
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        // `overrideUrlRegex` 需要拦截导航，否则设置成更省的默认值（ADR-0068 §决策 6）。
        useShouldOverrideUrlLoading: overrideUrlRegex != null,
      ),
      shouldOverrideUrlLoading: overrideUrlRegex == null
          ? null
          : (controller, navigationAction) async {
              final WebUri? target = navigationAction.request.url;
              if (target == null ||
                  !target.toString().contains(overrideUrlRegex)) {
                return NavigationActionPolicy.ALLOW;
              }
              // 命中的地址就是结果页：不再继续跳转，读完它的 DOM 就收工。
              try {
                final String? html = await controller.getHtml();
                if (html != null && html.isNotEmpty) {
                  await finish(
                    FetchedWebPage(url: target.toString(), body: html),
                  );
                }
              } on Exception catch (error, stackTrace) {
                _logger.warning(
                  'Reading the overridden WebView page failed: rule=$rulePath',
                  error,
                  stackTrace,
                );
                fail(error);
              }

              return NavigationActionPolicy.CANCEL;
            },
      onLoadStop: (InAppWebViewController controller, WebUri? loadedUrl) async {
        // 站点自己写的 `webViewDelayTime` 追加在固定 settle 之后，并同样有上限（30 s 在解析侧）。
        await Future<void>.delayed(
          webViewSettle + (delayTime ?? Duration.zero),
        );
        try {
          final String? html = await _readBody(
            controller,
            javaScript: javaScript,
          );
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

  /// Reads the body of the rendered page: the script's result when [javaScript] is set, else the DOM.
  ///
  /// `webJs` (and `java.webView(url, js)`) is the same mechanism as a `@js:` rule but evaluated
  /// **inside** the page, where the site's own globals exist (ADR-0068 §决策 6). A script that
  /// throws or returns nothing is a failure rather than a silent DOM fallback: the rule asked for
  /// something the page could not produce.
  Future<String?> _readBody(
    InAppWebViewController controller, {
    required String? javaScript,
  }) async {
    if (javaScript == null || javaScript.isEmpty) {
      return controller.getHtml();
    }
    final Object? result = await controller.evaluateJavascript(
      source: javaScript,
    );

    return result?.toString();
  }
}
