import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_source_kind.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_session.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_tts_highlight.dart';
import 'package:flutter_reader/features/reader/presentation/pages/reader_page.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/audio_reader_view.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_scroll_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_settings_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_status_bar.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_audio_ports.dart';
import '../../../../support/fake_bookmark_repository.dart';
import '../../../../support/fake_clock.dart';
import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_reader_platform_ports.dart';
import '../../../../support/fake_reader_ports.dart';
import '../../../../support/fake_reading_record_repository.dart';
import '../../../../support/offline_corpus.dart';

/// The book every case opens.
const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '剑来',
  tocUrl: 'https://source.test/book/1/toc',
);

/// One chapter, long enough that a paged layout needs several pages.
final String _longBody = <String>[
  for (var index = 0; index < 80; index++) '第${index + 1}行：正文内容。',
].join('\n');

/// The chapters the fake list answers with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章 开端', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章 继续', url: 'https://source.test/2.html'),
];

/// The line break the chapter bodies in these cases are joined with.
final String _newline = String.fromCharCode(10);

/// The collaborators one case wires together.
typedef _Fixture = ({
  ProviderContainer container,
  FakeChapterListProvider chapters,
  FakeChapterContentProvider content,
  FakeReadingProgressStore progress,
  FakeReaderSettingsRepository settings,
  FakeBookmarkRepository bookmarks,
  FakeReadingRecordRepository records,
  FakeClock clock,
  FakeLogPrinter printer,
  FakeScreenAwake screenAwake,
  FakeBatteryLevel battery,
});

/// Builds a container around the three reader ports and the settings store.
_Fixture _fixture({
  FakeChapterListProvider? chapters,
  FakeReadingProgressStore? progress,
  ReaderSettings? settings,
  FakeBookmarkRepository? bookmarks,
  FakeReadingRecordRepository? records,
  FakeClock? clock,
  ReaderSourceKind kind = ReaderSourceKind.text,
}) {
  final FakeChapterListProvider list = chapters ?? FakeChapterListProvider();
  if (chapters == null) {
    list.chapters = _chapters;
  }
  final FakeChapterContentProvider content = FakeChapterContentProvider()
    ..bodies['https://source.test/1.html'] = _longBody
    ..bodies['https://source.test/2.html'] = '第二章正文';
  final FakeReadingProgressStore store = progress ?? FakeReadingProgressStore();
  final FakeReaderSettingsRepository readerSettings =
      FakeReaderSettingsRepository(initial: settings);
  final FakeBookmarkRepository bookmarkStore =
      bookmarks ?? FakeBookmarkRepository();
  final FakeReadingRecordRepository recordStore =
      records ?? FakeReadingRecordRepository();
  final FakeClock fakeClock = clock ?? FakeClock();
  final FakeLogPrinter printer = FakeLogPrinter();
  final FakeScreenAwake screenAwake = FakeScreenAwake();
  final FakeBatteryLevel battery = FakeBatteryLevel(level: 80);
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      readerChapterListProvider.overrideWithValue(list),
      readerChapterContentProvider.overrideWithValue(content),
      readerProgressStoreProvider.overrideWithValue(store),
      bookmarkRepositoryProvider.overrideWithValue(bookmarkStore),
      readingRecordRepositoryProvider.overrideWithValue(recordStore),
      clockProvider.overrideWithValue(fakeClock),
      readerSettingsRepositoryProvider.overrideWith(
        (Ref ref) async => readerSettings,
      ),
      readerSourceKindPortProvider.overrideWithValue(
        FakeReaderSourceKindProvider()..kind = kind,
      ),
      readerAudioTrackProvider.overrideWithValue(
        FakeAudioTrackProvider()
          ..tracks['https://source.test/1.html'] = <ReaderAudioTrack>[
            const ReaderAudioTrack(url: 'https://cdn.test/1.mp3'),
          ]
          ..tracks['https://source.test/2.html'] = <ReaderAudioTrack>[
            const ReaderAudioTrack(url: 'https://cdn.test/2.mp3'),
          ],
      ),
      audioPlaybackEngineProvider.overrideWithValue(FakeAudioPlaybackEngine()),
      playbackNotificationProvider.overrideWithValue(
        const NoopPlaybackNotification(),
      ),
      screenAwakeProvider.overrideWithValue(screenAwake),
      batteryLevelProvider.overrideWithValue(battery),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: printer),
      ),
    ],
  );
  addTearDown(container.dispose);

  return (
    container: container,
    chapters: list,
    content: content,
    progress: store,
    settings: readerSettings,
    bookmarks: bookmarkStore,
    records: recordStore,
    clock: fakeClock,
    printer: printer,
    screenAwake: screenAwake,
    battery: battery,
  );
}

