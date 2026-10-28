import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_scroll_flow.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The chapters every case works with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/2.html'),
];

/// A body of [lines] lines, long enough to scroll at the size the cases use.
String _body(String label, {int lines = 40}) => <String>[
  for (var index = 0; index < lines; index++) '$label 第${index + 1}行：正文内容。',
].join('\n');

/// The style every case renders with.
const TextStyle _style = TextStyle(fontSize: 16, height: 1.5);

/// The style of the sentence being read aloud.
const TextStyle _highlightStyle = TextStyle(backgroundColor: Color(0xFF00FF00));

/// Advances a few frames instead of settling.
///
/// A loading slot shows an indeterminate [CircularProgressIndicator], which animates forever:
/// `pumpAndSettle` would never return while one is on screen.
Future<void> _advance(WidgetTester tester, {int frames = 5}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// What one case observed from the flow.
final class _Probe {
  final List<({int index, int charOffset})> progress =
      <({int index, int charOffset})>[];
  final List<({int index, int charOffset})> settled =
      <({int index, int charOffset})>[];
  final List<int> requested = <int>[];

  /// The chapters the flow reported as the top of the viewport.
  Set<int> get reportedChapters => <int>{
    for (final ({int index, int charOffset}) entry in progress) entry.index,
  };
}

/// Pumps one scroll flow and returns what it reported.
Future<_Probe> _pumpFlow(
  WidgetTester tester, {
  required Map<int, String> bodies,
  int anchorIndex = 0,
  Set<int> failed = const <int>{},
  ReaderFlowRestore? restore,
  ReaderFlowHighlight? highlight,
  List<ReadingChapter> chapters = _chapters,
}) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final _Probe probe = _Probe();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReaderScrollFlow(
          chapters: chapters,
          anchorIndex: anchorIndex,
          bodies: bodies,
          failed: failed,
          restore: restore,
          highlight: highlight,
          style: _style,
          highlightStyle: _highlightStyle,
          padding: 16,
          onProgress: (int index, int charOffset) =>
              probe.progress.add((index: index, charOffset: charOffset)),
          onSettled: (int index, int charOffset) =>
              probe.settled.add((index: index, charOffset: charOffset)),
          onNeedChapter: probe.requested.add,
        ),
      ),
    ),
  );
  await _advance(tester);

  return probe;
}

/// Drags the flow by [dy] and lets it settle.
Future<void> _scrollBy(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(ReaderScrollFlow), Offset(0, dy));
  await _advance(tester);
}

