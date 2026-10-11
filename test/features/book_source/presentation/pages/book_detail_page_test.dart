import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_detail_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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

    testWidgets('build_givenAFailingChapterList_keepsTheInformationVisible', (
      WidgetTester tester,
    ) async {
      final BookSource source = loadCorpusBookSource();
      final BookSource unsupportedToc = source.copyWith(
        tocRule: source.tocRule.copyWith(chapterList: '@js:result'),
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
  });
}
