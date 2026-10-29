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
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
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

/// A table of contents long enough for the prefetch window (±15) to be visible.
final List<ReadingChapter> _manyChapters = <ReadingChapter>[
  for (var index = 0; index < 20; index++)
    ReadingChapter(
      title: '第${index + 1}章',
      url: 'https://source.test/${index + 1}.html',
    ),
];

/// The chapters the page table currently renders, in reading order and without repeats.
List<int> _tableChapters(WidgetTester tester) =>
    _tableOf(tester).pages
        .map((ReaderPageEntry page) => page.id.chapterIndex)
        .toSet()
        .toList();

/// Where [url] sits in [_manyChapters].
int _chapterIndexOf(String url) =>
    _manyChapters.indexWhere((ReadingChapter chapter) => chapter.url == url);

/// The page table the reader is rendering right now.
ReaderPageTable _tableOf(WidgetTester tester) =>
    tester.widget<ReaderScrollFlow>(find.byType(ReaderScrollFlow)).table;

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
  // 加载页上的转圈是无限动画，`pumpAndSettle` 在它可见时永远不会返回。
  bool settle = true,
  Size size = const Size(1200, 2000),
}) async {
  tester.view.physicalSize = size;
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // 加载页上的转圈是无限动画：`pumpAndSettle` 在它可见时永远不会返回。
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
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

/// Opens the reader on four long chapters — long enough that a chapter boundary falls inside a
/// real scroll, not at a page break.
///
/// The neighbouring bodies are in the fixture's port from the start, so the prefetch queue has them
/// in hand before the reader ever reaches the boundary — which is what a real device looks like after
/// the first second of reading, and the only state in which "crossing must not jump" can hold.
Future<_Fixture> _pumpFourLongChapters(
  WidgetTester tester, {
  Size size = const Size(1200, 1200),
}) async {
  final _Fixture fixture = _fixture(
    chapters: FakeChapterListProvider()
      ..chapters = _manyChapters.take(4).toList(),
  );
  for (final ReadingChapter chapter in _manyChapters.take(4)) {
    fixture.content.bodies[chapter.url] = <String>[
      for (var line = 0; line < 40; line++)
        '${chapter.title} 第${line + 1}行：正文内容。',
    ].join(_newline);
  }
  await _pump(tester, fixture, size: size);

  return fixture;
}

/// Builds a fixture with every chapter's body in hand, opened at [anchorUrl].
///
/// Written out rather than built on top of [_fixture] because a store position has to be in the
/// fixture before the page is pumped — the session reads it once, in `build`.
_Fixture _pumpWithBodies({
  required List<ReadingChapter> chapters,
  required String anchorUrl,
}) {
  final _Fixture fixture = _fixture(
    chapters: FakeChapterListProvider()..chapters = chapters,
    progress: FakeReadingProgressStore()
      ..positions['${_book.sourceUrl}|${_book.bookUrl}'] = ReadingPosition(
        chapterUrl: anchorUrl,
      ),
  );
  for (final ReadingChapter chapter in chapters) {
    fixture.content.bodies[chapter.url] = <String>[
      for (var line = 0; line < 40; line++)
        '${chapter.title} 第${line + 1}行：正文内容。',
    ].join(_newline);
  }

  return fixture;
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

    testWidgets('build_givenARealChapterBody_laysItOutWithoutOverflow', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      // 真机的形状：长中文正文（全角缩进 + 段距空行）、带书名与标点的章节标题。
      // 页表按**量到**的高度给每一项定高，量的样式与画的样式只要差一行，这里就会溢出。
      fixture.content.bodies['https://source.test/1.html'] = <String>[
        for (var index = 0; index < 60; index++)
          '　　“这世道，人心不古。”老人叹了口气，抬起袖子擦了擦脸上的雨水，'
              '又低头看了看脚边那只破碗，碗里空荡荡的，只剩下一层浅浅的水光。',
      ].join(_newline);

      await _pump(tester, fixture);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('这世道，人心不古'), findsWidgets);
    });

    testWidgets('build_whenTheAnchorBodyIsMissing_stopsAtThatChapter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        chapters: FakeChapterListProvider()..chapters = _manyChapters,
      );
      // 第一章（锚点）的正文一直没到：页表只能排到它自己，读者滑不进第二章。
      fixture.content.bodies.remove('https://source.test/1.html');

      await _pump(tester, fixture, settle: false);

      // ADR-0088 §决策 1：阅读位置不许跑到已加载内容前面。
      expect(_tableChapters(tester), <int>[0]);
    });

    testWidgets('build_whenTheNextBodyIsMissing_opensOneLoadingPageOnly', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        chapters: FakeChapterListProvider()..chapters = _manyChapters,
      );
      // 第二章没有正文，第三章有：只能跨进第二章的加载页，第三章不得预先排进来。
      fixture.content.bodies.remove('https://source.test/2.html');

      await _pump(tester, fixture);

      final ReaderPageTable table = _tableOf(tester);
      expect(table.pages.last.id.chapterIndex, 1);
      expect(table.pages.last.isPlaceholder, isTrue);
      expect(_tableChapters(tester), isNot(contains(2)));
    });

    testWidgets('build_givenABigToc_prefetchesNearestFirstOneAtATime', (
      WidgetTester tester,
    ) async {
      final FakeReadingProgressStore store = FakeReadingProgressStore()
        ..positions['${_book.sourceUrl}|${_book.bookUrl}'] =
            const ReadingPosition(chapterUrl: 'https://source.test/8.html');
      final _Fixture fixture = _fixture(
        chapters: FakeChapterListProvider()..chapters = _manyChapters,
        progress: store,
      );
      // 只留下锚点与它两侧那一章：窗口里没有占位页，请求顺序就全是预取队列的顺序。
      fixture.content.bodies
        ..clear()
        ..['https://source.test/8.html'] = '第八章正文';
      // 一次只发一个请求：有延迟才看得出并发（ADR-0088 §决策 2）。
      fixture.content.delay = const Duration(milliseconds: 20);

      await _pump(tester, fixture);
      // 串行队列在假时钟上推进：每 30 ms 推一帧，直到队列走完（`pumpAndSettle` 不推进
      // 只挂着定时器的那些帧）。
      for (var frame = 0; frame < 400; frame++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      final List<String> requests = fixture.content.requests;
      // 锚点自己那一章先取（它走 provider），然后队列「后 1、前 1、后 2、前 2、…」。
      expect(requests.first, 'https://source.test/8.html');
      expect(requests.skip(1).take(6), <String>[
        'https://source.test/9.html',
        'https://source.test/7.html',
        'https://source.test/10.html',
        'https://source.test/6.html',
        'https://source.test/11.html',
        'https://source.test/5.html',
      ]);
      // 最近优先：与锚点的距离只增不减。
      final List<int> distances = <int>[
        for (final String url in requests.skip(1)) _chapterIndexOf(url) - 7,
      ].map((int distance) => distance.abs()).toList();
      for (var index = 1; index < distances.length; index++) {
        expect(distances[index], greaterThanOrEqualTo(distances[index - 1]));
        expect(distances[index], lessThanOrEqualTo(15));
      }
      // 每章只问一次；队列是串行的——同时在飞的除了队列那一个，只有页面自己 watch 的锚点章。
      expect(requests, hasLength(requests.toSet().length));
      expect(fixture.content.maxInFlight, lessThanOrEqualTo(2));
    });

    testWidgets('build_whenTheBookGainsChapters_keepsTheReaderWhereItIs', (
      WidgetTester tester,
    ) async {
      final FakeReadingProgressStore store = FakeReadingProgressStore()
        ..positions['${_book.sourceUrl}|${_book.bookUrl}'] =
            const ReadingPosition(
              chapterUrl: 'https://source.test/8.html',
              charOffset: 120,
            );
      final _Fixture fixture = _fixture(
        chapters: FakeChapterListProvider()
          ..chapters = _manyChapters.take(12).toList(),
        progress: store,
      );
      // 每一章都有正文（否则锚点章是一页加载页，转圈永远不停）。
      for (final ReadingChapter chapter in _manyChapters) {
        fixture.content.bodies[chapter.url] = _longBody;
      }

      await _pump(tester, fixture);
      // 读到第 8 章（下标 7）的中间：把进度写进会话，模拟「读到一半」。
      await fixture.container
          .read(readerSessionProvider(_book).notifier)
          .selectChapter(7, charOffset: 300);
      await tester.pump();
      final ScrollPosition before = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final double offsetBefore = before.pixels;

      // 书更了 8 章：目录刷新（`AsyncValue` 会先进 loading，再带新列表回来）。
      fixture.chapters.chapters = _manyChapters;
      fixture.container.invalidate(readerChaptersProvider(_book));
      await tester.pump();

      // ① 不闪屏：刷新期间读者眼前还是正文，没有整块的转圈。
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();

      // ② 不错位：会话仍停在同一章、同一偏移，滚动位置没有被"重新恢复"到存档那一次。
      final ReaderSessionState? session = fixture.container
          .read(readerSessionProvider(_book))
          .value;
      expect(session?.chapterIndex, 7);
      // 偏移是**当前这一屏**的（300 附近），不是存档里那一次的 120——刷新没有把位置倒回去。
      expect(session?.charOffset, greaterThan(200));
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(offsetBefore, 1),
      );
    });

    testWidgets('scroll_backAcrossChapters_keepsTheFlingRunning', (
      WidgetTester tester,
    ) async {
      // 回翻：读者滑回上一章时，那张表必须**已经**包含它（窗口在锚点上方留了 lead）。
      // 否则往回跨一章就要在视口上方插页、重设滚动位置 —— 位置是准的，但手势当场被丢掉，
      // 真机上就是「上滑回上一章被停住」。
      final _Fixture fixture = _pumpWithBodies(
        chapters: _manyChapters,
        anchorUrl: 'https://source.test/11.html',
      );
      await _pump(tester, fixture, size: const Size(1200, 1200));
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      int chapterOf() =>
          fixture.container
              .read(readerSessionProvider(_book))
              .value
              ?.chapterIndex ??
          0;

      // 往前读到第 13 章（下标 12），让窗口也经历一次回收。
      var guard = 0;
      while (chapterOf() < 12 && guard++ < 400) {
        await tester.drag(find.byType(ReaderPage), const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(chapterOf(), 12);
      final double start = position().pixels;

      // 一次上滑：惯性里跨过好几章也不该被停住。
      await tester.fling(find.byType(ReaderPage), const Offset(0, 300), 12000);
      final List<double> offsets = <double>[];
      final Set<int> chapters = <int>{};
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        offsets.add(position().pixels);
        chapters.add(chapterOf());
      }

      // 位移单调不增：没有一步往前跳。
      for (var index = 1; index < offsets.length; index++) {
        expect(
          offsets[index],
          lessThanOrEqualTo(offsets[index - 1]),
          reason: '第 $index 帧往前跳了 ${offsets[index] - offsets[index - 1]}',
        );
      }
      // 真的往上跨了至少两章，而且跨完还能接着滑（惯性没被停住）。
      expect(
        chapters.reduce((int a, int b) => a < b ? a : b),
        lessThanOrEqualTo(10),
      );
      expect(start - offsets.last, greaterThan(3000));
    });

    testWidgets('scroll_acrossAChapterBoundary_movesSmoothly', (
      WidgetTester tester,
    ) async {
      // 4 章、每章 40 行：跨章会发生在真实阅读过程中，而不是刚好一屏一章。
      final _Fixture fixture = await _pumpFourLongChapters(tester);
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      int chapterOf() =>
          fixture.container
              .read(readerSessionProvider(_book))
              .value
              ?.chapterIndex ??
          0;

      /// 拖一小段，返回视口位移。
      Future<double> step(double dy) async {
        final double before = position().pixels;
        await tester.drag(find.byType(ReaderPage), Offset(0, dy));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        return position().pixels - before;
      }

      // 向下：每一步的位移都必须与拖动同向、同量级——跨章那一步也不例外。
      // 真机的症状是跨章时被「强制回到顶部」，也就是某一步的位移突然反向或变大。
      final Set<int> crossed = <int>{};
      var previousChapter = chapterOf();
      for (var index = 0; index < 60; index++) {
        final double delta = await step(-60);
        expect(delta, greaterThanOrEqualTo(0), reason: '第 $index 步往回跳了');
        expect(delta, lessThanOrEqualTo(70), reason: '第 $index 步跳了 $delta');
        final int chapter = chapterOf();
        if (chapter != previousChapter) {
          crossed.add(chapter);
          previousChapter = chapter;
        }
      }
      expect(crossed, isNotEmpty, reason: '这轮滑动没有跨章，用例就白跑了');

      // 向上：同样要平滑——「在下一章上滑回上一章」是最容易跳的那一下。
      for (var index = 0; index < 60; index++) {
        final double delta = await step(60);
        expect(delta, lessThanOrEqualTo(0), reason: '上行第 $index 步往回跳了');
        expect(
          delta,
          greaterThanOrEqualTo(-70),
          reason: '上行第 $index 步跳了 $delta',
        );
      }
    });

    testWidgets('scroll_whenTheBoundaryIsCrossed_keepsTheNewChapterInHand', (
      WidgetTester tester,
    ) async {
      // 「跨章闪一下再跳章首」的根因是页表：会话换了章，`readerContent` 是新的一次请求、先是
      // loading，若正文只看 provider，整章会在那一帧退回**一页加载页**（章高从一屏缩成一行），
      // 上方高度骤变、位置只能按字符重算 —— 落点就是章首。正文在手就该按在手算。
      final _Fixture fixture = await _pumpFourLongChapters(tester);
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      int chapterOf() =>
          fixture.container
              .read(readerSessionProvider(_book))
              .value
              ?.chapterIndex ??
          0;

      // 往下滑到会话换章的那一步为止。
      var guard = 0;
      while (chapterOf() == 0 && guard++ < 60) {
        await tester.drag(find.byType(ReaderPage), const Offset(0, -60));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(chapterOf(), 1, reason: '这轮滑动没有跨到第二章');

      // ① 新章没有变成加载页：它的每一页都排着真正文。
      final ReaderPageTable table = _tableOf(tester);
      final List<ReaderPageEntry> second = table.pages
          .where((ReaderPageEntry page) => page.id.chapterIndex == 1)
          .toList();
      expect(second, isNotEmpty);
      expect(second.any((ReaderPageEntry page) => page.isPlaceholder), isFalse);
      expect(second, hasLength(greaterThan(1)), reason: '第二章是长章，不是一页');
      // ② 屏幕上没有加载条 / 转圈。
      expect(find.byType(ReaderChapterPendingStrip), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // ③ 窗口往下一章接着排（跨章那一步只往下追加，不动上方高度）。
      expect(
        table.pages.map((ReaderPageEntry page) => page.id.chapterIndex),
        contains(2),
      );
      // ④ 位置是连续的。
      expect(position().pixels, greaterThan(0));

      // 上滑回上一章同样不能掉正文：这是用户报的「回到上一章顶部」。
      final double beforeUp = position().pixels;
      var upGuard = 0;
      while (chapterOf() == 1 && upGuard++ < 60) {
        await tester.drag(find.byType(ReaderPage), const Offset(0, 60));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(chapterOf(), 0);
      final ReaderPageTable afterUp = _tableOf(tester);
      expect(
        afterUp.pages
            .where((ReaderPageEntry page) => page.id.chapterIndex == 0)
            .any((ReaderPageEntry page) => page.isPlaceholder),
        isFalse,
      );
      // 回到上一章是「接着上一章的末尾往上滑」，不是被扔回它的开头。
      expect(position().pixels, greaterThan(beforeUp - 200));
      expect(find.byType(ReaderChapterPendingStrip), findsNothing);
    });

    testWidgets('scroll_acrossAChapterBoundary_doesNotStopTheFling', (
      WidgetTester tester,
    ) async {
      // 惯性里跨章：页表只是往下追加，滚动位置一点不用重设，于是 `Scrollable` 不被换掉、
      // 惯性照旧。以前跨章那一帧会新建控制器（换 key），惯性当场被丢掉 —— 读者看到的就是
      // 「跨章被强制停下、还闪了一下」。
      final _Fixture fixture = await _pumpFourLongChapters(tester);
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      int chapterOf() =>
          fixture.container
              .read(readerSessionProvider(_book))
              .value
              ?.chapterIndex ??
          0;

      // 停在跨章前一点，再一次 fling 越过去。
      await tester.drag(find.byType(ReaderPage), const Offset(0, -1800));
      await tester.pump(const Duration(milliseconds: 400));
      expect(chapterOf(), 0);

      await tester.fling(find.byType(ReaderPage), const Offset(0, -200), 2500);
      final List<double> offsets = <double>[];
      final Set<int> chapters = <int>{};
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        offsets.add(position().pixels);
        chapters.add(chapterOf());
      }

      // 这一轮 fling 真的跨了章，用例才有意义。
      expect(chapters, contains(1));
      // 位移单调不减：没有一步往回跳。
      for (var index = 1; index < offsets.length; index++) {
        expect(
          offsets[index],
          greaterThanOrEqualTo(offsets[index - 1]),
          reason: '第 $index 帧往回跳了 ${offsets[index] - offsets[index - 1]}',
        );
      }
      // 惯性还在：跨章之后仍在往前走（不是被「落地」那一下停住）。
      final int crossing = offsets.indexWhere(
        (double offset) => offset > offsets.first + 1,
      );
      expect(crossing, greaterThanOrEqualTo(0));
      expect(offsets.last, greaterThan(offsets[crossing] + 100));
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
