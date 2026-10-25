import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/book_search.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/usecases/search_in_book.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_search_sheet.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_reader_ports.dart';

const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '剑来',
  tocUrl: 'https://source.test/book/1/toc',
);

const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/book/1/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/book/1/2.html'),
];

/// Pumps the sheet over [content] and answers the hits the user picked.
Future<List<BookSearchHit>> _pump(
  WidgetTester tester,
  FakeChapterContentProvider content, {
  int fromIndex = 0,
  List<ReadingChapter> chapters = _chapters,
}) async {
  final List<BookSearchHit> picked = <BookSearchHit>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        searchInBookProvider.overrideWith(
          (Ref ref) => SearchInBook(content: content),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: Scaffold(
          body: ReaderSearchSheet(
            book: _book,
            chapters: chapters,
            fromIndex: fromIndex,
            onSelected: picked.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return picked;
}

/// The sheet's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ReaderSearchSheet)));

/// Types [keyword] and submits it.
Future<void> _search(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byType(TextField), keyword);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  group('ReaderSearchSheet', () {
    testWidgets('build_givenNoRun_showsThePrompt', (WidgetTester tester) async {
      await _pump(tester, FakeChapterContentProvider());

      expect(find.text(_l10n(tester).readerSearchHint), findsWidgets);
    });

    testWidgets('search_givenMatches_listsTheHits', (
      WidgetTester tester,
    ) async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来开始了'
        ..bodies['https://source.test/book/1/2.html'] = '没有关键词';

      await _pump(tester, content);
      await _search(tester, '剑来');

      expect(find.text('第1章'), findsOneWidget);
      expect(find.textContaining('剑来开始了'), findsOneWidget);
      // 进度行报「搜到哪了」：搜完是 2/2。
      expect(
        find.text(_l10n(tester).readerSearchProgress(2, 2)),
        findsOneWidget,
      );
    });

    testWidgets('search_givenNoMatch_saysSo', (WidgetTester tester) async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '别的内容';

      await _pump(tester, content);
      await _search(tester, '剑来');

      expect(find.text(_l10n(tester).readerSearchEmpty), findsOneWidget);
    });

    testWidgets('tap_whenAHitIsChosen_reportsItWithItsOffset', (
      WidgetTester tester,
    ) async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/2.html'] = '前文 剑来 后文';

      final List<BookSearchHit> picked = await _pump(tester, content);
      await _search(tester, '剑来');

      await tester.tap(find.text('第2章'));
      await tester.pumpAndSettle();

      expect(picked.single.chapterIndex, 1);
      expect(picked.single.offsetInText, 3);
      expect(picked.single.chapterUrl, 'https://source.test/book/1/2.html');
    });

    testWidgets('search_givenFromTheMiddleChapter_startsThere', (
      WidgetTester tester,
    ) async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来'
        ..bodies['https://source.test/book/1/2.html'] = '剑来';

      await _pump(tester, content, fromIndex: 1);
      await _search(tester, '剑来');

      // 从当前章往后搜：第一章不发请求（ADR-0070 §决策 2）。
      expect(content.requests, <String>['https://source.test/book/1/2.html']);
    });

    testWidgets('search_givenAFailingChapter_warnsAboutIt', (
      WidgetTester tester,
    ) async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来'
        ..failures['https://source.test/book/1/2.html'] =
            ParseFailureKind.networkTimeout;

      await _pump(tester, content);
      await _search(tester, '剑来');

      expect(
        find.text(_l10n(tester).readerSearchFailedChapters(1)),
        findsOneWidget,
      );
    });

    testWidgets('search_givenAnUntitledChapter_fallsBackToTheCaption', (
      WidgetTester tester,
    ) async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来';

      await _pump(
        tester,
        content,
        chapters: const <ReadingChapter>[
          ReadingChapter(title: '', url: 'https://source.test/book/1/1.html'),
        ],
      );
      await _search(tester, '剑来');

      expect(
        find.text(_l10n(tester).readerSearchUntitledChapter),
        findsOneWidget,
      );
    });
  });
}
