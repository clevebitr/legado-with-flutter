import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_scroll_flow.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/reader_page_table_fixture.dart';

/// The chapters every case works with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/2.html'),
  ReadingChapter(title: '第3章', url: 'https://source.test/3.html'),
];

/// The page margin the flows get in these cases.
const double _padding = 16;

/// The style of the sentence being read aloud.
const TextStyle _highlightStyle = TextStyle(backgroundColor: Color(0xFF00FF00));

/// Advances a few frames instead of settling.
///
/// A loading page shows an indeterminate [CircularProgressIndicator], which animates forever:
/// `pumpAndSettle` would never return while one is on screen.
Future<void> _advance(WidgetTester tester, {int frames = 5}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// What one case observed from the flow.
final class _Probe {
  final List<({int chapterIndex, int charOffset})> progress =
      <({int chapterIndex, int charOffset})>[];
  final List<({int chapterIndex, int charOffset})> settled =
      <({int chapterIndex, int charOffset})>[];
  final List<int> requested = <int>[];

  /// The chapters the flow reported as the top of the viewport.
  Set<int> get reportedChapters => <int>{
    for (final ({int chapterIndex, int charOffset}) entry in progress)
      entry.chapterIndex,
  };
}

/// A flow a case can rebuild with a different page table.
class _Harness {
  _Harness(this.table, {this.restore, this.highlight});

  /// The pages the flow renders.
  ReaderPageTable table;

  /// The explicit jump the flow must apply, if any.
  ReaderFlowRestore? restore;

  /// The sentence being read aloud, if any.
  ReaderFlowHighlight? highlight;

  /// What the flow reported.
  final _Probe probe = _Probe();

  /// Pumps the flow with the current [table].
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReaderScrollFlow(
            table: table,
            restore: restore,
            highlight: highlight,
            style: testReaderBodyStyle,
            highlightStyle: _highlightStyle,
            titleStyle: testReaderTitleStyle,
            padding: _padding,
            onProgress: (int chapterIndex, int charOffset) => probe.progress
                .add((chapterIndex: chapterIndex, charOffset: charOffset)),
            onSettled: (int chapterIndex, int charOffset) => probe.settled.add((
              chapterIndex: chapterIndex,
              charOffset: charOffset,
            )),
            onNeedChapter: (int index, {bool explicit = false}) =>
                probe.requested.add(index),
          ),
        ),
      ),
    );
    await _advance(tester);
  }
}

/// The scroll position the flow is showing.
ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

/// Drags the flow by [dy] and lets it settle.
Future<void> _scrollBy(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(ReaderScrollFlow), Offset(0, dy));
  await _advance(tester);
}

