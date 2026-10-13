import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/explore_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/offline_corpus.dart';

/// A discover page with one category per entry of [titles].
///
/// The URL slug is ASCII on purpose: a non-ASCII path is percent-encoded when it is resolved
/// against the book source URL (§4), and this test wants to name the URL it served.
String _exploreUrl(List<String> titles) => <String>[
  for (var index = 0; index < titles.length; index++)
    '${titles[index]}::/list/c$index.html',
].join('&&');

void main() {
  group('ExplorePage', () {
    testWidgets('build_givenNoBookSource_showsTheMissingSourceState', (
      WidgetTester tester,
    ) async {
      await pumpBookSourcePage(
        tester,
        page: const ExplorePage(),
        source: null,
        http: FakeHttpClient(),
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(ExplorePage),
      );

      expect(find.text(l10n.bookSourceMissingSource), findsOneWidget);
      // 没有书源时不发起任何请求（分类来自书源模型，没有模型就没有分类）。
      expect(find.text(l10n.bookSourceExploreEmpty), findsNothing);
    });

    testWidgets('build_givenASourceWithoutCategories_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await pumpBookSourcePage(
        tester,
        page: const ExplorePage(),
        // 没有 `exploreUrl` 的书源是正常书源：空态，不是失败（book-source.md §4.2）。
        source: loadCorpusBookSource(),
        http: FakeHttpClient(),
      );
      await tester.pumpAndSettle();

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(ExplorePage),
      );

      expect(find.text(l10n.bookSourceExploreEmpty), findsOneWidget);
    });

    testWidgets('open_givenACategory_listsItsBooks', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/list/c0.html',
          '<ul class="result-list"><div class="result-item">'
              '<div class="result-item-title"><a href="/book/1/">书名一</a></div>'
              '</div></ul>',
        );

      await pumpBookSourcePage(
        tester,
        page: const ExplorePage(),
        source: loadCorpusBookSource().copyWith(
          exploreUrl: _exploreUrl(<String>['玄幻']),
        ),
        http: http,
      );
      await tester.pumpAndSettle();

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(ExplorePage),
      );
      expect(find.text(l10n.bookSourceExplorePrompt), findsOneWidget);

      await tester.tap(find.text('玄幻'));
      await tester.pumpAndSettle();

      // `ruleExplore` 缺失 → 整条回落 searchRule（ADR-0035 §决策 2），语料里的
      // `class.result-item` 规则读到上面那一条命中。
      expect(http.requestedUrls, <String>[
        'https://example-novel.test/list/c0.html',
      ]);
      expect(find.text('书名一'), findsOneWidget);
    });

    testWidgets('open_givenAFailingCategory_keepsTheRowAndShowsTheFailure', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(
          'https://example-novel.test/list/c0.html',
          ParseFailureKind.notFound,
        );

      await pumpBookSourcePage(
        tester,
        page: const ExplorePage(),
        source: loadCorpusBookSource().copyWith(
          exploreUrl: _exploreUrl(<String>['玄幻', '都市']),
        ),
        http: http,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('玄幻'));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(ExplorePage),
      );

      // 单分类失败只影响该分类（book-source.md §9）：分类行还在，失败有文案与重试。
      expect(find.text(l10n.failureNotFound), findsOneWidget);
      expect(find.text('玄幻'), findsOneWidget);
      expect(find.text('都市'), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsOneWidget);
    });
  });
}
