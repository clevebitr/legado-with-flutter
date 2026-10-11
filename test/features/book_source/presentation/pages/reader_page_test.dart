import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/reader_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/offline_corpus.dart';

/// The first chapter of the corpus book.
const Chapter _chapter = Chapter(name: '第1章 开端', url: corpusChapterUrl);

void main() {
  group('ReaderPage', () {
    testWidgets('build_givenNoBookSource_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await pumpBookSourcePage(
        tester,
        page: const ReaderPage(chapter: _chapter),
        source: null,
        http: FakeHttpClient(),
      );

      expect(
        find.text(
          localizationOf(
            tester,
            find.byType(ReaderPage),
          ).bookSourceMissingSource,
        ),
        findsOneWidget,
      );
    });

    testWidgets('build_givenTheCorpusChapter_showsTheText', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpBookSourcePage(
        tester,
        page: const ReaderPage(chapter: _chapter),
        source: loadCorpusBookSource(),
        http: http,
      );

      expect(find.text('第1章 开端'), findsOneWidget);
      expect(find.text('正文第一段。\n正文第二段。\n正文第三段。'), findsOneWidget);
      expect(http.requestedUrls, <String>[corpusChapterUrl]);
    });

    testWidgets('build_givenAChapterWithoutName_usesTheGenericTitle', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpBookSourcePage(
        tester,
        page: const ReaderPage(
          chapter: Chapter(name: '', url: corpusChapterUrl),
        ),
        source: loadCorpusBookSource(),
        http: http,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(ReaderPage),
      );

      // `chapterName` 规则没匹配到时名字是空串（F4）：标题必须回退到 ARB 文案。
      expect(find.text(l10n.bookSourceReaderTitle), findsOneWidget);
    });

    testWidgets('build_givenACollaboratorThatThrows_showsTheGenericFailure', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient())
        ..throwOn(corpusChapterUrl, Exception('broken collaborator'));

      await pumpBookSourcePage(
        tester,
        page: const ReaderPage(chapter: _chapter),
        source: loadCorpusBookSource(),
        http: http,
      );

      final AppLocalizations l10n = localizationOf(
        tester,
        find.byType(ReaderPage),
      );

      expect(find.text(l10n.failureParseFailed), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsOneWidget);
    });
  });
}
