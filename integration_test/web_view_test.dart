import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/in_app_web_view_page_fetcher.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Device-level check of the real headless WebView (ADR-0056).
///
/// The fetcher needs the platform WebView (Android WebView / Windows WebView2), which the host VM
/// does not have; this file is its only automated entry point. The page writes its result with
/// JavaScript, so a pass proves scripts really ran before `getHtml` was read.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('webPageFetcher_whenThePageRunsScript_returnsTheRenderedHtml', (
    WidgetTester tester,
  ) async {
    final Directory directory = await getApplicationSupportDirectory();
    final File file = File('${directory.path}/webview_probe.html');
    await file.writeAsString(
      '<html><body><div id="out">pending</div>'
      '<script>document.getElementById("out").textContent = "rendered";</script>'
      '</body></html>',
    );

    final InAppWebViewPageFetcher fetcher = InAppWebViewPageFetcher(
      logger: AppLogger(printer: SimplePrinter()),
    );
    final ParseResult<FetchedWebPage> result = await fetcher.fetch(
      url: Uri.file(file.path).toString(),
      rulePath: 'ruleContent',
    );

    expect(
      result,
      isA<ParseSuccess<FetchedWebPage>>(),
      reason: 'the WebView must render the page',
    );
    final FetchedWebPage page = (result as ParseSuccess<FetchedWebPage>).data;
    expect(page.body, contains('rendered'));
    expect(page.body, isNot(contains('pending')));
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets(
    'webPageFetcher_whenTheRulePosts_submitsTheBodyInsideTheWebView',
    (WidgetTester tester) async {
      // ADR-0057 §决策 1：表单型源的页面只有提交后才存在，所以 POST 必须真的由 WebView 发出，
      // 而不是先 GET 一次再渲染。这里用一个本地服务器同时当验收方：它记下收到的动词与 body。
      final List<String> methods = <String>[];
      final List<String> bodies = <String>[];
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      server.listen((HttpRequest request) async {
        methods.add(request.method);
        bodies.add(await utf8.decoder.bind(request).join());
        // 两种动词给不同内容：这样「渲染出来的到底是提交后的页面，还是又 GET 了一次」可判。
        final bool posted = request.method == 'POST';
        request.response
          ..headers.contentType = ContentType.html
          ..write(
            '<html><body><div id="out">pending</div>'
            '<script>document.getElementById("out").textContent = '
            '"${posted ? 'posted' : 'got'}-rendered";</script>'
            '</body></html>',
          );
        await request.response.close();
      });

      try {
        final InAppWebViewPageFetcher fetcher = InAppWebViewPageFetcher(
          logger: AppLogger(printer: SimplePrinter()),
        );
        final ParseResult<FetchedWebPage> result = await fetcher.fetch(
          url: 'http://127.0.0.1:${server.port}/search',
          rulePath: 'searchUrl',
          method: WebPageRequestMethod.post,
          body: 'k=%E5%89%91%E6%9D%A5',
          headers: const <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        );

        expect(
          result,
          isA<ParseSuccess<FetchedWebPage>>(),
          reason: 'the WebView must render the posted page',
        );
        final FetchedWebPage page =
            (result as ParseSuccess<FetchedWebPage>).data;
        expect(page.body, contains('posted-rendered'));
        expect(methods.first, 'POST');
        expect(bodies.first, 'k=%E5%89%91%E6%9D%A5');
      } finally {
        await server.close(force: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
