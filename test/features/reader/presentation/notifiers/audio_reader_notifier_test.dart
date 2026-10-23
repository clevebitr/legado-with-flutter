import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/audio_reader_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_audio_ports.dart';
import '../../../../support/fake_clock.dart';
import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_reader_ports.dart';

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
  FakeAudioTrackProvider tracks,
  FakeReadingProgressStore progress,
  FakeClock clock,
});

/// Builds a container around the reader ports and the audio doubles.
_Fixture _fixture({
  bool twoTracks = false,
  bool plainHttpTrack = false,
  bool allowPlainHttp = false,
}) {
  final FakeChapterListProvider chapters = FakeChapterListProvider()
    ..chapters = _chapters;
  final FakeChapterContentProvider content = FakeChapterContentProvider()
    ..bodies['https://source.test/1.html'] = '第一章正文'
    ..bodies['https://source.test/2.html'] = '第二章正文';
  final FakeReadingProgressStore progress = FakeReadingProgressStore();
  final FakeAudioTrackProvider tracks = FakeAudioTrackProvider()
    ..tracks['https://source.test/1.html'] = <ReaderAudioTrack>[
      ReaderAudioTrack(
        url: plainHttpTrack
            ? 'http://cdn.test/1.mp3'
            : 'https://cdn.test/1.mp3',
      ),
      if (twoTracks) const ReaderAudioTrack(url: 'https://cdn.test/1b.mp3'),
    ]
    ..tracks['https://source.test/2.html'] = <ReaderAudioTrack>[
      const ReaderAudioTrack(url: 'https://cdn.test/2.mp3'),
    ];
  final FakeAudioPlaybackEngine engine = FakeAudioPlaybackEngine();
  final FakeClock clock = FakeClock();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      readerChapterListProvider.overrideWithValue(chapters),
      readerChapterContentProvider.overrideWithValue(content),
      readerProgressStoreProvider.overrideWithValue(progress),
      readerAudioTrackProvider.overrideWithValue(tracks),
      audioPlaybackEngineProvider.overrideWithValue(engine),
      playbackNotificationProvider.overrideWithValue(
        const NoopPlaybackNotification(),
      ),
      clockProvider.overrideWithValue(clock),
      plainHttpSettingProvider.overrideWithValue(allowPlainHttp),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(
    audioReaderProvider(_book),
    (_, _) {},
    fireImmediately: true,
  );

  return (
    container: container,
    engine: engine,
    tracks: tracks,
    progress: progress,
    clock: clock,
  );
}

/// Awaits the notifier's current build.
Future<void> _open(_Fixture fixture) async {
  await fixture.container.read(audioReaderProvider(_book).future);
  await pumpEventQueue();
}

/// Reads the current state, failing when it is not loaded.
AudioReaderState _state(_Fixture fixture) {
  final AsyncValue<AudioReaderState> value = fixture.container.read(
    audioReaderProvider(_book),
  );

  return switch (value) {
    AsyncData<AudioReaderState>(:final AudioReaderState value) => value,
    _ => fail('The audio reader is not loaded.'),
  };
}

