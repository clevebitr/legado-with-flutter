import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/explore_layout_store.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/explore_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_explore_layout_store.dart';
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

    testWidgets('open_givenABookWithACover_showsTheCover', (
      WidgetTester tester,
    ) async {
      // S1（roadmap §3.9）：发现页是用户点名要看封面的那一页。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/list/c0.html',
          '<ul class="result-list"><div class="result-item">'
              '<div class="result-item-pic"><img src="/covers/1.jpg"/></div>'
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

      await tester.tap(find.text('玄幻'));
      await tester.pumpAndSettle();

      expect(find.byType(CoverImage), findsOneWidget);
    });

    testWidgets('open_givenACategoryWithoutUsableBooks_showsItsOwnEmptyState', (
      WidgetTester tester,
    ) async {
      // 列表命中了一条，但它的 `bookUrl` 规则取不到地址：条目按 §9 丢弃（warning），
      // 页面因此是「成功但没有书目」，而不是失败。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/list/c0.html',
          '<ul class="result-list"><div class="result-item">'
              '<div class="result-item-title">没有链接</div>'
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

      await tester.tap(find.text('玄幻'));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(ExplorePage),
      );

      // 这个文案不能是搜索的空态（那句话提到「关键词」，而发现页没有关键词）。
      expect(find.text(l10n.bookSourceExploreEmptyCategory), findsOneWidget);
      expect(find.text(l10n.bookSourceSearchEmpty), findsNothing);
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

    testWidgets('build_givenASectionHeader_showsItAsALabel', (
      WidgetTester tester,
    ) async {
      // 真实 `exploreUrl` 用 `══ 推荐 ══` 这样的分组标题（没有地址）把 chip 分组：它是标题，
      // 不是可点的分类（ADR-0069）。
      await pumpBookSourcePage(
        tester,
        page: const ExplorePage(),
        source: loadCorpusBookSource().copyWith(
          exploreUrl: '══ 推荐 ══::&&玄幻::/list/c0.html',
        ),
        http: FakeHttpClient()
          ..serve('https://example-novel.test/list/c0.html', '<div></div>'),
      );
      await tester.pumpAndSettle();

      expect(find.text('══ 推荐 ══'), findsOneWidget);
      // 标题不是 chip：点它不会去请求空地址。
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .map((ChoiceChip chip) => (chip.label as Text).data),
        <String>['玄幻'],
      );
    });

    testWidgets('source_whenTheSelectedSourceChanges_reloadsItsCategories', (
      WidgetTester tester,
    ) async {
      // 回归点（ADR-0058）：发现页在 shell 的 IndexedStack 里常驻，用户到书源管理里换源再
      // 切回来时页面不会重建。旧的「只请求一次」标记让 chip 行永远是上一个源的分类。
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final StoredBookSource first = repository.add(
        source: loadCorpusBookSource().copyWith(
          name: '甲源',
          url: 'https://a.test',
          exploreUrl: _exploreUrl(<String>['玄幻']),
        ),
      );
      final StoredBookSource second = repository.add(
        source: loadCorpusBookSource().copyWith(
          name: '乙源',
          url: 'https://b.test',
          exploreUrl: _exploreUrl(<String>['科幻']),
        ),
      );

      final ProviderContainer container = (await pumpBookSourcePage(
        tester,
        page: const ExplorePage(),
        source: null,
        repository: repository,
        http: FakeHttpClient(),
      ))!;

      // 默认选中第一条（列表顺序），分类是它的。
      expect(container.read(selectedBookSourceProvider).value?.id, first.id);
      expect(find.text('玄幻'), findsOneWidget);
      expect(find.text('科幻'), findsNothing);

      await container
          .read(selectedBookSourceProvider.notifier)
          .select(second.id);
      await tester.pumpAndSettle();

      expect(find.text('科幻'), findsOneWidget);
      expect(find.text('玄幻'), findsNothing);
    });
  });
  group('ExplorePage layout', () {
    /// The discover page of one category holding one book.
    Future<FakeExploreLayoutStore> pumpLayout(
      WidgetTester tester, {
      ExploreLayout? initial,
    }) async {
      final FakeExploreLayoutStore store = FakeExploreLayoutStore(
        initial: initial,
      );
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/list/c0.html',
          '<ul class="result-list"><div class="result-item">'
              '<div class="result-item-title"><a href="/book/1/">书名一</a></div>'
              '<div class="result-item-author">作者甲</div>'
              '</div></ul>',
        );

      await pumpBookSourcePage(
        tester,
        page: const ExplorePage(),
        source: loadCorpusBookSource().copyWith(
          exploreUrl: _exploreUrl(<String>['玄幻']),
        ),
        http: http,
        exploreLayoutStore: store,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('玄幻'));
      await tester.pumpAndSettle();

      return store;
    }

    testWidgets('layout_whenToggled_showsTheGridAndRemembersIt', (
      WidgetTester tester,
    ) async {
      // 上游有两种布局（`layoutState`）：列表 / 网格，切换记在偏好里（DECISIONS #77）。
      final FakeExploreLayoutStore store = await pumpLayout(tester);
      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(ExplorePage),
      );

      expect(find.byType(GridView), findsNothing);
      await tester.tap(find.byTooltip(l10n.exploreLayoutGrid));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('书名一'), findsOneWidget);
      expect(store.layout.isGrid, isTrue);
    });

    testWidgets('layout_whenStoredAsGrid_opensAsAGrid', (
      WidgetTester tester,
    ) async {
      // 记忆是读盘的那一半：偏好里是网格，打开就是网格。
      await pumpLayout(
        tester,
        initial: ExploreLayout.defaults.copyWith(isGrid: true),
      );

      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('columns_whenTheSliderIsReleased_storesThatOrientation', (
      WidgetTester tester,
    ) async {
      final FakeExploreLayoutStore store = await pumpLayout(
        tester,
        initial: ExploreLayout.defaults.copyWith(isGrid: true),
      );
      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(ExplorePage),
      );

      await tester.tap(find.byTooltip(l10n.exploreGridColumnsAction));
      await tester.pumpAndSettle();
      // 1–10 的分段滑块：往右拖到底是 10 列。
      await tester.drag(find.byType(Slider), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(store.layout.portraitColumns, 10);
      // 横屏那一份不动（两份分开记）。
      expect(store.layout.landscapeColumns, 7);
    });
  });
}
