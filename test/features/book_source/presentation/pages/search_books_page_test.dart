import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/app_shell.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_detail_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_import_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_list_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/search_books_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_search_scope_store.dart';
import '../../../../support/offline_corpus.dart';

void main() {
  group('SearchBooksPage', () {
    testWidgets('sources_givenTheManageAction_opensTheListAndTheImportScreen', (
      WidgetTester tester,
    ) async {
      // 5.1 的验收包含「入口可达」：搜索页 → 书源列表 → 导入页（docs/dev/roadmap.md 5.1）。
      await pumpReaderApp(
        tester,
        source: loadCorpusBookSource(),
        http: serveCorpusPages(FakeHttpClient()),
      );
      await _openSearchTab(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.bookSourceListTitle));
      await tester.pumpAndSettle();
      expect(find.byType(BookSourceListPage), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.actionImport));
      await tester.pumpAndSettle();
      expect(find.byType(BookSourceImportPage), findsOneWidget);
    });

    testWidgets(
      'build_givenNoBookSource_showsTheEmptyStateAndDisablesTheAction',
      (WidgetTester tester) async {
        await pumpBookSourcePage(
          tester,
          page: const SearchBooksPage(),
          source: null,
          http: FakeHttpClient(),
        );

        final AppLocalizations l10n = localizationOf(
          tester,
          find.byType(SearchBooksPage),
        );

        expect(find.text(l10n.bookSourceMissingSource), findsOneWidget);
        // 没有书源就没有可解析的规则集：按钮必须禁用，但仍带语义标签（C-UI-7）。
        expect(find.byTooltip(l10n.bookSourceSearchAction), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.ancestor(
                  of: find.byTooltip(l10n.bookSourceSearchAction),
                  matching: find.byType(IconButton),
                ),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets('search_givenABlankKeyword_requestsNothing', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpSearchPage(
        tester,
        repository: FakeBookSourceRepository()
          ..add(source: loadCorpusBookSource()),
        http: http,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(SearchBooksPage),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byTooltip(l10n.bookSourceSearchAction));
      await tester.pumpAndSettle();

      expect(http.requestedUrls, isEmpty);
      expect(find.text(l10n.bookSourceSearchPrompt), findsOneWidget);
    });

    testWidgets('search_givenTheOfflineCorpus_listsTheHits', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpSearchPage(
        tester,
        repository: FakeBookSourceRepository()
          ..add(source: loadCorpusBookSource()),
        http: http,
      );
      await _search(tester, corpusKeyword);

      final AppLocalizations l10n = _l10n(tester);
      // 命中的是生产链路：模板渲染 + 关键词编码 + 规则引擎 + 合并去重。
      expect(http.requestedUrls, <String>[corpusSearchUrl]);
      expect(find.text('书名一'), findsOneWidget);
      // 作者行现在走 ARB（与详情页同一句话），并且与「N 个来源」同在一个副标题里。
      expect(
        find.textContaining(l10n.bookSourceAuthorLine('作者甲')),
        findsOneWidget,
      );
      expect(find.text('书名二'), findsOneWidget);
      // 只有一个来源命中：行内标出来源数（ADR-0046 §决策 4）。
      expect(find.textContaining(l10n.searchOriginsLine(1)), findsWidgets);
    });

    testWidgets('search_givenAnUpdateTimeRule_showsTheUpdateLine', (
      WidgetTester tester,
    ) async {
      // §3.7 的「updateTime 的展示」：规则给了就显示，没给就不显示（不写「未知」）。
      final BookSource source = loadCorpusBookSource().copyWith(
        searchRule: loadCorpusBookSource().searchRule.copyWith(
          updateTime: 'class.result-game-item-info-tag.2@tag.span.1@text',
        ),
      );

      await pumpSearchPage(
        tester,
        repository: FakeBookSourceRepository()..add(source: source),
        http: serveCorpusPages(FakeHttpClient()),
      );
      await _search(tester, corpusKeyword);

      // ignore: avoid_print
      expect(
        find.textContaining(_l10n(tester).bookSourceUpdateTimeLine('')),
        findsWidgets,
      );
    });

    testWidgets('search_givenHitsWithoutUrl_showsTheEmptyResultMessage', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          corpusSearchUrl,
          '<div class="result-item">'
          '<div class="result-item-title"><a>无链接</a></div>'
          '</div>',
        );

      await pumpSearchPage(
        tester,
        repository: FakeBookSourceRepository()
          ..add(source: loadCorpusBookSource()),
        http: http,
      );
      await _search(tester, corpusKeyword);

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(SearchBooksPage),
      );

      // 「命中但被跳过」是成功且为空：不是失败，也不是加载中。
      expect(find.text(l10n.bookSourceSearchEmpty), findsOneWidget);
    });

    testWidgets('search_givenAnUnsupportedRule_showsTheUnsupportedMessage', (
      WidgetTester tester,
    ) async {
      final BookSource source = loadCorpusBookSource();
      final BookSource unsupported = source.copyWith(
        // 顶层规则被拒才是整次失败（ADR-0026 §决策 1）；非顶层字段会降级。
        searchRule: source.searchRule.copyWith(bookList: '@xpath://div'),
      );
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpSearchPage(
        tester,
        repository: FakeBookSourceRepository()..add(source: unsupported),
        http: http,
      );
      await _search(tester, corpusKeyword);

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(SearchBooksPage),
      );

      expect(find.text(l10n.failureUnsupportedRule), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsNothing);
    });

    testWidgets('scope_whenAGroupIsPicked_searchesOnlyThatGroup', (
      WidgetTester tester,
    ) async {
      // 范围是「哪些源参与」的唯一决定者（ADR-0046 §决策 1）。
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(
          source: loadCorpusBookSource().copyWith(name: '精选源'),
          groupName: '精选',
        )
        ..add(
          source: loadCorpusBookSource().copyWith(
            name: '玄幻源',
            url: 'https://other.test',
          ),
          groupName: '玄幻',
        );
      final FakeSearchScopeStore store = FakeSearchScopeStore();

      await pumpSearchPage(
        tester,
        repository: repository,
        http: http,
        scopeStore: store,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.text(l10n.searchScopeAll));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RadioListTile<String>, '精选'));
      await tester.pumpAndSettle();

      expect(store.scope, const BookSearchScope.groups(<String>{'精选'}));
      expect(find.text('精选'), findsWidgets);
    });

    testWidgets('scope_whenANamedSourceIsTicked_redrawsTheBoxAndCanUntickIt', (
      WidgetTester tester,
    ) async {
      // 回归点（ADR-0058）：范围 sheet 曾经只是一次性快照 —— 勾选改了 provider，但 sheet 不重画，
      // 勾选框永远是空的，于是既看不到勾、也取消不了（tile 永远报 `false`，只能一路加）。
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: loadCorpusBookSource().copyWith(name: '甲源'))
        ..add(
          source: loadCorpusBookSource().copyWith(
            name: '乙源',
            url: 'https://b.test',
          ),
        );
      final FakeSearchScopeStore store = FakeSearchScopeStore();

      await pumpSearchPage(
        tester,
        repository: repository,
        http: serveCorpusPages(FakeHttpClient()),
        scopeStore: store,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.text(l10n.searchScopeAll));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, '甲源'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, '甲源'),
            )
            .value,
        isTrue,
        reason: '勾了必须看得见',
      );
      expect(
        store.scope,
        const BookSearchScope.sources(<ScopeSource>[
          ScopeSource(name: '甲源', url: 'https://example-novel.test'),
        ]),
      );

      // 再点一次能取消：最后一个勾去掉后回到「全部启用源」。
      await tester.tap(find.widgetWithText(CheckboxListTile, '甲源'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, '甲源'),
            )
            .value,
        isFalse,
      );
      expect(store.scope, BookSearchScope.defaults);
    });

    testWidgets('start_whenTheStoredScopeNoLongerExists_saysItFellBack', (
      WidgetTester tester,
    ) async {
      // 存下来的范围指向一个已经不存在分组（改名 / 删源后残留）：回落仍然有效，但必须说出来，
      // 否则用户看到的是「我选了分组，却搜了全库」=「范围筛选失效」（ADR-0058）。
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());
      final FakeSearchScopeStore store = FakeSearchScopeStore(
        initial: const BookSearchScope.groups(<String>{'已删除的分组'}),
      );

      await pumpSearchPage(
        tester,
        repository: FakeBookSourceRepository()
          ..add(source: loadCorpusBookSource()),
        http: http,
        scopeStore: store,
      );
      await _search(tester, corpusKeyword);

      final AppLocalizations l10n = _l10n(tester);
      expect(find.text(l10n.searchScopeFellBack), findsOneWidget);
    });

    testWidgets('filters_whenAnExactMatchIsPicked_keepsOnlyExactHits', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpSearchPage(
        tester,
        repository: FakeBookSourceRepository()
          ..add(source: loadCorpusBookSource()),
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.searchFilterLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.searchMatchExact));
      await tester.pumpAndSettle();
      // 关掉 sheet 再搜索。
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await _search(tester, corpusKeyword);

      // 语料里的命中书名是「书名一/二」，作者不等于关键词 —— 精确模式下一条都不留。
      expect(find.text(l10n.bookSourceSearchEmpty), findsOneWidget);
    });

    testWidgets('search_givenAHitWithACover_showsIt', (
      WidgetTester tester,
    ) async {
      // S1：命中带 `coverUrl` 时列表要显示封面（以前根本没有图片控件）。
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpSearchPage(
        tester,
        repository: FakeBookSourceRepository()
          ..add(source: loadCorpusBookSource()),
        http: http,
      );
      await _search(tester, corpusKeyword);

      expect(find.byType(CoverImage), findsWidgets);
    });

    testWidgets('search_givenASourceThatFails_stillShowsTheOtherHits', (
      WidgetTester tester,
    ) async {
      // 部分失败：命中的照常显示，进度行给出失败数（ADR-0046 §决策 5）。
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient())
        ..failWith(
          'https://broken.test/s?q=%E5%89%91%E6%9D%A5&p=1',
          ParseFailureKind.networkFailed,
        );
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: loadCorpusBookSource())
        ..add(
          source: loadCorpusBookSource().copyWith(
            name: '坏源',
            url: 'https://broken.test',
            searchUrl: 'https://broken.test/s?q={{key}}&p={{page}}',
          ),
        );

      await pumpSearchPage(tester, repository: repository, http: http);
      await _search(tester, corpusKeyword);
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text('书名一'), findsOneWidget);
      expect(find.textContaining(l10n.searchPartialFailed(1)), findsWidgets);
    });

    testWidgets('search_givenASourceThatThrows_stillShowsTheOtherHits', (
      WidgetTester tester,
    ) async {
      // 一个源把异常抛出请求层时，结果区不能被失败页盖掉：已经拿到的命中是用户的
      // 真实所得，只剩“有几个源失败”这一行提示（ADR-0046 §决策 5）。
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient())
        ..throwOn(
          'https://broken.test/s?q=%E5%89%91%E6%9D%A5&p=1',
          const FormatException('broken source'),
        );
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: loadCorpusBookSource())
        ..add(
          source: loadCorpusBookSource().copyWith(
            name: '坏源',
            url: 'https://broken.test',
            searchUrl: 'https://broken.test/s?q={{key}}&p={{page}}',
          ),
        );

      await pumpSearchPage(tester, repository: repository, http: http);
      await _search(tester, corpusKeyword);
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text('书名一'), findsOneWidget);
      expect(find.text(l10n.failureParseFailed), findsNothing);
      expect(find.textContaining(l10n.searchPartialFailed(1)), findsWidgets);
    });

    testWidgets('search_whenWhileRunning_offersPauseAndStop', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient())
        ..onRequest = () => gate.future;

      await pumpSearchPage(
        tester,
        repository: FakeBookSourceRepository()
          ..add(source: loadCorpusBookSource()),
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.enterText(find.byType(TextField), corpusKeyword);
      await tester.tap(find.byTooltip(l10n.bookSourceSearchAction));
      await tester.pump();

      expect(find.text(l10n.searchPause), findsOneWidget);
      expect(find.text(l10n.searchStop), findsOneWidget);

      await tester.tap(find.text(l10n.searchPause));
      await tester.pump();
      expect(find.text(l10n.searchResume), findsOneWidget);

      await tester.tap(find.text(l10n.searchStop));
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('search_givenAHit_opensTheDetailPageOfTheHit', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpReaderApp(
        tester,
        source: loadCorpusBookSource(),
        http: http,
        repository: FakeBookSourceRepository()
          ..add(source: loadCorpusBookSource()),
      );
      await _openSearchTab(tester);
      await _search(tester, corpusKeyword);

      await tester.tap(find.text('书名一'));
      await tester.pumpAndSettle();

      expect(find.byType(BookDetailPage), findsOneWidget);
      // 详情页真的按 G2a 的生产链路请求了书籍页与目录页。
      expect(http.requestedUrls, contains(corpusBookUrl));
    });
  });
}

/// Types [keyword] into the search field and presses the search action.
Future<void> _search(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byType(TextField), keyword);
  await tester.tap(
    // 只点搜索页里的那个按钮：底栏的「搜索」tab 也带同名 tooltip（ADR-0055）。
    find.descendant(
      of: find.byType(SearchBooksPage),
      matching: find.byTooltip(
        localizationOf(
          tester,
          find.byType(SearchBooksPage),
        ).bookSourceSearchAction,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The strings the search page renders, taken from its own localization.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(SearchBooksPage));

/// Switches the shell to the search tab (the shell opens on the shelf, ADR-0055).
Future<void> _openSearchTab(WidgetTester tester) async {
  final AppLocalizations l10n = AppLocalizations.of(
    tester.element(find.byType(AppShell)),
  );
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(l10n.shellTabSearch),
    ),
  );
  await tester.pumpAndSettle();
}
