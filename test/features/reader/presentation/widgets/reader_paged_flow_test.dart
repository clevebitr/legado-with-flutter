import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_paged_flow.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The chapters every case works with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/2.html'),
];

/// A body of [lines] lines, long enough to need several pages at the size the cases use.
String _body(String label, {int lines = 40}) => <String>[
  for (var index = 0; index < lines; index++) '$label 第${index + 1}行：正文内容。',
].join('\n');

/// The style every case renders with.
const TextStyle _style = TextStyle(fontSize: 16, height: 1.5);

/// The style of the sentence being read aloud.
const TextStyle _highlightStyle = TextStyle(backgroundColor: Color(0xFF00FF00));

/// Advances a few frames instead of settling.
///
/// A pending strip shows an indeterminate [CircularProgressIndicator], which animates forever:
/// `pumpAndSettle` would never return while one is on screen.
Future<void> _advance(WidgetTester tester, {int frames = 5}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}


/// A flow the case can rebuild with a different set of bodies.
class _Harness {
  _Harness(this.bodies, {this.anchorIndex = 0, this.chapters = _chapters});

  /// The bodies in hand, keyed by chapter URL.
  final Map<String, String> bodies;

  /// The session's chapter.
  final int anchorIndex;

  /// The whole table of contents.
  final List<ReadingChapter> chapters;

  /// What the flow reported as the position under the viewport.
  final List<({int index, int charOffset})> progress =
      <({int index, int charOffset})>[];

  /// The chapters the flow asked for.
  final List<int> requested = <int>[];

  /// Pumps the flow with the current [bodies].
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
            chapters: chapters,
            anchorIndex: anchorIndex,
            bodies: bodies,
            failed: const <String>{},
            restore: (index: anchorIndex, charOffset: 0, nonce: 1),
            highlight: null,
            style: _style,
            highlightStyle: _highlightStyle,
            padding: 16,
            onProgress: (int index, int charOffset) =>
                progress.add((index: index, charOffset: charOffset)),
            onSettled: (int index, int charOffset) {},
            onNeedChapter: requested.add,
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

void main() {
  group('ReaderPagedFlow', () {
    testWidgets('build_givenOneShortChapter_showsItsFirstPage', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(<String, String>{
        'https://source.test/1.html': '第一章正文',
      });

      await harness.pump(tester);

      expect(find.textContaining('第一章正文'), findsOneWidget);
      // 第二章没有正文但存在：先拿到占位页，而不是「本章读完 + 下一章」。
      expect(harness.requested, contains(1));
    });

    testWidgets('turn_givenTheNextChapterInHand_landsOnItsFirstPage', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(<String, String>{
        'https://source.test/1.html': '第一章正文',
        'https://source.test/2.html': _body('第二章'),
      });

      await harness.pump(tester);
      await _turnPage(tester);

      // 越过章界是连续翻页：会话进入第二章，页面上不再是任何按钮。
      expect(
        harness.progress.map((({int index, int charOffset}) e) => e.index),
        contains(1),
      );
      expect(find.textContaining('第二章 第1行'), findsOneWidget);
      expect(find.text('This is the last chapter'), findsNothing);
    });

    testWidgets('turn_givenTheNextBodyMissing_showsThePlaceholderPage', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(<String, String>{
        'https://source.test/1.html': '第一章正文',
      });

      await harness.pump(tester);
      await _turnPage(tester);

      expect(find.byType(ReaderChapterPendingStrip), findsOneWidget);
      expect(find.text('Loading the neighbouring chapter…'), findsOneWidget);
    });

    testWidgets('build_givenThePlaceholderBodyArrives_replacesItInPlace', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(<String, String>{
        'https://source.test/1.html': '第一章正文',
      });

      await harness.pump(tester);
      await _turnPage(tester);
      expect(find.byType(ReaderChapterPendingStrip), findsOneWidget);

      // 正文到手：占位页原地变成第二章的第一页，不跳页、不需要再翻一次。
      harness.bodies['https://source.test/2.html'] = '第二章正文';
      await harness.pump(tester);

      expect(find.byType(ReaderChapterPendingStrip), findsNothing);
      expect(find.textContaining('第二章正文'), findsOneWidget);
      expect(
        harness.progress.map((({int index, int charOffset}) e) => e.index),
        contains(1),
      );
    });

    testWidgets('build_givenThePreviousChapterInHand_turnsBackIntoTail', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        <String, String>{
          'https://source.test/1.html': _body('第一章'),
          'https://source.test/2.html': _body('第二章'),
        },
        anchorIndex: 1,
      );

      await harness.pump(tester);
      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await _advance(tester);

      // 向上翻同样跨章：回到第一章的尾部，而不是停在第二章第一页。
      expect(
        harness.progress.map((({int index, int charOffset}) e) => e.index),
        contains(0),
      );
    });

    testWidgets('build_givenTheLastChapter_showsTheEndPage', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness(
        <String, String>{'https://source.test/1.html': '第一章正文'},
        chapters: const <ReadingChapter>[
          ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
        ],
      );

      await harness.pump(tester);
      await _turnPage(tester);

      expect(find.text('This is the last chapter'), findsOneWidget);
      // 已是最后一章：没有「下一章」按钮，也没有占位页。
      expect(find.byType(ReaderChapterPendingStrip), findsNothing);
      expect(find.text('Next chapter'), findsNothing);
    });
  });
}
