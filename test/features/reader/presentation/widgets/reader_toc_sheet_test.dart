import 'package:flutter/material.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_toc_sheet.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Three chapters, one of them the current one.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章 开端', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章 继续', url: 'https://source.test/2.html'),
  ReadingChapter(title: '第3章 结束', url: 'https://source.test/3.html'),
];

/// Pumps the sheet and answers the indices the user picked.
Future<List<int>> _pump(
  WidgetTester tester, {
  int currentIndex = 1,
  String? query,
}) async {
  final List<int> picked = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildReaderTheme(fallbackLightColorScheme()),
      home: Scaffold(
        body: ReaderTocSheet(
          chapters: _chapters,
          currentIndex: currentIndex,
          onSelected: picked.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (query != null) {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  return picked;
}

void main() {
  group('ReaderTocSheet', () {
    testWidgets('build_givenACurrentChapter_marksItSelected', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final ListTile row = tester.widget<ListTile>(
        find.widgetWithText(ListTile, '第2章 继续'),
      );
      expect(row.selected, isTrue);
    });

    testWidgets('build_givenAQuery_keepsOnlyMatchingChapters', (
      WidgetTester tester,
    ) async {
      await _pump(tester, query: '结束');

      expect(find.text('第3章 结束'), findsOneWidget);
      expect(find.text('第1章 开端'), findsNothing);
    });

    testWidgets('build_givenNoMatch_showsTheEmptyMessage', (
      WidgetTester tester,
    ) async {
      await _pump(tester, query: '不存在的章节');

      expect(
        find.text(
          AppLocalizations.of(tester.element(find.byType(ReaderTocSheet)))
              .bookSourceListNoMatch,
        ),
        findsOneWidget,
      );
    });

    testWidgets('tap_givenAChapter_answersItsOriginalIndex', (
      WidgetTester tester,
    ) async {
      // 倒序是**视图**（ADR-0051 §决策 2）：点第三行仍然回到第 3 章，不是“倒序后的第 1 行”。
      final List<int> picked = await _pump(tester);
      await tester.tap(find.byIcon(Icons.sort_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, '第3章 结束'));

      expect(picked, <int>[2]);
    });

    testWidgets('build_givenReversed_showsTheLastChapterFirst', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byIcon(Icons.sort_outlined));
      await tester.pumpAndSettle();

      final double first = tester
          .getTopLeft(find.widgetWithText(ListTile, '第3章 结束'))
          .dy;
      final double last = tester
          .getTopLeft(find.widgetWithText(ListTile, '第1章 开端'))
          .dy;
      expect(first, lessThan(last));
    });
  });
}
