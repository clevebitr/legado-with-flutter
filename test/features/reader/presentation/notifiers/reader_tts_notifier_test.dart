import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/repositories/speech_synthesizer.dart';
import 'package:flutter_reader/features/reader/domain/speech_text.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_tts_highlight.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_tts_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_audio_ports.dart';
import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_reader_ports.dart';

/// The book every case opens.
const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '剑来',
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
  FakeSpeechSynthesizer speech,
  FakeReaderSettingsRepository settings,
});

/// Builds a container around the reader ports and the speech double.
_Fixture _fixture({
  ReaderSettings? settings,
  String chapterOneBody = '第一句。第二句。',
}) {
  final FakeChapterListProvider chapters = FakeChapterListProvider()
    ..chapters = _chapters;
  final FakeChapterContentProvider content = FakeChapterContentProvider()
    ..bodies['https://source.test/1.html'] = chapterOneBody
    ..bodies['https://source.test/2.html'] = '第二章内容。';
  final FakeReaderSettingsRepository readerSettings =
      FakeReaderSettingsRepository(initial: settings);
  final FakeSpeechSynthesizer speech = FakeSpeechSynthesizer()
    ..voicesOf = const <SpeechVoice>[
      SpeechVoice(name: 'Microsoft Huihui', locale: 'zh-CN'),
    ];
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      readerChapterListProvider.overrideWithValue(chapters),
      readerChapterContentProvider.overrideWithValue(content),
      readerProgressStoreProvider.overrideWithValue(FakeReadingProgressStore()),
      readerSettingsRepositoryProvider.overrideWith(
        (Ref ref) async => readerSettings,
      ),
      speechSynthesizerProvider.overrideWithValue(speech),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(readerTtsProvider(_book), (_, _) {}, fireImmediately: true);

  return (container: container, speech: speech, settings: readerSettings);
}

/// Awaits the notifier's current build and its voice loading.
Future<void> _open(_Fixture fixture) async {
  await fixture.container.read(readerTtsProvider(_book).future);
  await pumpEventQueue();
}

/// Reads the current state, failing when it is not loaded.
ReaderTtsState _state(_Fixture fixture) {
  final AsyncValue<ReaderTtsState> value = fixture.container.read(
    readerTtsProvider(_book),
  );

  return switch (value) {
    AsyncData<ReaderTtsState>(:final ReaderTtsState value) => value,
    _ => fail('The TTS notifier is not loaded.'),
  };
}

/// The notifier under test.
ReaderTts _notifier(_Fixture fixture) =>
    fixture.container.read(readerTtsProvider(_book).notifier);

/// The sentence the reader would highlight right now (ADR-0057 §决策 5).
ReaderTtsHighlight? _highlight(_Fixture fixture) =>
    fixture.container.read(readerTtsHighlighterProvider);

