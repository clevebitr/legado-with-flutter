import 'dart:async';

import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/repositories/speech_synthesizer.dart';
import 'package:flutter_reader/features/reader/domain/speech_text.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_tts_highlight.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_tts_notifier.freezed.dart';
part 'reader_tts_notifier.g.dart';

/// What the read-aloud sheet shows (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
@freezed
abstract class ReaderTtsState with _$ReaderTtsState {
  /// Creates the read-aloud state.
  const factory ReaderTtsState({
    /// Whether the engine is speaking right now.
    @Default(false) bool isSpeaking,

    /// Whether speech is paused and can be resumed.
    @Default(false) bool isPaused,

    /// Whether the chapter text is being fetched or the first chunk is being prepared.
    @Default(false) bool isPreparing,

    /// The system voices the sheet offers; empty when the platform lists none.
    @Default(<SpeechVoice>[]) List<SpeechVoice> voices,

    /// Speech rate multiplier (1.0 = normal).
    @Default(1.0) double rate,

    /// Speech pitch (1.0 = normal).
    @Default(1.0) double pitch,

    /// The selected voice, or `null` for the platform default.
    SpeechVoice? voice,

    /// Whether leaving the reader stops speech.
    @Default(true) bool stopOnExit,

    /// A failure to explain in the sheet.
    ParseFailure<Never>? failure,
  }) = _ReaderTtsState;

  /// Private constructor so the class may carry the getter below.
  const ReaderTtsState._();

  /// Whether anything is speaking, paused or preparing.
  bool get isActive => isSpeaking || isPaused || isPreparing;
}

/// Reads the open book aloud with the system TTS engine
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
///
/// It watches the session's **chapter index** (not its offset) so the session stays alive while the
/// sheet is closed, and a chapter change is what starts the next chapter. A chapter is split into
/// utterance-sized chunks ([splitSpeechText]), spoken one after another; the last chunk advances the
/// session, which rebuilds this notifier and starts the next chapter.
///
/// The provider is kept alive while it speaks, so “continue after leaving the reader” can work; the
/// sheet's switch (stored as [ReaderSettings.stopTtsOnExit]) decides whether closing the page
/// stops it.
@riverpod
class ReaderTts extends _$ReaderTts {
  SpeechSynthesizer? _engine;
  ReaderBook? _book;
  List<ReadingChapter> _chapters = const <ReadingChapter>[];
  List<SpeechVoice> _voices = const <SpeechVoice>[];
  List<SpeechSegment> _segments = const <SpeechSegment>[];
  int _chunkIndex = 0;
  String _chapterText = '';
  String _chapterUrl = '';
  ReaderSettings? _settings;
  double _rate = 1;
  double _pitch = 1;
  SpeechVoice? _voice;
  String? _storedVoiceName;
  String? _storedVoiceLocale;
  bool _stopOnExit = true;
  bool _settingsLoaded = false;
  bool _built = false;
  bool _continue = false;
  bool _awaitingCompletion = false;
  bool _disposed = false;
  KeepAliveLink? _alive;

  @override
  Future<ReaderTtsState> build(ReaderBook book) async {
    _book = book;
    _built = false;
    _disposed = false;
    final ReaderSettings settings = await ref.read(
      readerSettingsProvider.future,
    );
    _settings = settings;
    if (!_settingsLoaded) {
      _settingsLoaded = true;
      _rate = settings.ttsRate;
      _pitch = settings.ttsPitch;
      _stopOnExit = settings.stopTtsOnExit;
      _storedVoiceName = settings.ttsVoiceName;
      _storedVoiceLocale = settings.ttsVoiceLocale;
    }

    final SpeechSynthesizer engine = ref.watch(speechSynthesizerProvider);
    _engine = engine;
    final StreamSubscription<SpeechSnapshot> subscription = engine.snapshots
        .listen(_onSnapshot);
    ref.onDispose(() {
      _disposed = true;
      unawaited(subscription.cancel());
      // 离开页面且没有 keep-alive 时停读：声音不能从一个已经关闭的页面继续。
      // 只在「还有未读完的块」时停：每章读完会触发一次换章重建，那时平台已经结束发声，
      // 再 stop 一次会多发一个 cancel 快照，可能把新章的 isSpeaking 覆盖成 false。
      if (_continue && _awaitingCompletion) {
        unawaited(engine.stop());
      }
    });

    final ParseResult<List<ReadingChapter>> chaptersResult = await ref.watch(
      readerChaptersProvider(book).future,
    );
    _chapters = switch (chaptersResult) {
      ParseSuccess<List<ReadingChapter>>(:final List<ReadingChapter> data) =>
        data,
      ParseFailure<List<ReadingChapter>>() => const <ReadingChapter>[],
    };
    final int? chapterIndex = ref.watch(readerChapterIndexProvider(book));

    _built = true;
    if (_voices.isEmpty) {
      unawaited(_loadVoices());
    }
    if (_chapters.isEmpty || chapterIndex == null) {
      _continue = false;
      _releaseAlive();
    } else if (_continue) {
      unawaited(_speakCurrentChapter());
    }

    return ReaderTtsState(
      voices: _voices,
      rate: _rate,
      pitch: _pitch,
      voice: _voice,
      stopOnExit: _stopOnExit,
      isPreparing: _continue,
    );
  }