/// Pumps the reader page on top of [fixture].
Future<void> _pump(
  WidgetTester tester,
  _Fixture fixture, {
  String? chapterUrl,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: ReaderPage(book: _book, chapterUrl: chapterUrl),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The strings the page renders, taken from the page's own localization.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(ReaderPage));

/// The body text widget of the reader.
Finder _bodyFinder() => find.textContaining('第1行');

/// Reveals the immersive chrome by tapping the middle third (ADR-0051 §决策 1).
Future<void> _showChrome(WidgetTester tester) async {
  final Size size = tester.getSize(find.byType(ReaderPage));
  await tester.tapAt(Offset(size.width / 2, size.height / 2));
  await tester.pump();
}

/// Opens the settings sheet (chrome first: the reader starts immersive).
Future<void> _openSettings(WidgetTester tester) async {
  await _showChrome(tester);
  await tester.tap(find.byTooltip(_l10n(tester).readerSettingsAction));
  await tester.pumpAndSettle();
}

void main() {
  group('ReaderPage dispatch', () {
    testWidgets('build_givenAnAudioSource_opensThePlayer', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _fixture(kind: ReaderSourceKind.audio));

      expect(find.byType(AudioReaderView), findsOneWidget);
      // 音频书不去抓正文：文本视图根本不存在。
      expect(_bodyFinder(), findsNothing);
    });

    testWidgets('build_givenATextSource_keepsTheTextReader', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _fixture(kind: ReaderSourceKind.text));

      expect(find.byType(AudioReaderView), findsNothing);
      expect(_bodyFinder(), findsOneWidget);
    });
  });

  group('ReaderPage', () {
    testWidgets('build_givenAChapterList_showsTheFirstChapter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);

      // AppBar 默认隐藏（沉浸式）：章节标题只在唤出 chrome 后才出现在标题栏里
      // （状态栏那一份是 ADR-0086 §决策 6 的常驻行，不是 chrome）。
      expect(find.byType(AppBar), findsNothing);
      await _showChrome(tester);
      expect(find.text('第1章 开端'), findsWidgets);
      expect(_bodyFinder(), findsOneWidget);
      expect(fixture.chapters.requests.single.$2, _book.tocUrl);
    });

    testWidgets('build_givenAStoredPosition_opensThatChapter', (
      WidgetTester tester,
    ) async {
      final FakeReadingProgressStore store = FakeReadingProgressStore()
        ..positions['${_book.sourceUrl}|${_book.bookUrl}'] =
            const ReadingPosition(
              chapterUrl: 'https://source.test/2.html',
              chapterName: '第2章',
            );
      final _Fixture fixture = _fixture(progress: store);

      await _pump(tester, fixture);

      // 恢复到存下来的那一章，而不是永远从第一章开始。
      expect(find.textContaining('第二章正文'), findsOneWidget);
      await _showChrome(tester);
      expect(find.text('第2章 继续'), findsWidgets);
    });

    testWidgets('build_givenAChapterUrl_opensTheRequestedChapter', (
      WidgetTester tester,
    ) async {
      // 详情页点某一章时，显式给的章节要压过「上次读到哪」。
      final FakeReadingProgressStore store = FakeReadingProgressStore()
        ..positions['${_book.sourceUrl}|${_book.bookUrl}'] =
            const ReadingPosition(chapterUrl: 'https://source.test/1.html');
      final _Fixture fixture = _fixture(progress: store);

      await _pump(tester, fixture, chapterUrl: 'https://source.test/2.html');

      expect(find.textContaining('第二章正文'), findsOneWidget);
    });

    testWidgets('build_givenABodyRepeatingTheChapterTitle_printsTheTitleOnce', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      // 源站常见形状：正文第一行就是本章标题。阅读器自己也印章头，不删掉就是两次
      // （上游 `ContentProcessor` 的「去除重复标题」同一件事，ADR-0087 §决策 4）。
      fixture.content.bodies['https://source.test/1.html'] =
          '第1章 开端$_newline$_longBody';

      await _pump(tester, fixture);

      expect(find.text('第1章 开端'), findsOneWidget);
      expect(find.textContaining('第1章 开端'), findsOneWidget);
      // 正文本身还在（只删了重复的那一行）。
      expect(_bodyFinder(), findsOneWidget);
    });

    testWidgets('build_givenAFailingChapterList_showsTheFailure', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        chapters: FakeChapterListProvider()
          ..failure = const ParseFailure<List<ReadingChapter>>(
            kind: ParseFailureKind.networkFailed,
            rulePath: 'reader.chapterList',
          ),
      );

      await _pump(tester, fixture);

      expect(find.text(_l10n(tester).failureNetworkFailed), findsOneWidget);
    });

    testWidgets('nextChapter_whenTapped_showsTheNextChapter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      await _showChrome(tester);
      await tester.tap(find.byTooltip(_l10n(tester).readerNextChapter));
      await tester.pumpAndSettle();

      expect(find.textContaining('第二章正文'), findsOneWidget);
      expect(fixture.progress.writes, isNotEmpty);
    });

    testWidgets('toc_whenAChapterIsTapped_opensIt', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      await _showChrome(tester);
      await tester.tap(find.byTooltip(_l10n(tester).readerTocAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text('第2章 继续').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('第二章正文'), findsOneWidget);
    });

    testWidgets('settings_whenTheFontSizeIsRaised_appliesItToTheBody', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      final double before = tester.widget<Text>(_bodyFinder()).style!.fontSize!;

      await _openSettings(tester);
      // 字号滑块是设置面板里的第一根；往右拖一档。**必须限定在面板内**：工具条的进度滑块
      // 也是一个 `Slider`，用 `.first` 会拖错那一个。
      await tester.drag(
        find
            .descendant(
              of: find.byType(ReaderSettingsSheet),
              matching: find.byType(Slider),
            )
            .first,
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(_bodyFinder()).style!.fontSize,
        greaterThan(before),
      );
      expect(fixture.settings.stored.fontScale, greaterThan(1));
    });

    testWidgets('settings_whenTheDarkBackgroundIsChosen_paintsIt', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      final Color before = tester
          .widget<Scaffold>(find.byType(Scaffold))
          .backgroundColor!;

      await _openSettings(tester);
      await tester.tap(find.text(_l10n(tester).readerBackgroundDark));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        isNot(before),
      );
      expect(fixture.settings.stored.background, ReaderBackground.dark);
    });

    testWidgets('settings_whenPagedIsChosen_showsPages', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      expect(find.byType(PageView), findsNothing);

      await _openSettings(tester);
      await tester.tap(find.text(_l10n(tester).readerPageModePaged));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(fixture.settings.stored.pageMode, ReaderPageMode.paged);
    });

    testWidgets('pagedMode_whenThePageIsTurned_remembersTheNewOffset', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(pageMode: ReaderPageMode.paged),
      );

      await _pump(tester, fixture);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();

      // 翻页把「读到第几页」换算成字符偏移并交给会话（ADR-0044 §决策 4）。
      expect(
        fixture.container.read(readerSessionProvider(_book)).value?.charOffset,
        greaterThan(0),
      );
    });

    testWidgets(
      'pagedMode_whenTheNextChapterIsPrefetched_turnsAcrossTheBoundary',
      (WidgetTester tester) async {
        final _Fixture fixture = _fixture(
          settings: ReaderSettings(pageMode: ReaderPageMode.paged),
        );
        // 第一章缩到一页：越过章界只差一次翻页。
        fixture.content.bodies['https://source.test/1.html'] = '第一章正文';

        await _pump(tester, fixture);
        // 预取是真实端口请求：还没翻页，第二章已经在手里（`pumpAndSettle` 等它落地）。
        expect(
          fixture.content.requests,
          contains('https://source.test/2.html'),
        );

        await tester.drag(find.byType(PageView), const Offset(-600, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // 跨章翻页：会话进入下一章；正文到了就在这一页换上来（ADR-0086 §决策 7）。
        expect(
          fixture.container
              .read(readerSessionProvider(_book))
              .value
              ?.chapterIndex,
          1,
        );
        // 章界不再是一页「本章读完 + 下一章」；正文没到就是这一章的加载页。
        expect(find.text('This is the last chapter'), findsNothing);
      },
    );

    testWidgets('scrollMode_whenTheNextChapterIsInHand_showsItInTheSameFlow', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);

      // 下一章正文是预取来的（`pumpAndSettle` 等它落地），已经排进同一份滚动页表里：
      // 章末不再是一个需要点一下的页（ADR-0085 §决策 2、ADR-0087 §决策 1）。
      expect(fixture.content.requests, contains('https://source.test/2.html'));
      final ReaderScrollFlow flow = tester.widget<ReaderScrollFlow>(
        find.byType(ReaderScrollFlow),
      );
      expect(
        flow.table.pages.map((ReaderPageEntry page) => page.id.chapterIndex),
        containsAll(<int>[0, 1]),
      );
      // 页表已经到全书末尾（滚动列表是懒加载的，「已是最后一章」在末尾一屏之外，不当场断言）。
      expect(flow.table.hasNextChapter, isFalse);
    });

    testWidgets('scrollMode_whenScrolledToTheEnd_opensTheNextChapter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      // 第二章也写长（远高于一屏）：只有它占满视野时，滑到末尾的视口顶才落在它里面。
      fixture.content.bodies['https://source.test/2.html'] = <String>[
        for (var index = 0; index < 200; index++) '第二章第${index + 1}行：正文内容。',
      ].join('\n');

      await _pump(tester, fixture);
      // 一段一段往下滑（每段不到一屏，免得撞上过卷动画）：视口顶一旦落进第二章，
      // 会话就该自己换过去（ADR-0086 §决策 7）。
      for (
        var attempt = 0;
        attempt < 10 &&
            fixture.container
                    .read(readerSessionProvider(_book))
                    .value
                    ?.chapterIndex !=
                1;
        attempt++
      ) {
        await tester.drag(
          find.byType(ReaderScrollFlow),
          const Offset(0, -1600),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        fixture.container
            .read(readerSessionProvider(_book))
            .value
            ?.chapterIndex,
        1,
      );
      expect(fixture.progress.writes, isNotEmpty);
    });

    testWidgets('build_givenTheWarmFilterOn_wrapsTheBodyInIt', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(eyeProtection: 40),
      );

      await _pump(tester, fixture);

      // 护眼是正文上的一层滤镜（ADR-0086 §决策 2），不是系统亮度。
      expect(find.byType(ColorFiltered), findsOneWidget);
    });

    testWidgets('build_givenTheWarmFilterOff_leavesTheBodyAlone', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);

      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets('build_givenTheStatusLineOn_showsChapterProgressAndCharge', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);

      // 状态行只有进度 + 时间 + 电量；章名归正文里的章头（ADR-0086 §决策 7），不再重复。
      expect(
        find.descendant(
          of: find.byType(ReaderStatusBar),
          matching: find.textContaining(
            _l10n(tester).readerChapterProgress(1, 2),
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('80% battery'), findsOneWidget);
    });

    testWidgets('build_givenTheStatusLineOff_hidesIt', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(showReaderStatus: false),
      );

      await _pump(tester, fixture);

      expect(find.textContaining('battery'), findsNothing);
    });

    testWidgets('build_givenKeepScreenAwakeOn_asksThePlatform', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);

      // 阅读器一打开就要住「别息屏」，离开时交还（ADR-0086 §决策 1）。
      expect(fixture.screenAwake.calls, <bool>[true]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(fixture.screenAwake.calls, <bool>[true, false]);
    });

    testWidgets('dispose_whenLeaving_writesThePosition', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      // 换掉整棵子树 → 阅读器 dispose → 落盘（ADR-0044 §决策 2）。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(fixture.progress.writes, isNotEmpty);
      expect(
        fixture.progress.writes.last.chapterUrl,
        'https://source.test/1.html',
      );
    });
  });

  group('ReaderPage tts highlight', () {
    testWidgets('ttsHighlight_whenTheChapterIsBeingRead_paintsTheSentence', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      final String rendered = readerBodyText(
        _longBody,
        ReaderSettings.defaults,
      );
      fixture.container
          .read(readerTtsHighlighterProvider.notifier)
          .show(chapterUrl: 'https://source.test/1.html', start: 2, end: 10);
      await tester.pump();

      final Text body = tester.widget<Text>(_bodyFinder());
      final TextSpan painted = (body.textSpan! as TextSpan).children!
          .whereType<TextSpan>()
          .firstWhere((TextSpan span) => span.style?.backgroundColor != null);

      expect(painted.text, rendered.substring(2, 10));
    });

    testWidgets('ttsHighlight_whenItBelongsToAnotherChapter_paintsNothing', (
      WidgetTester tester,
    ) async {
      // 读者可能已经翻到下一章：旧章节的句子不能画在新正文上。
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      fixture.container
          .read(readerTtsHighlighterProvider.notifier)
          .show(chapterUrl: 'https://source.test/2.html', start: 2, end: 10);
      await tester.pump();

      final Text body = tester.widget<Text>(_bodyFinder());
      expect(body.textSpan, isNull);
    });
  });

  group('ReaderPage bookmarks', () {
    testWidgets('bookmarkButton_whenTapped_addsTheCurrentPosition', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await _showChrome(tester);
      await tester.tap(find.byTooltip(_l10n(tester).bookmarkAdd));
      await tester.pumpAndSettle();

      expect(fixture.bookmarks.toggles, hasLength(1));
      final BookmarkDraft draft = fixture.bookmarks.toggles.single;
      expect(draft.chapterUrl, 'https://source.test/1.html');
      expect(draft.bookName, '剑来');
      expect(draft.tocUrl, 'https://source.test/book/1/toc');
      expect(draft.excerpt, isNotNull);
      expect(find.text(_l10n(tester).bookmarkAdded), findsOneWidget);
    });

    testWidgets('bookmarkButton_whenThePositionIsMarked_removesIt', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      fixture.bookmarks.bookmarks.add(
        Bookmark(
          id: 1,
          sourceUrl: _book.sourceUrl,
          bookUrl: _book.bookUrl,
          bookName: _book.name,
          chapterUrl: 'https://source.test/1.html',
          chapterName: '第1章 开端',
          charOffset: 0,
          createdAt: DateTime(2026, 10, 23),
        ),
      );
      await _pump(tester, fixture);

      await _showChrome(tester);
      // 位置已被标记时按钮的提示是「取消书签」，图标也是实心的。
      await tester.tap(find.byTooltip(_l10n(tester).bookmarkRemove));
      await tester.pumpAndSettle();

      expect(fixture.bookmarks.bookmarks, isEmpty);
      expect(find.text(_l10n(tester).bookmarkRemoved), findsOneWidget);
    });

    testWidgets('bookmarkButton_whenTheWriteFails_showsTheFailureMessage', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      fixture.bookmarks.writeFailure = Exception('disk is full');
      await _pump(tester, fixture);

      await _showChrome(tester);
      await tester.tap(find.byTooltip(_l10n(tester).bookmarkAdd));
      await tester.pumpAndSettle();

      expect(find.text(_l10n(tester).bookmarkFailed), findsOneWidget);
      expect(fixture.bookmarks.bookmarks, isEmpty);
    });
  });

  group('ReaderPage reading records', () {
    testWidgets('dispose_whenTheSessionLastedLongEnough_recordsIt', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);
      fixture.clock.advance(const Duration(minutes: 3));

      // 离开阅读器：换掉整棵树，触发 dispose（记录在那一刻收尾，ADR-0066 §决策 4）。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      final ReadingSession session = fixture.records.sessions.single;
      expect(session.bookUrl, _book.bookUrl);
      expect(session.bookName, _book.name);
      expect(session.chapterUrl, 'https://source.test/1.html');
      expect(session.durationSeconds, 180);
    });

    testWidgets('dispose_whenTheSessionWasTooShort_recordsNothing', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(fixture.records.sessions, isEmpty);
    });
  });
}
