import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/audio_reader_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/audio_reader_view.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_audio_ports.dart';
import '../../../../support/fake_clock.dart';
import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_reader_ports.dart';
import '../../../../support/offline_corpus.dart';

/// The book every case opens.
const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '听书',
  tocUrl: 'https://source.test/book/1/toc',
);

/// The chapters the fake list answers with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/2.html'),
];

/// The collaborators one case wires together.
typedef _Fixture = ({
  ProviderContainer container,
  FakeAudioPlaybackEngine engine,
});

/// Builds a container around the audio doubles.
_Fixture _fixture({ParseFailureKind? loadFailure}) {
  final FakeChapterListProvider chapters = FakeChapterListProvider()
    ..chapters = _chapters;
  final FakeChapterContentProvider content = FakeChapterContentProvider()
    ..bodies['https://source.test/1.html'] = '第一章正文'
    ..bodies['https://source.test/2.html'] = '第二章正文';
  final FakeAudioTrackProvider tracks = FakeAudioTrackProvider()
    ..tracks['https://source.test/1.html'] = <ReaderAudioTrack>[
      const ReaderAudioTrack(url: 'https://cdn.test/1.mp3'),
    ]
    ..tracks['https://source.test/2.html'] = <ReaderAudioTrack>[
      const ReaderAudioTrack(url: 'https://cdn.test/2.mp3'),
    ];
  final FakeAudioPlaybackEngine engine = FakeAudioPlaybackEngine()
    ..loadFailure = loadFailure;
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      readerChapterListProvider.overrideWithValue(chapters),
      readerChapterContentProvider.overrideWithValue(content),
      readerProgressStoreProvider.overrideWithValue(FakeReadingProgressStore()),
      readerAudioTrackProvider.overrideWithValue(tracks),
      audioPlaybackEngineProvider.overrideWithValue(engine),
      playbackNotificationProvider.overrideWithValue(
        const NoopPlaybackNotification(),
      ),
      clockProvider.overrideWithValue(FakeClock()),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ),
    ],
  );
  addTearDown(container.dispose);

  return (container: container, engine: engine);
}

/// Pumps the audio view on top of [fixture].
Future<void> _pump(WidgetTester tester, _Fixture fixture) async {
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
        home: const AudioReaderView(book: _book),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The strings the view renders.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(AudioReaderView));

void main() {
  group('AudioReaderView', () {
    testWidgets('build_givenATrack_showsThePlayer', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);

      expect(find.text('听书'), findsOneWidget);
      expect(find.text('第1章'), findsOneWidget);
      expect(find.byTooltip(_l10n(tester).readerAudioPlay), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('0:00'), findsNWidgets(2));
    });

    testWidgets('build_givenAPlayTap_asksTheEngineToPlay', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await tester.tap(find.byTooltip(_l10n(tester).readerAudioPlay));
      await tester.pump();

      expect(fixture.engine.playCalls, 1);
    });

    testWidgets('build_givenPlayingSnapshots_showsThePositionAndPause', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          position: Duration(seconds: 3),
          duration: Duration(seconds: 30),
        ),
      );
      await tester.pump();

      expect(find.text('0:03'), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);
      expect(find.byTooltip(_l10n(tester).readerAudioPause), findsOneWidget);
    });

    testWidgets('snapshots_givenOnlyThePositionChanges_doNotNotifyThePage', (
      WidgetTester tester,
    ) async {
      // 回归点（ADR-0064 §决策 1）：位置每 ~200 ms 变一次，整页跟着重建会把 Windows 的 UIA
      // 桥刷成 `Failed to update ui::AXTree … Nodes left pending by the update`。
      // 页面订阅的是 audioReaderPageState（不含位置），所以位置跳变不该通知它。
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);
      var notifications = 0;
      fixture.container.listen<AsyncValue<AudioReaderSkeleton>>(
        audioReaderProvider(_book).select(audioReaderPageState),
        (
          AsyncValue<AudioReaderSkeleton>? previous,
          AsyncValue<AudioReaderSkeleton> next,
        ) => notifications++,
      );

      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          position: Duration(seconds: 1),
          duration: Duration(seconds: 30),
        ),
      );
      await tester.pump();
      expect(find.text('0:01'), findsOneWidget);
      final int afterFirstTick = notifications;

      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          position: Duration(seconds: 2),
          duration: Duration(seconds: 30),
        ),
      );
      await tester.pump();

      // 位置仍然上屏（那一行自己订阅了 position），但页面结构没有被通知重建。
      expect(find.text('0:02'), findsOneWidget);
      expect(find.text('0:01'), findsNothing);
      expect(notifications, afterFirstTick, reason: '只有位置变化时，页面结构不该重建');
    });

    test('audioReaderSkeleton_ignoresTheTickingPosition', () {
      // select 的等价性靠这个投影：位置不同的两个状态必须投影成相等值，否则「不重建」不成立。
      const AudioReaderState base = AudioReaderState(
        tracks: <ReaderAudioTrack>[
          ReaderAudioTrack(url: 'https://cdn.test/1.mp3'),
        ],
        isPlaying: true,
        position: Duration(seconds: 1),
        duration: Duration(seconds: 30),
        speed: 1.25,
      );

      expect(
        audioReaderSkeleton(base),
        audioReaderSkeleton(
          base.copyWith(position: const Duration(seconds: 9)),
        ),
      );
      expect(
        audioReaderSkeleton(base),
        isNot(audioReaderSkeleton(base.copyWith(isPlaying: false))),
      );
      expect(
        audioReaderSkeleton(base),
        isNot(audioReaderSkeleton(base.copyWith(speed: 1))),
      );
    });

    testWidgets('tapNextChapter_loadsTheNextChapter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await tester.tap(find.byTooltip(_l10n(tester).readerNextChapter));
      await tester.pump();
      await tester.pump();

      expect(fixture.engine.loadedUrls.last, 'https://cdn.test/2.mp3');
      expect(find.text('第2章'), findsOneWidget);
    });

    testWidgets('speedChip_whenTapped_setsTheSpeed', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await tester.tap(find.text(_l10n(tester).readerAudioSpeedValue('1.5')));
      await tester.pump();

      expect(fixture.engine.speeds, <double>[1.5]);
    });

    testWidgets('build_givenALoadFailure_showsTheRetry', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        loadFailure: ParseFailureKind.parseFailed,
      );

      await _pump(tester, fixture);

      expect(find.text(_l10n(tester).readerAudioFailed), findsOneWidget);
      await tester.tap(find.text(_l10n(tester).actionRetry));
      await tester.pump();
      await tester.pump();

      expect(fixture.engine.loadedUrls.length, 2);
    });

    testWidgets('tocAction_whenTapped_listsTheChapters', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await tester.tap(find.byTooltip(_l10n(tester).readerTocAction));
      await tester.pumpAndSettle();

      expect(find.text('第1章'), findsWidgets);
      expect(find.text('第2章'), findsWidgets);
    });

    testWidgets('dispose_whenThePageGoes_pausesThePlayer', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(fixture.engine.pauseCalls, 1);
    });

    testWidgets('build_givenTheLastChapter_disablesNext', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);
      await fixture.container
          .read(readerSessionProvider(_book).notifier)
          .nextChapter();
      await tester.pump();
      await tester.pump();

      final IconButton next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_next),
      );
      expect(next.onPressed, isNull);
    });
  });
}