  /// Starts reading the current chapter from its beginning.
  Future<void> start() async {
    final ReaderTtsState? current = state.value;
    if (_engine == null || current == null || current.isActive) {
      return;
    }
    _continue = true;
    _holdAlive();
    state = AsyncData<ReaderTtsState>(
      current.copyWith(isPreparing: true, failure: null),
    );
    await _speakCurrentChapter();
  }

  /// Pauses the current chunk; [resume] continues from the platform's position.
  Future<void> pause() async {
    final SpeechSynthesizer? engine = _engine;
    if (engine == null) {
      return;
    }
    // Android 的 pause 实现是「停止并记住剩余文本」，并不发 `speak.onPause`：
    // 这里先乐观地标成暂停，快照到达时再以平台为准（Windows 会发 onPause）。
    _updateState(
      (ReaderTtsState value) =>
          value.copyWith(isPaused: true, isSpeaking: true),
    );
    await _guard(engine.pause);
  }

  /// Continues a paused chunk.
  ///
  /// Android has no resume call: the plugin remembers the remaining text and a second `speak`
  /// continues it, which is why the **current chunk** is sent again instead of the whole chapter.
  Future<void> resume() async {
    final SpeechSynthesizer? engine = _engine;
    if (engine == null || _segments.isEmpty) {
      return;
    }
    _updateState(
      (ReaderTtsState value) =>
          value.copyWith(isPaused: false, isSpeaking: true, failure: null),
    );
    _awaitingCompletion = true;
    await _guard(
      () => engine.speak(
        _segments[_chunkIndex].text,
        rate: _rate,
        pitch: _pitch,
        voice: _voice,
      ),
    );
  }

  /// Stops reading and releases the keep-alive.
  Future<void> stop() async {
    _continue = false;
    _awaitingCompletion = false;
    _segments = const <SpeechSegment>[];
    _chunkIndex = 0;
    _chapterText = '';
    _chapterUrl = '';
    ref.read(readerTtsHighlighterProvider.notifier).clear();
    _releaseAlive();
    final SpeechSynthesizer? engine = _engine;
    if (engine != null) {
      await _guard(engine.stop);
    }
    final ReaderTtsState? current = state.value;
    if (current != null) {
      state = AsyncData<ReaderTtsState>(
        current.copyWith(
          isSpeaking: false,
          isPaused: false,
          isPreparing: false,
        ),
      );
    }
  }

  /// Sets the speech rate and remembers it.
  Future<void> applyRate(double rate) async {
    _rate = rate.clamp(minTtsRate, maxTtsRate);
    _updateState((ReaderTtsState value) => value.copyWith(rate: _rate));
    await _persist((ReaderSettings value) => value.copyWith(ttsRate: _rate));
  }

  /// Sets the pitch and remembers it.
  Future<void> applyPitch(double pitch) async {
    _pitch = pitch.clamp(minTtsPitch, maxTtsPitch);
    _updateState((ReaderTtsState value) => value.copyWith(pitch: _pitch));
    await _persist((ReaderSettings value) => value.copyWith(ttsPitch: _pitch));
  }