void main() {
  group('ReaderScrollFlow', () {
    testWidgets('build_givenTheNextChapterInHand_printsEachHeadingOnce', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          // 短章：两章同屏，才好在不滚动的前提下断言两边的章头。
          bodies: <int, String>{0: '第一章正文', 1: '第二章正文'},
        ),
      );

      await harness.pump(tester);

      // 章头印在章首（ADR-0087 §决策 3）；每章只出现一次。
      expect(find.text('第1章'), findsOneWidget);
      expect(find.text('第2章'), findsOneWidget);
      expect(find.textContaining('第一章正文'), findsOneWidget);
      expect(find.textContaining('第二章正文'), findsOneWidget);
      expect(find.byType(ReaderChapterPendingStrip), findsNothing);
    });

    testWidgets('build_givenTwoChaptersSharingAUrl_printsBothOnce', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: const <ReadingChapter>[
            ReadingChapter(title: '第1章', url: 'https://source.test/same.html'),
            ReadingChapter(title: '第2章', url: 'https://source.test/same.html'),
          ],
          // 同一份地址的正文按章节下标各有一份：页表不会把它们压成一章。
          bodies: <int, String>{0: '同一份正文', 1: '同一份正文'},
        ),
      );

      await harness.pump(tester);

      expect(find.text('第1章'), findsOneWidget);
      expect(find.text('第2章'), findsOneWidget);
      expect(find.text('同一份正文'), findsNWidgets(2));
    });

    testWidgets('build_givenTheAnchorBodyMissing_printsItsHeadingAndLoading', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(chapters: _chapters, bodies: const <int, String>{}),
      );

      await harness.pump(tester);

      // 刚打开就还没有正文：先给章头 + 正在加载，页面不再另画一个转圈。
      expect(find.text('第1章'), findsOneWidget);
      expect(find.byType(ReaderChapterPendingStrip), findsWidgets);
      expect(find.text('Loading…'), findsWidgets);
      expect(harness.probe.requested, contains(0));
    });

    testWidgets('build_givenAFailedNextChapter_offersTheRetry', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: '第一章正文'},
          failed: <int>{1},
        ),
      );

      await harness.pump(tester);
      await tester.tap(find.text('Reload this chapter'));
      await _advance(tester);

      // 读失败的章给的是重试，不是永远转圈；点一次就再问一次。
      expect(
        harness.probe.requested.where((int index) => index == 1),
        hasLength(2),
      );
    });

    testWidgets('scroll_givenTheNextChapterInHand_continuesIntoIt', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{
            0: testReaderBody('第一章'),
            1: testReaderBody('第二章'),
          },
        ),
      );

      await harness.pump(tester);
      await _scrollBy(tester, -6000);

      // 滑到后面，视口顶已经落在第二章：会话跟着换章，中间没有「加载中」。
      expect(harness.probe.reportedChapters, contains(1));
    });

    testWidgets('scroll_givenThePreviousChapterInHand_goesBackIntoItsTail', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{
            0: testReaderBody('第一章'),
            1: testReaderBody('第二章'),
          },
          anchorIndex: 1,
        ),
        // 从第二章开头读起，向上滑就该回到第一章的尾巴。
        restore: (chapterIndex: 1, charOffset: 0, nonce: 1),
      );

      await harness.pump(tester);
      expect(harness.probe.reportedChapters, contains(1));

      await _scrollBy(tester, 6000);

      expect(harness.probe.reportedChapters, contains(0));
    });

    testWidgets('build_givenAnExplicitRestore_landsOnThatPosition', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{
            0: testReaderBody('第一章'),
            1: testReaderBody('第二章'),
          },
          anchorIndex: 1,
        ),
        restore: (chapterIndex: 1, charOffset: 200, nonce: 1),
      );

      await harness.pump(tester);

      // 显式跳转落在第二章的那个偏移，而不是停在窗口第一段的第一章开头。
      expect(harness.probe.progress.first.chapterIndex, 1);
      expect(harness.probe.progress.first.charOffset, greaterThan(0));
    });

    testWidgets('build_givenTheLastChapterInHand_showsTheEndOfTheBook', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: const <ReadingChapter>[
            ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
          ],
          bodies: <int, String>{0: '第一章正文'},
        ),
      );

      await harness.pump(tester);

      expect(find.text('This is the last chapter'), findsOneWidget);
    });

    testWidgets('build_givenTheMeasuredPages_paintsThemAtTheMeasuredHeight', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{
            0: testReaderBody('第一章'),
            1: testReaderBody('第二章'),
          },
        ),
      );

      await harness.pump(tester);

      // 量出来的高度必须与真正排出来的高度一致：否则滚动范围会漂，锚点换算也会跟着漂。
      for (final Element element in find.byType(ReaderPageView).evaluate()) {
        final ReaderPageView view = element.widget as ReaderPageView;
        expect(
          tester.getSize(find.byWidget(view)).height,
          closeTo(view.page.extent, 1),
          reason: 'page ${view.page.id}',
        );
      }
    });

    testWidgets('build_givenAShortLastPage_letsItScrollToTheViewportTop', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: testReaderBody('第一章'), 1: '第二章正文'},
        ),
      );

      await harness.pump(tester);
      _position(tester).jumpTo(_position(tester).maxScrollExtent);
      await _advance(tester);

      // 末页往往不满一屏，没有尾部留白就滚不到视口顶——那时「跳到最后一章」会被滚动范围截住，
      // 锚点落回上一章，会话跟着回退（真机上看到的就是一次回弹）。
      expect(
        _position(tester).maxScrollExtent,
        greaterThanOrEqualTo(harness.table.tops.last + _padding),
      );
      // 末页停在视口顶上：它的顶端与视口顶对齐（页边距已经滚出去了）。
      final ReaderPageView lastPage = tester
          .widgetList<ReaderPageView>(find.byType(ReaderPageView))
          .last;
      expect(lastPage.page.isPlaceholder, isFalse);
      expect(tester.getTopLeft(find.byWidget(lastPage)).dy, closeTo(0, 1));
    });

    testWidgets('update_whenABodyAboveArrives_keepsTheTextUnderTheViewport', (
      WidgetTester tester,
    ) async {
      // 第一章的正文还没到、锚点已经在第二章：这正是「上一章变高」那一类跳动。
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{1: testReaderBody('第二章')},
          anchorIndex: 1,
        ),
        restore: (chapterIndex: 1, charOffset: 0, nonce: 1),
      );

      await harness.pump(tester);
      final Finder firstLine = find.textContaining('第二章 第1行');
      final double before = tester.getTopLeft(firstLine).dy;
      final double offsetBefore = _position(tester).pixels;

      // 第一章的正文到手：它会在锚点上方长出好几页。
      harness.table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{
          0: testReaderBody('第一章'),
          1: testReaderBody('第二章'),
        },
        anchorIndex: 1,
      );
      await harness.pump(tester);

      // 滚动位置必须跟着挪（内容变高了），而读者眼前那行字一动不动。
      expect(_position(tester).pixels, greaterThan(offsetBefore));
      expect(tester.getTopLeft(firstLine).dy, closeTo(before, 1));
    });

    testWidgets('update_whenAChapterJoinsBelow_doesNotMoveTheReader', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: testReaderBody('第一章')},
        ),
      );

      await harness.pump(tester);
      await _scrollBy(tester, -300);
      final Finder line = find.textContaining('第一章 第');
      final double before = tester.getTopLeft(line.first).dy;
      final double offsetBefore = _position(tester).pixels;

      // 跨章：窗口往下扩一章（页面就是这么给表的），锚点上方的页一章也没少。
      harness.table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{
          0: testReaderBody('第一章'),
          1: testReaderBody('第二章'),
        },
        anchorIndex: 1,
      );
      await harness.pump(tester);

      // 滚动位置一点没变，读者眼前那行字也一点没动——跨章不再打断手势（ADR-0087 §决策 2）。
      expect(_position(tester).pixels, closeTo(offsetBefore, 0.5));
      expect(tester.getTopLeft(line.first).dy, closeTo(before, 1));
    });

    testWidgets('build_givenTheSpokenSentence_paintsThatRangeOnly', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: '第一章正文', 1: '第二章正文'},
        ),
        highlight: (url: 'https://source.test/2.html', start: 0, end: 2),
      );

      await harness.pump(tester);

      final Iterable<Text> highlighted = tester
          .widgetList<Text>(find.byType(Text))
          .where((Text text) {
            final InlineSpan? span = text.textSpan;
            if (span is! TextSpan) {
              return false;
            }

            return span.children?.any(
                  (InlineSpan child) => child.style?.backgroundColor != null,
                ) ??
                false;
          });

      // 朗读高亮只画在它自己的章节上：相邻章的正文不应跟着变色。
      expect(highlighted, hasLength(1));
    });
  });
}