void main() {
  group('ReaderTts', () {
    test('build_givenSettings_loadsVoicesAndTheSpeechAxes', () async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(
          ttsRate: 1.5,
          ttsPitch: 0.8,
          ttsVoiceName: 'Microsoft Huihui',
          ttsVoiceLocale: 'zh-CN',
          stopTtsOnExit: false,
        ),
      );

      await _open(fixture);

      final ReaderTtsState state = _state(fixture);
      expect(state.rate, 1.5);
      expect(state.pitch, 0.8);
      expect(state.stopOnExit, isFalse);
      expect(state.voice?.name, 'Microsoft Huihui');
      expect(state.voices, hasLength(1));
    });

    test('start_givenAChapter_speaksItsText', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);

      await _notifier(fixture).start();
      await pumpEventQueue();

      expect(fixture.speech.spoken, <String>['第一句。第二句。']);
      expect(fixture.speech.rates.single, 1);
      expect(_state(fixture).isSpeaking, isTrue);
      expect(_state(fixture).isPreparing, isFalse);
    });

    test('pause_thenResume_keepsTheCurrentChunk', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      await _notifier(fixture).pause();
      expect(fixture.speech.pauseCalls, 1);
      expect(_state(fixture).isPaused, isTrue);

      await _notifier(fixture).resume();
      await pumpEventQueue();
      // Android 没有 resume：续播就是重发**当前块**（插件记住剩余文本）。
      expect(fixture.speech.spoken, <String>['第一句。第二句。', '第一句。第二句。']);
      expect(_state(fixture).isPaused, isFalse);
    });

    test('stop_whenAsked_stopsTheEngineAndClearsTheState', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      await _notifier(fixture).stop();

      expect(fixture.speech.stopCalls, 1);
      expect(_state(fixture).isActive, isFalse);
    });

    test('snapshot_whenTheChapterFinished_opensTheNextChapter', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      fixture.speech.emit(const SpeechSnapshot(isCompleted: true));
      await pumpEventQueue(times: 30);
      await _open(fixture);
      await pumpEventQueue(times: 30);

      final ReaderSessionState session = await fixture.container.read(
        readerSessionProvider(_book).future,
      );
      expect(session.chapterIndex, 1);
      expect(fixture.speech.spoken.last, '第二章内容。');
    });

    test('snapshot_whenTheLastChapterFinished_stops', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      // 先走到最后一章。
      await fixture.container
          .read(readerSessionProvider(_book).notifier)
          .nextChapter();
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      fixture.speech.emit(const SpeechSnapshot(isCompleted: true));
      await pumpEventQueue(times: 30);

      expect(fixture.speech.stopCalls, 1);
      expect(_state(fixture).isActive, isFalse);
    });

    test('snapshot_whenAChapterHasSeveralChunks_speaksThemInOrder', () async {
      final _Fixture fixture = _fixture(
        chapterOneBody: '字' * (maxSpeechChunkLength + 5),
      );
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      fixture.speech.emit(const SpeechSnapshot(isCompleted: true));
      await pumpEventQueue(times: 20);

      expect(fixture.speech.spoken, hasLength(2));
      expect(fixture.speech.spoken.first.length, maxSpeechChunkLength);
      expect(fixture.speech.spoken.last.length, 5);
    });

    test('start_givenASpeakFailure_showsTheFailure', () async {
      final _Fixture fixture = _fixture();
      fixture.speech.speakFailure = ParseFailureKind.unsupportedRule;
      await _open(fixture);

      await _notifier(fixture).start();
      await pumpEventQueue();

      expect(_state(fixture).failure?.kind, ParseFailureKind.unsupportedRule);
      expect(_state(fixture).isActive, isFalse);
    });

    test('applyRate_andApplyPitch_persistThem', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);

      await _notifier(fixture).applyRate(1.5);
      await _notifier(fixture).applyPitch(0.75);

      expect(_state(fixture).rate, 1.5);
      expect(_state(fixture).pitch, 0.75);
      expect(fixture.settings.stored.ttsRate, 1.5);
      expect(fixture.settings.stored.ttsPitch, 0.75);
    });

    test('applyVoice_whenGivenTheSystemDefault_clearsTheStoredVoice', () async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(
          ttsVoiceName: 'Microsoft Huihui',
          ttsVoiceLocale: 'zh-CN',
        ),
      );
      await _open(fixture);

      await _notifier(fixture).applyVoice(null);
      await pumpEventQueue();

      expect(_state(fixture).voice, isNull);
      expect(fixture.settings.stored.ttsVoiceName, isNull);
      expect(fixture.settings.stored.ttsVoiceLocale, isNull);
    });

    test('applyStopOnExit_whenTurnedOff_persistsIt', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);

      await _notifier(fixture).applyStopOnExit(false);

      expect(_state(fixture).stopOnExit, isFalse);
      expect(fixture.settings.stored.stopTtsOnExit, isFalse);
    });

    test('onReaderClosed_whenStopOnExit_stopsSpeaking', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      _notifier(fixture).onReaderClosed();
      await pumpEventQueue();

      expect(fixture.speech.stopCalls, 1);
    });

    test('onReaderClosed_whenTheSwitchIsOff_keepsSpeaking', () async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(stopTtsOnExit: false),
      );
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      _notifier(fixture).onReaderClosed();
      await pumpEventQueue();

      expect(fixture.speech.stopCalls, 0);
    });

    test('start_givenAChapter_highlightsItsFirstSentence', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);

      await _notifier(fixture).start();
      await pumpEventQueue();

      // 读声用的正文是**排版后**的（段首缩进已就位），所以第一句从偏移 2 开始。
      final ReaderTtsHighlight? highlight = _highlight(fixture);
      expect(highlight?.chapterUrl, 'https://source.test/1.html');
      expect(highlight?.start, 2);
      expect(highlight?.end, 6);
    });

    test('progress_givenTheSecondSentence_movesTheHighlight', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      // 引擎报的是**当前这一段**里的偏移（'第二句。' 在块里从第 4 个字开始）。
      fixture.speech.emit(
        const SpeechSnapshot(
          isSpeaking: true,
          spokenRange: SpeechRange(start: 4, end: 8),
        ),
      );
      await pumpEventQueue();

      final ReaderTtsHighlight? highlight = _highlight(fixture);
      expect(highlight?.start, 6);
      expect(highlight?.end, 10);
    });

    test('stop_clearsTheHighlight', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      await _notifier(fixture).stop();
      await pumpEventQueue();

      expect(_highlight(fixture), isNull);
    });

    test('nextChapter_highlightsTheNextChaptersSentence', () async {
      final _Fixture fixture = _fixture();
      await _open(fixture);
      await _notifier(fixture).start();
      await pumpEventQueue();

      // 每章读完会触发换章重建；新一章的第一句必须带上新章的地址，否则高亮会落在旧正文上。
      fixture.speech.emit(
        const SpeechSnapshot(isSpeaking: false, isCompleted: true),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      expect(_highlight(fixture)?.chapterUrl, 'https://source.test/2.html');
    });
  });
}