  /// Selects a system voice, or the platform default when [voice] is `null`.
  Future<void> applyVoice(SpeechVoice? voice) async {
    _voice = voice;
    _storedVoiceName = voice?.name;
    _storedVoiceLocale = voice?.locale;
    _updateState((ReaderTtsState value) => value.copyWith(voice: voice));
    await _persist(
      (ReaderSettings value) => value.copyWith(
        ttsVoiceName: voice?.name,
        ttsVoiceLocale: voice?.locale,
        clearTtsVoice: voice == null,
      ),
    );
  }

  /// Chooses whether leaving the reader stops speech.
  Future<void> applyStopOnExit(bool stop) async {
    _stopOnExit = stop;
    _updateState((ReaderTtsState value) => value.copyWith(stopOnExit: stop));
    await _persist(
      (ReaderSettings value) => value.copyWith(stopTtsOnExit: stop),
    );
  }

  /// Called from the reader page's `dispose`.
  ///
  /// The default is to stop (ADR-0054 §决策 5): a page that is gone must not leave a voice with no
  /// visible source. When the switch is off the notifier keeps its keep-alive link and goes on.
  void onReaderClosed() {
    if (_disposed || !_stopOnExit) {
      return;
    }
    unawaited(stop());
  }

  /// Fetches the current chapter's text and starts from its first chunk.
  Future<void> _speakCurrentChapter() async {
    final ReaderBook? book = _book;
    final SpeechSynthesizer? engine = _engine;
    if (book == null || engine == null || !_continue) {
      return;
    }
    final ReaderSessionState? session = ref
        .read(readerSessionProvider(book))
        .value;
    if (session == null || _chapters.isEmpty) {
      _fail(kind: ParseFailureKind.parseFailed, rulePath: 'reader.ttsChapter');

      return;
    }
    final int index = session.chapterIndex.clamp(0, _chapters.length - 1);
    final ReadingChapter chapter = _chapters[index];
    _chapterUrl = chapter.url;
    final ParseResult<String> content = await ref.read(
      readerContentProvider((book, chapter.url)).future,
    );
    if (!_continue) {
      return;
    }
    switch (content) {
      case ParseFailure<String>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        _fail(kind: kind, rulePath: rulePath);
      case ParseSuccess<String>(:final String data):
        // 与阅读页同一份排版后的正文（`readerBodyText`）：高亮的偏移必须落在**渲染出来的**
        // 那段文字上，否则缩进与段距会把位置推偏（ADR-0057 §决策 5）。
        _chapterText = readerBodyText(data, _settings ?? ReaderSettings());
        _segments = splitSpeechSegments(_chapterText);
        _chunkIndex = 0;
        ref.read(readerTtsHighlighterProvider.notifier).clear();
        if (_segments.isEmpty) {
          _fail(kind: ParseFailureKind.parseFailed, rulePath: 'reader.ttsText');

          return;
        }
        await _speakChunk();
    }
  }

  /// Speaks [_chunkIndex] of [_segments].
  Future<void> _speakChunk() async {
    final SpeechSynthesizer? engine = _engine;
    final ReaderTtsState? current = state.value;
    if (engine == null || current == null || _segments.isEmpty) {
      return;
    }
    _awaitingCompletion = true;
    state = AsyncData<ReaderTtsState>(
      current.copyWith(
        isPreparing: false,
        isSpeaking: true,
        isPaused: false,
        failure: null,
      ),
    );
    _announce(_segments[_chunkIndex].start);
    final ParseResult<void> result = await engine.speak(
      _segments[_chunkIndex].text,
      rate: _rate,
      pitch: _pitch,
      voice: _voice,
    );
    if (result case ParseFailure<void>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      _fail(kind: kind, rulePath: rulePath);
    }
  }

  /// Applies one engine snapshot.
  void _onSnapshot(SpeechSnapshot snapshot) {
    if (!_built || !ref.mounted) {
      return;
    }
    final ReaderTtsState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<ReaderTtsState>(
      current.copyWith(
        isSpeaking: snapshot.isSpeaking,
        isPaused: snapshot.isPaused,
        failure: snapshot.failure,
      ),
    );
    if (snapshot.failure != null) {
      _continue = false;
      _releaseAlive();

      return;
    }
    final SpeechRange? spoken = snapshot.spokenRange;
    if (spoken != null &&
        _awaitingCompletion &&
        !snapshot.isCompleted &&
        !snapshot.isPaused &&
        _chunkIndex < _segments.length) {
      // 引擎报的是**当前这一段**里的偏移，加上段起点才是正文里的位置。
      _announce(_segments[_chunkIndex].start + spoken.start);
    }
    if (snapshot.isCompleted && _awaitingCompletion) {
      _awaitingCompletion = false;
      unawaited(_onChunkCompleted());
    }
  }

