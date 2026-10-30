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
  List<ReadingChapter> chapters = _chapters,
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
          chapters: chapters,
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

  group('ReaderTocSheet volumes', () {
    /// One volume heading followed by two chapters, then a second volume heading.
    const List<ReadingChapter> volumes = <ReadingChapter>[
      ReadingChapter(
        title: '第一卷 少年',
        url: 'https://source.test/v1.html',
        isVolume: true,
      ),
      ReadingChapter(title: '第1章 开端', url: 'https://source.test/1.html'),
      ReadingChapter(title: '第2章 继续', url: 'https://source.test/2.html'),
      ReadingChapter(
        title: '第二卷 江湖',
        url: 'https://source.test/v2.html',
        isVolume: true,
      ),
      ReadingChapter(title: '第3章 结束', url: 'https://source.test/3.html'),
    ];

    testWidgets('build_givenVolumeHeadings_groupsTheChaptersUnderThem', (
      WidgetTester tester,
    ) async {
      // ADR-0095：卷标题是组头，与章节同列出现，且点击**不**跳转。
      final List<int> picked = await _pump(
        tester,
        chapters: volumes,
        currentIndex: 1,
      );

      expect(find.text('第一卷 少年'), findsOneWidget);
      expect(find.text('第二卷 江湖'), findsOneWidget);

      await tester.tap(find.text('第一卷 少年'));
      await tester.pumpAndSettle();

      expect(picked, isEmpty);
    });

    testWidgets('volume_whenCollapsed_hidesItsChaptersUntilTheNextHeading', (
      WidgetTester tester,
    ) async {
      await _pump(tester, chapters: volumes, currentIndex: 1);

      await tester.tap(find.text('第一卷 少年'));
      await tester.pumpAndSettle();

      // 卷内两章隐藏；下一卷的章节仍然在（折叠只作用于自己的区间）。
      expect(find.text('第1章 开端'), findsNothing);
      expect(find.text('第2章 继续'), findsNothing);
      expect(find.text('第3章 结束'), findsOneWidget);
      expect(find.text('第一卷 少年'), findsOneWidget);
    });

    testWidgets('volume_whenCollapsedAndSearching_showsTheHits', (
      WidgetTester tester,
    ) async {
      // 搜索忽略折叠：命中项必须看得见（ADR-0095 §决策 2）。
      await _pump(tester, chapters: volumes, currentIndex: 1);
      await tester.tap(find.text('第一卷 少年'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '开端');
      await tester.pumpAndSettle();

      expect(find.text('第1章 开端'), findsOneWidget);
    });
  });
}
