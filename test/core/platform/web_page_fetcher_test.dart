import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnsupportedWebPageFetcher', () {
    test('isSupported_whenNothingBound_isFalse', () {
      expect(const UnsupportedWebPageFetcher().isSupported, isFalse);
    });

    test('fetch_whenNothingBound_reportsTheWebViewRule', () async {
      final ParseResult<FetchedWebPage> result =
          await const UnsupportedWebPageFetcher().fetch(
            url: 'https://example.test/page',
            rulePath: 'ruleContent',
          );

      expect(
        result,
        isA<ParseFailure<FetchedWebPage>>()
            .having(
              (ParseFailure<FetchedWebPage> failure) => failure.kind,
              'kind',
              ParseFailureKind.unsupportedRule,
            )
            .having(
              (ParseFailure<FetchedWebPage> failure) => failure.rulePath,
              'rulePath',
              'webView',
            ),
      );
    });
  });
}