  /// Highlights the sentence of the chapter body that contains [offset].
  void _announce(int offset) {
    if (_chapterText.isEmpty) {
      return;
    }
    final SpeechSegment sentence = speechSentenceAt(_chapterText, offset);
    if (sentence.end <= sentence.start) {
      return;
    }
    ref
        .read(readerTtsHighlighterProvider.notifier)
        .show(
          chapterUrl: _chapterUrl,
          start: sentence.start,
          end: sentence.end,
        );
  }

  /// Speaks the next chunk, or advances to the next chapter after the last one.
  Future<void> _onChunkCompleted() async {
    if (!_continue) {
      return;
    }
    if (_chunkIndex + 1 < _segments.length) {
      _chunkIndex++;
      await _speakChunk();

      return;
    }
    final ReaderBook? book = _book;
    final ReaderSessionState? session = book == null
        ? null
        : ref.read(readerSessionProvider(book)).value;
    if (book == null || session == null) {
      await stop();

      return;
    }
    if (session.chapterIndex + 1 >= _chapters.length) {
      await stop();

      return;
    }
    // 换章会让本 notifier 重建（它 watch 章节索引），新 build 会接着读下一章。
    _continue = true;
    await ref.read(readerSessionProvider(book).notifier).nextChapter();
  }

  /// Reads the engine's voice list and resolves the stored selection.
  Future<void> _loadVoices() async {
    final SpeechSynthesizer? engine = _engine;
    if (engine == null) {
      return;
    }
    final ParseResult<List<SpeechVoice>> result = await engine.voices();
    if (!ref.mounted) {
      return;
    }
    if (result case ParseSuccess<List<SpeechVoice>>(
      :final List<SpeechVoice> data,
    )) {
      _voices = data;
      if (_voice == null && _storedVoiceName != null) {
        for (final SpeechVoice voice in data) {
          if (voice.name == _storedVoiceName &&
              (voice.locale == _storedVoiceLocale ||
                  _storedVoiceLocale == null)) {
            _voice = voice;
            break;
          }
        }
      }
      _updateState(
        (ReaderTtsState value) => value.copyWith(voices: data, voice: _voice),
      );
    } else {
      ref
          .read(appLoggerProvider)
          .warning('The system TTS voice list could not be read.');
    }
  }

  /// Runs a speech command, turning a failure into state.
  Future<void> _guard(Future<ParseResult<void>> Function() command) async {
    try {
      final ParseResult<void> result = await command();
      if (result case ParseFailure<void>(
        :final ParseFailureKind kind,
        :final String rulePath,
      )) {
        _fail(kind: kind, rulePath: rulePath);
      }
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('A speech command failed.', error, stackTrace);
      _fail(kind: ParseFailureKind.parseFailed, rulePath: 'reader.tts');
    }
  }

  /// Persists one TTS setting through the reader settings notifier.
  Future<void> _persist(ReaderSettings Function(ReaderSettings) update) async {
    try {
      final ReaderSettings settings = await ref.read(
        readerSettingsProvider.future,
      );
      await ref.read(readerSettingsProvider.notifier).apply(update(settings));
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('Saving a TTS setting failed.', error, stackTrace);
    }
  }

  /// Puts a failure into the state and stops the reading loop.
  void _fail({required ParseFailureKind kind, required String rulePath}) {
    _continue = false;
    _awaitingCompletion = false;
    _releaseAlive();
    final ReaderTtsState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<ReaderTtsState>(
      current.copyWith(
        isSpeaking: false,
        isPaused: false,
        isPreparing: false,
        failure: ParseFailure<Never>(kind: kind, rulePath: rulePath),
      ),
    );
  }

  /// Applies [update] to the current state, if there is one.
  void _updateState(ReaderTtsState Function(ReaderTtsState) update) {
    final ReaderTtsState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<ReaderTtsState>(update(current));
  }

  /// Keeps the notifier alive while it speaks, so leaving the page can keep reading.
  void _holdAlive() => _alive ??= ref.keepAlive();

  /// Releases the keep-alive link.
  void _releaseAlive() {
    _alive?.close();
    _alive = null;
  }
}
