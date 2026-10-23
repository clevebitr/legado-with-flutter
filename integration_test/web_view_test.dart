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
}
