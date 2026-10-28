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
  group('ReaderChapterWindow', () {
    test('sync_givenOnlyTheAnchorBody_answersThatOneChapter', () {
      final ReaderChapterWindow window = ReaderChapterWindow();

      final List<ReaderFlowChapter> visible = window.sync(
        chapters: _chapters,
        anchorIndex: 1,
        bodies: <String, String>{'https://source.test/2.html': '正文二'},
      );

      expect(visible, hasLength(1));
      expect(visible.single.index, 1);
      expect(visible.single.text, '正文二');
    });

    test('sync_givenBodiesAroundTheAnchor_answersThemInTocOrder', () {
      final ReaderChapterWindow window = ReaderChapterWindow();

      final List<ReaderFlowChapter> visible = window.sync(
        chapters: _chapters,
        anchorIndex: 1,
        bodies: <String, String>{
          'https://source.test/3.html': '正文三',
          'https://source.test/1.html': '正文一',
          'https://source.test/2.html': '正文二',
        },
      );

      expect(visible.map((ReaderFlowChapter chapter) => chapter.index), <int>[
        0,
        1,
        2,
      ]);
    });

    test('sync_givenAGapBeforeTheAnchor_stopsAtTheGap', () {
      // 中间章没有正文时不能把上下一拼：读者会滑进「不存在的正文」。
      final ReaderChapterWindow window = ReaderChapterWindow();

      final List<ReaderFlowChapter> visible = window.sync(
        chapters: _chapters,
        anchorIndex: 2,
        bodies: <String, String>{
          'https://source.test/3.html': '正文三',
          'https://source.test/1.html': '正文一',
        },
      );

      expect(visible, hasLength(1));
      expect(visible.single.index, 2);
    });

    test('sync_givenNoBodyForTheAnchor_answersNothing', () {
      // 当前章正文还没到手：页面显示加载态，流程不该拿一个带洞的窗口去渲染。
      expect(
        ReaderChapterWindow().sync(
          chapters: _chapters,
          anchorIndex: 0,
          bodies: <String, String>{'https://source.test/2.html': '正文二'},
        ),
        isEmpty,
      );
    });

    test('sync_givenAnEmptyToc_answersNothing', () {
      expect(
        ReaderChapterWindow().sync(
          chapters: const <ReadingChapter>[],
          anchorIndex: 0,
          bodies: <String, String>{'https://source.test/1.html': '正文一'},
        ),
        isEmpty,
      );
    });

    test('sync_givenARebuiltToc_dropsTheChaptersItNoLongerKnows', () {
      final ReaderChapterWindow window = ReaderChapterWindow();
      window.sync(
        chapters: _chapters,
        anchorIndex: 0,
        bodies: <String, String>{
          'https://source.test/1.html': '正文一',
          'https://source.test/2.html': '正文二',
        },
      );

      // 换源后地址全变：旧章不能靠「已经渲染过」继续挂在窗口里（ADR-0085 §决策 3）。
      final List<ReaderFlowChapter> visible = window.sync(
        chapters: const <ReadingChapter>[
          ReadingChapter(title: '新第一章', url: 'https://other.test/1.html'),
        ],
        anchorIndex: 0,
        bodies: <String, String>{'https://other.test/1.html': '新正文一'},
      );

      expect(visible, hasLength(1));
      expect(visible.single.url, 'https://other.test/1.html');
    });

    test('sync_givenABodyThatLeftThePageWindow_keepsTheRenderedChapter', () {
      // 预取窗口跟着会话滑走时，屏幕上已经渲染的章不能跟着消失（否则读者眼前会跳一下）。
      final ReaderChapterWindow window = ReaderChapterWindow();
      window.sync(
        chapters: _chapters,
        anchorIndex: 1,
        bodies: <String, String>{
          'https://source.test/1.html': '正文一',
          'https://source.test/2.html': '正文二',
        },
      );

      final List<ReaderFlowChapter> visible = window.sync(
        chapters: _chapters,
        anchorIndex: 1,
        bodies: <String, String>{'https://source.test/2.html': '正文二'},
      );

      expect(visible.map((ReaderFlowChapter chapter) => chapter.index), <int>[
        0,
        1,
      ]);
    });

    test('retain_givenChaptersWithinTheRadius_keepsThem', () {
      final ReaderChapterWindow window = ReaderChapterWindow()
        ..sync(
          chapters: _chapters,
          anchorIndex: 1,
          bodies: <String, String>{
            'https://source.test/1.html': '正文一',
            'https://source.test/2.html': '正文二',
            'https://source.test/3.html': '正文三',
          },
        );

      final List<ReaderFlowChapter> dropped = window.retain(anchorIndex: 1);

      expect(dropped, isEmpty);
      expect(
        window.sync(
          chapters: _chapters,
          anchorIndex: 1,
          bodies: const <String, String>{},
        ),
        hasLength(3),
      );
    });

    test('retain_givenAChapterTwoAway_dropsItForGood', () {
      final ReaderChapterWindow window = ReaderChapterWindow()
        ..sync(
          chapters: _chapters,
          anchorIndex: 0,
          bodies: <String, String>{
            'https://source.test/1.html': '正文一',
            'https://source.test/2.html': '正文二',
            'https://source.test/3.html': '正文三',
          },
        );

      final List<ReaderFlowChapter> dropped = window.retain(anchorIndex: 0);

      expect(dropped.map((ReaderFlowChapter chapter) => chapter.index), <int>[
        2,
      ]);
      // 落下的章不再回来：内存里只留相邻的一章（ADR-0085 §决策 3）。
      expect(
        window
            .sync(
              chapters: _chapters,
              anchorIndex: 0,
              bodies: const <String, String>{},
            )
            .map((ReaderFlowChapter chapter) => chapter.index),
        <int>[0, 1],
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
      expect(find.text('Loading the neighbouring chapter…'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('build_givenAFailedRead_offersTheRetry', (
      WidgetTester tester,
    ) async {
      var retried = 0;
      await _pumpStrip(
        tester,
        ReaderChapterPendingStrip(isFailed: true, onRetry: () => retried++),
      );

      // 读失败的章不能一直画成「还在加载」。
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Reload this chapter'));
      expect(retried, 1);
    });
  });
}
