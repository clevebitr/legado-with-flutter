import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_paged_flow.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/reader_page_table_fixture.dart';

/// The chapters every case works with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/2.html'),
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

/// A flow a case can rebuild with a different page table.
class _Harness {
  _Harness(this.table, {this.anchorIndex = 0});

  /// The pages the flow renders.
  ReaderPageTable table;

  /// The chapter the session is on, which is where the flow opens.
  final int anchorIndex;

  /// What the flow reported as the position under the viewport.
  final List<({int chapterIndex, int charOffset})> progress =
      <({int chapterIndex, int charOffset})>[];

  /// The chapters the flow asked a body for.
  final List<int> requests = <int>[];

  /// The jump the flow is given; the nonce never changes, so a rebuild is not a new jump.
  ReaderFlowRestore get restore =>
      (chapterIndex: anchorIndex, charOffset: 0, nonce: 1);

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
          body: ReaderPagedFlow(
            table: table,
            restore: restore,
            highlight: null,
            style: testReaderBodyStyle,
            highlightStyle: _highlightStyle,
            titleStyle: testReaderTitleStyle,
            padding: _padding,
            onProgress: (int chapterIndex, int charOffset) => progress.add((
              chapterIndex: chapterIndex,
              charOffset: charOffset,
            )),
            onSettled: (int chapterIndex, int charOffset) {},
            onNeedChapter: (int index, {bool explicit = false}) =>
                requests.add(index),
          ),
        ),
      ),
    );
    await _advance(tester);
  }
}

/// Turns one page forward.
Future<void> _turnPage(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-400, 0));
  await _advance(tester);
}

/// The chapter of the last position the flow reported.
int? _reported(_Harness harness) =>
    harness.progress.isEmpty ? null : harness.progress.last.chapterIndex;

void main() {
  group('ReaderPagedFlow', () {
    testWidgets('build_givenOneShortChapter_showsItsFirstPage', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: '第一章正文'},
        ),
      );

      await harness.pump(tester);

      expect(find.textContaining('第一章正文'), findsOneWidget);
      // 第二章没有正文但存在：它那一页已经排上，并主动要正文。
      expect(harness.requests, contains(1));
    });

    testWidgets('build_givenAChapterBody_printsItsHeadingOnTheFirstPage', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: testReaderBody('第一章')},
        ),
      );

      await harness.pump(tester);

      // 分页模式的真实页也要有章头，否则翻过去就不知道这是哪一章（ADR-0087 §决策 3）。
      expect(find.text('第1章'), findsOneWidget);

      await _turnPage(tester);

      // 章头的后续页不再重复标题：同一章只印一次。
      expect(find.text('第1章'), findsNothing);
    });

    testWidgets('turn_givenTheNextChapterInHand_landsOnItsFirstPage', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: '第一章正文', 1: _body('第二章')},
        ),
      );

      await harness.pump(tester);
      await _turnPage(tester);

      // 越过章界是连续翻页：会话进入第二章，章头就在这一页上。
      expect(_reported(harness), 1);
      expect(find.textContaining('第二章 第1行'), findsOneWidget);
      expect(find.text('第2章'), findsOneWidget);
    });

    testWidgets('turn_givenTheNextBodyMissing_showsItsTitleAndLoading', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: '第一章正文'},
        ),
      );

      await harness.pump(tester);
      await _turnPage(tester);

      // 占位页带着这一章的标题：读者知道在等哪一章（ADR-0087 §决策 3）。
      expect(find.text('第2章'), findsOneWidget);
      expect(find.byType(ReaderChapterPendingStrip), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
    });

    testWidgets('build_givenThePlaceholderBodyArrives_replacesItInPlace', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: '第一章正文'},
        ),
      );

      await harness.pump(tester);
      await _turnPage(tester);
      expect(find.byType(ReaderChapterPendingStrip), findsOneWidget);

      // 正文到手：占位页原地变成第二章的第一页，不跳页、不需要再翻一次。
      harness.table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: '第一章正文', 1: '第二章正文'},
      );
      await harness.pump(tester);

      expect(find.byType(ReaderChapterPendingStrip), findsNothing);
      expect(find.textContaining('第二章正文'), findsOneWidget);
      expect(_reported(harness), 1);
    });

    testWidgets('build_givenThePreviousChapterInHand_turnsBackIntoTail', (
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
        anchorIndex: 1,
      );

      await harness.pump(tester);
      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await _advance(tester);

      // 向上翻同样跨章：回到第一章的尾部，而不是停在第二章第一页。
      expect(_reported(harness), 0);
    });

    testWidgets('build_givenTheLastChapter_showsTheEndPage', (
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
      await _turnPage(tester);

      expect(find.text('This is the last chapter'), findsOneWidget);
      expect(find.byType(ReaderChapterPendingStrip), findsNothing);
    });

    testWidgets('update_whenABodyAboveArrives_keepsTheReadersPage', (
      WidgetTester tester,
    ) async {
      // 第一章的正文还没到、读者已经在第二章的某一页上：上一章变长时不能把页码带偏。
      final _Harness harness = _Harness(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{1: _body('第二章')},
          anchorIndex: 1,
        ),
        anchorIndex: 1,
      );

      await harness.pump(tester);
      await _turnPage(tester);
      final int reported = _reported(harness) ?? -1;
      final double before = tester.getTopLeft(find.textContaining('第二章 第')).dy;

      harness.table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: testReaderBody('第一章'), 1: _body('第二章')},
        anchorIndex: 1,
      );
      await harness.pump(tester);

      // 同一页仍然在眼前：页表变了，读者脚下的这一页没有变。
      expect(_reported(harness), reported);
      expect(
        tester.getTopLeft(find.textContaining('第二章 第')).dy,
        closeTo(before, 1),
      );
    });
  });
}

/// A body of [lines] lines, long enough to need several pages at the size the cases use.
String _body(String label, {int lines = 40}) =>
    testReaderBody(label, lines: lines);