void main() {
  group('AudioReader', () {
    test('build_givenAnAudioChapter_loadsItsFirstTrack', () async {
      final _Fixture fixture = _fixture();

      await _open(fixture);

      expect(fixture.engine.loadedUrls, <String>['https://cdn.test/1.mp3']);
      expect(_state(fixture).tracks, hasLength(1));
      expect(_state(fixture).isPlaying, isFalse);
    });

    test('toggle_whenPaused_playsAndMirrorsTheSnapshots', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);

      await fixture.container
          .read(audioReaderProvider(_book).notifier)
          .toggle();
      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          position: Duration(seconds: 3),
          duration: Duration(seconds: 30),
        ),
      );
      await pumpEventQueue();

      expect(fixture.engine.playCalls, 1);
      expect(_state(fixture).isPlaying, isTrue);
      expect(_state(fixture).duration, const Duration(seconds: 30));
      // 首次快照立刻落一次盘：偏移列按毫秒解释（ADR-0054 §决策 4）。
      expect(fixture.progress.writes.single.charOffset, 3000);
    });

    test('snapshot_whenPlaybackStops_savesThePosition', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          position: Duration(seconds: 3),
          duration: Duration(seconds: 30),
        ),
      );
      await pumpEventQueue();

      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          position: Duration(seconds: 4),
          duration: Duration(seconds: 30),
        ),
      );
      await pumpEventQueue();

      expect(fixture.progress.writes.last.charOffset, 4000);
    });

    test('snapshot_whenLessThanTheIntervalPassed_doesNotWriteAgain', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          position: Duration(seconds: 1),
          duration: Duration(seconds: 30),
        ),
      );
      await pumpEventQueue();
      final int writes = fixture.progress.writes.length;

      fixture.clock.advance(const Duration(seconds: 2));
      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          position: Duration(seconds: 2),
          duration: Duration(seconds: 30),
        ),
      );
      await pumpEventQueue();
      expect(fixture.progress.writes, hasLength(writes));

      fixture.clock.advance(audioProgressWriteInterval);
      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          position: Duration(seconds: 3),
          duration: Duration(seconds: 30),
        ),
      );
      await pumpEventQueue();
      expect(fixture.progress.writes, hasLength(writes + 1));
    });

    test(
      'nextChapter_whenPlaying_loadsTheNextChapterAndKeepsPlaying',
      () async {
        final _Fixture fixture = _fixture();
        await _open(fixture);
        await fixture.container
            .read(audioReaderProvider(_book).notifier)
            .toggle();
        fixture.engine.emit(
          const AudioPlaybackSnapshot(
            isPlaying: true,
            duration: Duration(seconds: 30),
          ),
        );
        await pumpEventQueue();

        await fixture.container
            .read(audioReaderProvider(_book).notifier)
            .nextChapter();
        await _open(fixture);

        expect(fixture.engine.loadedUrls.last, 'https://cdn.test/2.mp3');
        expect(fixture.engine.playCalls, 2);
        final ReaderSessionState session = await fixture.container.read(
          readerSessionProvider(_book).future,
        );
        expect(session.chapterIndex, 1);
      },
    );

    test('snapshot_whenTheLastTrackCompleted_opensTheNextChapter', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);

      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          isCompleted: true,
          position: Duration(seconds: 30),
          duration: Duration(seconds: 30),
        ),
      );
      await pumpEventQueue();
      await _open(fixture);

      expect(fixture.engine.loadedUrls, <String>[
        'https://cdn.test/1.mp3',
        'https://cdn.test/2.mp3',
      ]);
    });

    test('snapshot_whenAChapterHasTwoTracks_playsTheSecondFirst', () async {
      final _Fixture fixture = _fixture(twoTracks: true);
      await _open(fixture);

      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          isCompleted: true,
          duration: Duration(seconds: 30),
        ),
      );
      await pumpEventQueue();

      expect(fixture.engine.loadedUrls.last, 'https://cdn.test/1b.mp3');
      expect(_state(fixture).trackIndex, 1);
      final ReaderSessionState session = await fixture.container.read(
        readerSessionProvider(_book).future,
      );
      expect(session.chapterIndex, 0);
    });

    test('build_givenALoadFailure_showsTheFailure', () async {
      final _Fixture fixture = _fixture();
      fixture.engine.loadFailure = ParseFailureKind.networkFailed;

      await _open(fixture);

      expect(_state(fixture).failure?.kind, ParseFailureKind.networkFailed);
      expect(_state(fixture).failure?.rulePath, 'reader.audioPlayer');
    });

    test('build_givenAPlainHttpTrack_blocksUntilTheUserOptsIn', () async {
      final _Fixture fixture = _fixture(plainHttpTrack: true);

      await _open(fixture);

      expect(fixture.engine.loadedUrls, isEmpty);
      expect(_state(fixture).failure?.rulePath, 'reader.audioPlainHttp');
    });

    test('build_givenAPlainHttpTrackAndTheSwitchOn_loadsIt', () async {
      final _Fixture fixture = _fixture(
        plainHttpTrack: true,
        allowPlainHttp: true,
      );

      await _open(fixture);

      expect(fixture.engine.loadedUrls, <String>['http://cdn.test/1.mp3']);
      expect(_state(fixture).failure, isNull);
    });

    test('build_givenATrackFailure_showsIt', () async {
      final _Fixture fixture = _fixture();
      fixture.tracks.failures['https://source.test/1.html'] =
          ParseFailureKind.parseFailed;

      await _open(fixture);

      expect(_state(fixture).failure?.rulePath, 'reader.audioTracks');
    });

    test('seek_whenAsked_seeksAndSavesTheMillisecondOffset', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      fixture.engine.emit(
        const AudioPlaybackSnapshot(duration: Duration(seconds: 30)),
      );
      await pumpEventQueue();

      await fixture.container
          .read(audioReaderProvider(_book).notifier)
          .seek(const Duration(seconds: 5));
      await pumpEventQueue();

      expect(fixture.engine.seeks, <Duration>[const Duration(seconds: 5)]);
      expect(fixture.progress.writes.last.charOffset, 5000);
    });

    test('setSpeed_whenChanged_persistsForTheNextChapter', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);

      await fixture.container
          .read(audioReaderProvider(_book).notifier)
          .setSpeed(1.5);
      expect(fixture.engine.speeds, <double>[1.5]);
      expect(_state(fixture).speed, 1.5);
    });

    test('onReaderClosed_whenThePageGoes_pausesAndSaves', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      fixture.engine.emit(
        const AudioPlaybackSnapshot(
          isPlaying: true,
          position: Duration(seconds: 8),
          duration: Duration(seconds: 30),
        ),
      );
      await pumpEventQueue();

      await fixture.container
          .read(audioReaderProvider(_book).notifier)
          .onReaderClosed();

      expect(fixture.engine.pauseCalls, 1);
      expect(fixture.progress.writes.last.charOffset, 8000);
    });
  });
}
