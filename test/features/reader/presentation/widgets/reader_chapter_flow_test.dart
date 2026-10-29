import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/reader_page_table_fixture.dart';

/// The style of the sentence being read aloud.
const TextStyle _highlightStyle = TextStyle(backgroundColor: Color(0xFF00FF00));

/// One page of chapter 0, as the table would hand it over.
ReaderPageEntry _page({
  String title = '',
  String? text = '正文内容',
  int start = 0,
  int? end,
  double titleExtent = 0,
  double bodyExtent = 100,
  bool isFailed = false,
  int chapterIndex = 0,
  int pageIndex = 0,
}) => ReaderPageEntry(
  id: (chapterIndex: chapterIndex, pageIndex: pageIndex),
  url: 'https://source.test/$chapterIndex.html',
  title: title,
  text: text,
  start: start,
  end: end ?? (text?.length ?? 0),
  titleExtent: titleExtent,
  bodyExtent: bodyExtent,
  isFailed: isFailed,
);

/// Pumps one page view and records the retries it asked for.
Future<List<int>> _pumpPage(
  WidgetTester tester,
  ReaderPageEntry page, {
  ReaderFlowHighlight? highlight,
}) async {
  final List<int> retried = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReaderPageView(
          page: page,
          style: testReaderBodyStyle,
          highlightStyle: _highlightStyle,
          titleStyle: testReaderTitleStyle,
          highlight: highlight,
          onNeedChapter: retried.add,
        ),
      ),
    ),
  );
  await tester.pump();

  return retried;
}

/// The text of every painted span that carries a background (the read-aloud highlight).
Iterable<String> _highlightedText() => find
    .byType(Text)
    .evaluate()
    .map((Element element) => element.widget)
    .whereType<Text>()
    .expand((Text text) {
      final InlineSpan? span = text.textSpan;
      if (span is TextSpan) {
        return span.children ?? const <InlineSpan>[];
      }

      return const <InlineSpan>[];
    })
    .whereType<TextSpan>()
    .where((TextSpan span) => span.style?.backgroundColor != null)
    .map((TextSpan span) => span.text ?? '');

void main() {
  group('ReaderPageView', () {
    testWidgets('build_givenAChapterHeading_printsItAboveTheBody', (
      WidgetTester tester,
    ) async {
      await _pumpPage(
        tester,
        _page(title: '第1章 开端', titleExtent: 48, text: '正文内容'),
      );

      // 章头与正文都在，且章头在上（ADR-0087 §决策 3）：这就是「每章只印一次标题」的位置。
      expect(find.text('第1章 开端'), findsOneWidget);
      expect(find.text('正文内容'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('第1章 开端')).dy,
        lessThan(tester.getTopLeft(find.text('正文内容')).dy),
      );
    });

    testWidgets('build_givenAPageWithoutAHeading_printsTheBodyOnly', (
      WidgetTester tester,
    ) async {
      await _pumpPage(tester, _page(text: '第二页正文'));

      expect(find.text('第二页正文'), findsOneWidget);
      expect(find.byType(ReaderChapterPendingStrip), findsNothing);
    });

    testWidgets('build_givenASliceOfTheBody_printsOnlyThatSlice', (
      WidgetTester tester,
    ) async {
      await _pumpPage(tester, _page(text: '0123456789', start: 2, end: 6));

      // 页画的是切片：前后的字属于相邻页，不能在上一页的末尾多印一遍。
      expect(find.text('2345'), findsOneWidget);
      expect(find.textContaining('01'), findsNothing);
      expect(find.textContaining('67'), findsNothing);
    });

    testWidgets('build_givenAPlaceholderPage_printsItsHeadingAndLoading', (
      WidgetTester tester,
    ) async {
      await _pumpPage(
        tester,
        _page(title: '第2章', text: null, titleExtent: 48, bodyExtent: 72),
      );

      expect(find.text('第2章'), findsOneWidget);
      expect(find.byType(ReaderChapterPendingStrip), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
    });

    testWidgets('build_givenAFailedChapter_retriesThatChapter', (
      WidgetTester tester,
    ) async {
      final List<int> retried = await _pumpPage(
        tester,
        _page(
          title: '第2章',
          text: null,
          titleExtent: 48,
          bodyExtent: 72,
          isFailed: true,
          chapterIndex: 2,
        ),
      );

      await tester.tap(find.text('Reload this chapter'));
      await tester.pump();

      // 读失败给的是重试按钮，重试问的是这一章（不是「当前章」）。
      expect(find.text('Loading…'), findsNothing);
      expect(retried, <int>[2]);
    });

    testWidgets('build_givenTheSpokenSentenceOfThisChapter_paintsThatRange', (
      WidgetTester tester,
    ) async {
      await _pumpPage(
        tester,
        _page(text: '一二三四五六'),
        highlight: (url: 'https://source.test/0.html', start: 1, end: 3),
      );

      expect(_highlightedText(), <String>['二三']);

      await _pumpPage(
        tester,
        _page(text: '一二三四五六', end: 6),
        highlight: (url: 'https://source.test/0.html', start: 0, end: 2),
      );

      expect(_highlightedText(), <String>['一二']);
    });

    testWidgets('build_givenTheSpokenSentenceOfAnotherChapter_paintsNothing', (
      WidgetTester tester,
    ) async {
      await _pumpPage(
        tester,
        _page(text: '一二三四五六'),
        highlight: (url: 'https://source.test/9.html', start: 0, end: 2),
      );

      expect(_highlightedText(), isEmpty);
    });

    testWidgets('build_givenAHighlightAcrossTheSlice_clipsIt', (
      WidgetTester tester,
    ) async {
      await _pumpPage(
        tester,
        _page(text: '0123456789', start: 4, end: 8),
        // 引擎里的句子跨页：只画落在这一页上的部分，不跳过也不越界。
        highlight: (url: 'https://source.test/0.html', start: 2, end: 10),
      );

      expect(_highlightedText(), <String>['4567']);
    });
  });

  group('ReaderChapterPendingStrip', () {
    testWidgets('build_givenLoading_showsTheSpinnerNotTheRetry', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReaderChapterPendingStrip(isFailed: false, onRetry: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Reload this chapter'), findsNothing);
    });
  });
}
