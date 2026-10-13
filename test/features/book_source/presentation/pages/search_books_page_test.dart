import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_detail_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/search_books_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/offline_corpus.dart';

void main() {
  group('SearchBooksPage', () {
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

      await pumpBookSourcePage(
        tester,
        page: const SearchBooksPage(),
        source: loadCorpusBookSource(),
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

      await pumpBookSourcePage(
        tester,
        page: const SearchBooksPage(),
        source: loadCorpusBookSource(),
        http: http,
      );
      await _search(tester, corpusKeyword);

      // 命中的是生产链路：模板渲染 + 关键词编码 + 规则引擎都由真实实现完成。
      expect(http.requestedUrls, <String>[corpusSearchUrl]);
      expect(find.text('书名一'), findsOneWidget);
      expect(find.text('作者甲'), findsOneWidget);
      expect(find.text('书名二'), findsOneWidget);
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

      await pumpBookSourcePage(
        tester,
        page: const SearchBooksPage(),
        source: loadCorpusBookSource(),
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
        searchRule: source.searchRule.copyWith(bookList: '@js:result'),
      );
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpBookSourcePage(
        tester,
        page: const SearchBooksPage(),
        source: unsupported,
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

    testWidgets('search_givenAHit_opensTheDetailPageOfTheHit', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpReaderApp(tester, source: loadCorpusBookSource(), http: http);
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
    find.byTooltip(
      localizationOf(
        tester,
        find.byType(SearchBooksPage),
      ).bookSourceSearchAction,
    ),
  );
  await tester.pumpAndSettle();
}
