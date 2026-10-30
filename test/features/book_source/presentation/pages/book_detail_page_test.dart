import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_detail_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_navigation.dart';
import '../../../../support/fake_bookshelf_writer.dart';
import '../../../../support/fake_content_cache.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/offline_corpus.dart';

/// The hit the corpus search page returns first.
const Book _book = Book(name: '书名一', url: corpusBookUrl);

void main() {
  group('BookDetailPage', () {
    testWidgets('build_givenNoBookSource_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: null,
        http: FakeHttpClient(),
      );

      expect(
        find.text(
          localizationOf(
            tester,
            find.byType(BookDetailPage),
          ).bookSourceMissingSource,
        ),
        findsOneWidget,
      );
    });

    testWidgets('build_givenTheCorpusBook_showsTheInformationAndTheChapters', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: http,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      // 详情与目录都按真实规则解析（G2a 的生产链路）。
      expect(find.text(l10n.bookSourceDetailTitle), findsOneWidget);
      expect(find.text(l10n.bookSourceTocTitle), findsOneWidget);
      // 详情页的作者规则带前缀（`book_page.html` 的真实形态），文案由 ARB 组装。
      expect(find.text(l10n.bookSourceAuthorLine('作 者：作者甲')), findsOneWidget);
      expect(find.text('第1章 开端'), findsOneWidget);
      expect(http.requestedUrls, contains(corpusBookUrl));
    });

    testWidgets('build_givenUpdateTimeRules_showsThemOnThePageAndTheChapters', (
      WidgetTester tester,
    ) async {
      // §3.7 的两条展示项之一：详情与目录的 updateTime 都是「规则给就显示」的字符串
      // （`book-source.md` §2，不做日期解析）。这里用一份最小派生源，让两条规则分别命中
      // 详情页与目录页上的日期。
      final BookSource source = loadCorpusBookSource().copyWith(
        bookInfoRule: const BookInfoRule(
          name: 'class.name@text',
          author: 'class.author@text',
          updateTime: 'class.date@text',
          tocUrl: 'class.toc@href',
        ),
        tocRule: const TocRule(
          chapterList: 'class.chapter',
          chapterName: 'tag.a@text',
          chapterUrl: 'tag.a.0@href',
          updateTime: 'class.date@text',
        ),
      );
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          corpusBookUrl,
          '<h1 class="name">书名一</h1>'
          '<span class="author">作者甲</span>'
          '<span class="date">2026-10-21</span>'
          '<a class="toc" href="/book/1/toc.html">目录</a>',
        )
        ..serve(
          'https://example-novel.test/book/1/toc.html',
          '<div class="chapter"><a href="/book/1/1.html">第1章 开端</a>'
              '<span class="date">2026-10-20</span></div>',
        );

      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: source,
        http: http,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      // 详情页自己的一行 + 目录项的一行，两处都来自 ARB 的同一句话。
      expect(
        find.text(l10n.bookSourceUpdateTimeLine('2026-10-21')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.bookSourceUpdateTimeLine('2026-10-20')),
        findsOneWidget,
      );
    });

    testWidgets('build_givenAReadableBook_showsTheCoverAndStartsAtChapterOne', (
      WidgetTester tester,
    ) async {
      // S1/S6（roadmap §3.9）：详情页要显示封面，并给出「开始阅读」的入口 —— 以前只能点
      // 某一个目录项才进得去阅读器。
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());
      final FakeAppNavigation navigation = FakeAppNavigation();

      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: http,
        navigation: navigation,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      expect(find.byType(CoverImage), findsOneWidget);
      expect(find.text(l10n.bookSourceStartReading), findsOneWidget);

      await tester.tap(find.text(l10n.bookSourceStartReading));
      await tester.pump();

      // 「开始阅读」= 第一章；「继续阅读」= 不带章节（由阅读器恢复进度）。
      expect(navigation.readerCalls.single.chapterUrl, isNotNull);
      expect(navigation.readerCalls.single.bookName, isNotEmpty);
    });

    testWidgets('build_givenTheContinueAction_resumesWithoutAChapter', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());
      final FakeAppNavigation navigation = FakeAppNavigation();

      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: http,
        navigation: navigation,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );
      await tester.tap(find.text(l10n.bookSourceContinueReading));
      await tester.pump();

      expect(navigation.readerCalls.single.chapterUrl, isNull);
    });

    testWidgets('build_givenTheReadingRecordsAction_asksTheNavigationPort', (
      WidgetTester tester,
    ) async {
      // M19：详情页只给「这一本书的阅读记录」一个入口，页面归 reader（ADR-0066 §决策 5）。
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());
      final FakeAppNavigation navigation = FakeAppNavigation();

      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: http,
        navigation: navigation,
      );
      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      await tester.tap(find.text(l10n.bookSourceReadingRecords));
      await tester.pump();

      expect(navigation.bookReadingRecordsCalls, hasLength(1));
      expect(navigation.bookReadingRecordsCalls.single.bookUrl, isNotEmpty);
      expect(navigation.readerCalls, isEmpty);
    });

    testWidgets('build_givenAnIntro_collapsesAndExpandsIt', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: http,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      // 默认折三行；点一下展开，按钮文案随之变化（S6）。
      expect(find.text(l10n.bookSourceIntroExpand), findsOneWidget);
      await tester.tap(find.text(l10n.bookSourceIntroExpand));
      await tester.pump();

      expect(find.text(l10n.bookSourceIntroCollapse), findsOneWidget);
    });

    testWidgets('build_givenAFailingChapterList_keepsTheInformationVisible', (
      WidgetTester tester,
    ) async {
      final BookSource source = loadCorpusBookSource();
      final BookSource unsupportedToc = source.copyWith(
        tocRule: source.tocRule.copyWith(chapterList: '@webJs:'),
      );
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: unsupportedToc,
        http: http,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      // 两个阶段独立失败：目录读不出来，详情照常显示，并各自提供重试（§9）。
      expect(find.text(l10n.bookSourceAuthorLine('作 者：作者甲')), findsOneWidget);
      expect(find.text(l10n.failureUnsupportedRule), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsOneWidget);
    });

    testWidgets('build_givenACollaboratorThatThrows_showsTheGenericFailure', (
      WidgetTester tester,
    ) async {
      // 用例按 C-ERR-1 不抛异常；这条测试证明契约被破坏时页面仍给文案而不是白屏。
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient())
        ..throwOn(corpusBookUrl, Exception('broken collaborator'));

      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: http,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      expect(find.text(l10n.failureParseFailed), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsOneWidget);
    });

    testWidgets('build_givenABookThatIsNotOnTheShelf_disablesGroupAndCover', (
      WidgetTester tester,
    ) async {
      // 分组与封面是书架行的属性：不在书架上时按钮置灰，而不是偷偷把书加进去。
      final FakeBookshelfWriter writer = FakeBookshelfWriter();
      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: serveCorpusPages(FakeHttpClient()),
        writer: writer,
      );
      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      final Finder group = find.widgetWithText(
        OutlinedButton,
        l10n.bookSourceShelfGroup,
      );
      final Finder cover = find.widgetWithText(
        OutlinedButton,
        l10n.bookSourceChangeCover,
      );

      expect(tester.widget<OutlinedButton>(group).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(cover).onPressed, isNull);
    });

    testWidgets('group_whenAGroupIsChosen_asksTheShelfPort', (
      WidgetTester tester,
    ) async {
      final FakeBookshelfWriter writer = FakeBookshelfWriter()
        ..membershipValue = const ShelfMembership(
          onShelf: true,
          groups: <ShelfGroupOption>[ShelfGroupOption(id: 7, name: '仙侠')],
        );
      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: serveCorpusPages(FakeHttpClient()),
        writer: writer,
      );
      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, l10n.bookSourceShelfGroup),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('仙侠'));
      await tester.pumpAndSettle();

      expect(writer.assignedGroups, <int?>[7]);
    });

    testWidgets('group_whenUngroupedIsChosen_writesNull', (
      WidgetTester tester,
    ) async {
      final FakeBookshelfWriter writer = FakeBookshelfWriter()
        ..membershipValue = const ShelfMembership(
          onShelf: true,
          groupId: 7,
          groups: <ShelfGroupOption>[ShelfGroupOption(id: 7, name: '仙侠')],
        );
      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: serveCorpusPages(FakeHttpClient()),
        writer: writer,
      );
      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, l10n.bookSourceShelfGroup),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shelfGroupUngrouped));
      await tester.pumpAndSettle();

      expect(writer.assignedGroups, <int?>[null]);
    });

    testWidgets('cover_whenTheButtonIsTapped_asksForAnImage', (
      WidgetTester tester,
    ) async {
      final FakeBookshelfWriter writer = FakeBookshelfWriter()
        ..membershipValue = const ShelfMembership(onShelf: true);
      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: serveCorpusPages(FakeHttpClient()),
        writer: writer,
      );
      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, l10n.bookSourceChangeCover),
      );
      await tester.pumpAndSettle();

      expect(writer.chooseCoverCalls, 1);
      expect(writer.resetCoverCalls, 0);
    });

    testWidgets('cover_whenOneIsAlreadySet_offersTheReset', (
      WidgetTester tester,
    ) async {
      final FakeBookshelfWriter writer = FakeBookshelfWriter()
        ..membershipValue = const ShelfMembership(
          onShelf: true,
          customCoverPath: '/covers/abc.jpg',
        );
      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: serveCorpusPages(FakeHttpClient()),
        writer: writer,
      );
      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      final Finder reset = find.widgetWithText(
        OutlinedButton,
        l10n.bookSourceResetCover,
      );
      expect(reset, findsOneWidget);

      await tester.tap(reset);
      await tester.pumpAndSettle();

      expect(writer.resetCoverCalls, 1);
    });

    testWidgets('cache_givenCachedChapters_clearsThemOnRequest', (
      WidgetTester tester,
    ) async {
      final FakeContentCache cache = FakeContentCache()
        ..entries['https://source.test|https://source.test/1.html'] = '正文'
        ..entries['https://source.test|https://source.test/2.html'] = '正文';
      await pumpBookSourcePage(
        tester,
        page: const BookDetailPage(book: _book),
        source: loadCorpusBookSource(),
        http: serveCorpusPages(FakeHttpClient()),
        contentCache: cache,
      );
      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(BookDetailPage),
      );

      // 按钮文案里带着数量：缓存 2 条 → 打开弹窗后显示 2 章。
      await tester.tap(
        find.widgetWithText(
          OutlinedButton,
          '${l10n.bookSourceBookCache} · '
          '${l10n.bookSourceBookCacheCount(2)}',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.bookSourceBookCacheCount(2)), findsWidgets);

      await tester.tap(find.text(l10n.bookSourceBookCacheClear));
      await tester.pumpAndSettle();

      expect(cache.scopeCalls.last, startsWith('clear|'));
      expect(find.text(l10n.bookSourceBookCacheCleared(2)), findsOneWidget);
    });
  });
}