void main() {
  group('ReaderScrollFlow', () {
    testWidgets('build_givenTheNextChapterInHand_printsEachChapterOnce', (
      WidgetTester tester,
    ) async {
      await _pumpFlow(
        tester,
        bodies: <int, String>{
          0: _body('第一章'),
          1: _body('第二章'),
        },
      );

      // 章标题印在正文之前（ADR-0086 §决策 7）；每章只出现一次。
      expect(find.text('第1章'), findsOneWidget);
      expect(find.text('第2章'), findsOneWidget);
      expect(find.textContaining('第一章 第1行'), findsOneWidget);
      expect(find.textContaining('第二章 第1行'), findsOneWidget);
      expect(find.byType(ReaderChapterPendingStrip), findsNothing);
    });

    testWidgets('build_givenTwoChaptersSharingAUrl_printsBothOnce', (
      WidgetTester tester,
    ) async {
      // 同一个 URL 的两章各自成段：正文按章节下标传进来，不再按 URL 归并。
      await _pumpFlow(
        tester,
        chapters: const <ReadingChapter>[
          ReadingChapter(title: '第1章', url: 'https://source.test/same.html'),
          ReadingChapter(title: '第2章', url: 'https://source.test/same.html'),
        ],
        bodies: <int, String>{0: '同一份正文', 1: '同一份正文'},
      );

      expect(find.text('第1章'), findsOneWidget);
      expect(find.text('第2章'), findsOneWidget);
      // 两段，各自一份正文（不是一段里出现两次）。
      expect(find.text('同一份正文'), findsNWidgets(2));
    });

    testWidgets('build_givenTheNextBodyMissing_printsItsTitleAndALoadingBlock', (
      WidgetTester tester,
    ) async {
      final _Probe probe = await _pumpFlow(
        tester,
        bodies: <int, String>{0: _body('第一章')},
      );

      // 下一章还没到：标题先出来，正文位置是「正在加载」，并且流程自己去要这一章。
      expect(find.text('第2章'), findsOneWidget);
      expect(find.byType(ReaderChapterPendingStrip), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
      expect(probe.requested, contains(1));
    });

    testWidgets('build_givenTheAnchorBodyMissing_printsItsTitleAndLoading', (
      WidgetTester tester,
    ) async {
      // 刚打开就还没有正文：同样先给标题 + 正在加载，页面不再另画一个转圈。
      await _pumpFlow(tester, bodies: const <int, String>{});

      expect(find.text('第1章'), findsOneWidget);
      expect(find.byType(ReaderChapterPendingStrip), findsWidgets);
      expect(find.text('Loading…'), findsWidgets);
    });

    testWidgets('build_givenAFailedNextChapter_offersTheRetry', (
      WidgetTester tester,
    ) async {
      final _Probe probe = await _pumpFlow(
        tester,
        bodies: <int, String>{0: '第一章正文'},
        failed: <int>{1},
      );

      await tester.tap(find.text('Reload this chapter'));
      await _advance(tester);

      // 读失败的章给的是重试，不是永远转圈；点一次就再问一次。
      expect(probe.requested.where((int index) => index == 1), hasLength(2));
    });

    testWidgets('scroll_givenTheNextChapterInHand_continuesIntoIt', (
      WidgetTester tester,
    ) async {
      final _Probe probe = await _pumpFlow(
        tester,
        bodies: <int, String>{
          0: _body('第一章'),
          1: _body('第二章'),
        },
      );

      await _scrollBy(tester, -6000);

      // 滑到后面，视口顶已经落在第二章：会话跟着换章，中间没有「加载中」。
      expect(probe.reportedChapters, contains(1));
    });

    testWidgets('scroll_givenThePreviousChapterInHand_goesBackIntoItsTail', (
      WidgetTester tester,
    ) async {
      final _Probe probe = await _pumpFlow(
        tester,
        anchorIndex: 1,
        bodies: <int, String>{
          0: _body('第一章'),
          1: _body('第二章'),
        },
        // 从第二章开头读起，向上滑就该回到第一章的尾巴。
        restore: (index: 1, charOffset: 0, nonce: 1),
      );

      expect(probe.reportedChapters, contains(1));
      await _scrollBy(tester, 6000);

      expect(probe.reportedChapters, contains(0));
    });

    testWidgets('build_givenAnExplicitRestore_landsOnThatPosition', (
      WidgetTester tester,
    ) async {
      final _Probe probe = await _pumpFlow(
        tester,
        bodies: <int, String>{
          0: _body('第一章'),
          1: _body('第二章'),
        },
        restore: (index: 1, charOffset: 10, nonce: 1),
      );

      // 显式跳转落在第二章，而不是停在窗口第一段的第一章开头。
      expect(probe.progress.first.index, 1);
      expect(probe.progress.first.charOffset, greaterThan(0));
    });

    testWidgets('build_givenTheLastChapterInHand_showsTheEndOfTheBook', (
      WidgetTester tester,
    ) async {
      await _pumpFlow(
        tester,
        bodies: <int, String>{0: '第一章正文'},
        chapters: const <ReadingChapter>[
          ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
        ],
      );

      expect(find.text('This is the last chapter'), findsOneWidget);
    });

    testWidgets('build_givenTheSpokenSentence_paintsThatRangeOnly', (
      WidgetTester tester,
    ) async {
      await _pumpFlow(
        tester,
        bodies: <int, String>{
          0: _body('第一章'),
          1: _body('第二章'),
        },
        highlight: (url: 'https://source.test/2.html', start: 0, end: 2),
      );

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
