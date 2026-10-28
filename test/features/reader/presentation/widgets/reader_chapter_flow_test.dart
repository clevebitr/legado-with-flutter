import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The chapters every case works with: three chapters, addresses `…/1.html` and so on.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/2.html'),
  ReadingChapter(title: '第3章', url: 'https://source.test/3.html'),
];

/// Pumps [strip] inside a localized app.
Future<void> _pumpStrip(
  WidgetTester tester,
  ReaderChapterPendingStrip strip,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: strip),
    ),
  );
}

void main() {
  group('ReaderChapterSlots', () {
    test('of_givenOnlyTheAnchorBody_answersTheAnchorAndTheNextSlot', () {
      // 下一章没有正文也占一个槽：它要印标题 + 「正在加载」，而不是凭空消失。
      final List<ReaderFlowChapter> slots = ReaderChapterSlots.of(
        chapters: _chapters,
        anchorIndex: 1,
        bodies: <int, String>{1: '正文二'},
        includePrevious: false,
      );

      expect(slots.map((ReaderFlowChapter slot) => slot.index), <int>[1, 2]);
      expect(slots.first.text, '正文二');
      expect(slots.last.text, isNull);
      expect(slots.last.title, '第3章');
    });

    test('of_givenIncludePrevious_startsWithTheNeighbour', () {
      final List<ReaderFlowChapter> slots = ReaderChapterSlots.of(
        chapters: _chapters,
        anchorIndex: 1,
        bodies: <int, String>{0: '正文一', 1: '正文二', 2: '正文三'},
        includePrevious: true,
      );

      expect(
        slots.map((ReaderFlowChapter slot) => slot.index),
        <int>[0, 1, 2],
      );
    });

    test('of_givenTheFirstChapter_hasNoPreviousSlot', () {
      final List<ReaderFlowChapter> slots = ReaderChapterSlots.of(
        chapters: _chapters,
        anchorIndex: 0,
        bodies: <int, String>{0: '正文一'},
        includePrevious: true,
      );

      expect(slots.map((ReaderFlowChapter slot) => slot.index), <int>[0, 1]);
    });

    test('of_givenTheLastChapter_hasNoNextSlot', () {
      final List<ReaderFlowChapter> slots = ReaderChapterSlots.of(
        chapters: _chapters,
        anchorIndex: 2,
        bodies: <int, String>{2: '正文三'},
        includePrevious: false,
      );

      expect(slots.map((ReaderFlowChapter slot) => slot.index), <int>[2]);
    });

    test('of_givenTwoChaptersWithTheSameUrl_keepsOneSlotPerChapter', () {
      // 抓下来的目录里两章指向同一个地址是常见形状：按 URL 归并会把它们压成一份正文，
      // 看起来就是同一章打印了两遍（ADR-0087 §决策 1）。
      final List<ReaderFlowChapter> slots = ReaderChapterSlots.of(
        chapters: const <ReadingChapter>[
          ReadingChapter(title: '第1章', url: 'https://source.test/same.html'),
          ReadingChapter(title: '第2章', url: 'https://source.test/same.html'),
        ],
        anchorIndex: 0,
        bodies: <int, String>{0: '正文一', 1: '正文一'},
        includePrevious: false,
      );

      expect(slots.map((ReaderFlowChapter slot) => slot.index), <int>[0, 1]);
      expect(slots.map((ReaderFlowChapter slot) => slot.title), <String>[
        '第1章',
        '第2章',
      ]);
    });

    test('of_givenAnAnchorOutsideTheToc_answersNothing', () {
      expect(
        ReaderChapterSlots.of(
          chapters: _chapters,
          anchorIndex: 5,
          bodies: const <int, String>{},
          includePrevious: true,
        ),
        isEmpty,
      );
    });
  });

  group('ReaderChapterPendingStrip', () {
    testWidgets('build_givenAReadInFlight_showsTheLoadingLabel', (
      WidgetTester tester,
    ) async {
      await _pumpStrip(
        tester,
        ReaderChapterPendingStrip(isFailed: false, onRetry: () {}),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('build_givenAFailedRead_offersTheRetry', (
      WidgetTester tester,
    ) async {
      var retried = 0;
      await _pumpStrip(
        tester,
        ReaderChapterPendingStrip(
          isFailed: true,
          onRetry: () => retried++,
        ),
      );

      // 读失败的章不能一直画成「还在加载」。
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Reload this chapter'));
      expect(retried, 1);
    });
  });
}
