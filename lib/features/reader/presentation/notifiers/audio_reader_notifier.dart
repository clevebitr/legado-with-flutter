import 'dart:async';

import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_reader_notifier.freezed.dart';
part 'audio_reader_notifier.g.dart';

/// How often the player writes the millisecond position while it keeps playing.
///
/// The text reader writes on scroll end; audio has no such event, and writing every snapshot
/// would write the progress row five times a second. Five seconds is the same order as the
/// position the shelf shows and survives a process kill well enough (ADR-0054 §决策 4).
const Duration audioProgressWriteInterval = Duration(seconds: 5);

/// The audio reader's state (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
///
/// [position] / [duration] are the **current track's**; the chapter-level position written to
/// `reading_progress` is [position] in milliseconds, which is why the text reader's character
/// estimate and this value never mean the same thing (ADR-0054 §决策 4).
@freezed
abstract class AudioReaderState with _$AudioReaderState {
  /// Creates the audio reader state.
  const factory AudioReaderState({
    /// The current chapter's tracks, in rule order.
    @Default(<ReaderAudioTrack>[]) List<ReaderAudioTrack> tracks,

    /// Index into [tracks].
    @Default(0) int trackIndex,

    /// Whether audio is advancing right now.
    @Default(false) bool isPlaying,

    /// Whether a track is being fetched or prepared.
    @Default(false) bool isLoading,

    /// Whether the player reported buffering.
    @Default(false) bool isBuffering,

    /// Whether the current track finished.
    @Default(false) bool isCompleted,

    /// Position inside the current track.
    @Default(Duration.zero) Duration position,

    /// Duration of the current track, or `null` before the player decodes it.
    Duration? duration,

    /// Playback speed (1.0 = normal).
    @Default(1.0) double speed,

    /// A failure to show instead of the controls' normal labels.
    ParseFailure<Never>? failure,
  }) = _AudioReaderState;

  /// Private constructor so the class may carry the getters below.
  const AudioReaderState._();

  /// Whether there is a track to play.
  bool get hasTrack => tracks.isNotEmpty && trackIndex < tracks.length;
}

/// Reads one chapter's audio tracks for the player (`docs/dev/roadmap.md` §3.10).
///
/// Like the text content provider, it is keyed by the chapter so leaving the chapter disposes the
/// request instead of writing into a dead notifier.
@riverpod
Future<ParseResult<List<ReaderAudioTrack>>> readerAudioTracks(
  Ref ref,
  (ReaderBook, ReadingChapter) request,
) => ref
    .watch(readerAudioTrackProvider)
    .fetch(
      sourceUrl: request.$1.sourceUrl,
      chapterUrl: request.$2.url,
      bookName: request.$1.name,
      chapterTitle: request.$2.title,
      bookUrl: request.$1.bookUrl,
      tocUrl: request.$1.tocUrl,
    );

/// Plays the current chapter of [book] (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
///
/// It is keyed by the book and rebuilds when the session's **chapter index** changes. It does not
/// watch the whole session value: every five seconds the offset changes, and a rebuild would
/// re-load the track and restart playback from the beginning.
///
/// The engine is watched from [audioPlaybackEngineProvider], which owns its disposal, so a chapter
/// switch keeps the same native player while a page exit releases it.
@riverpod
class AudioReader extends _$AudioReader {
  AudioPlaybackEngine? _engine;
  bool _built = false;
  AudioPlaybackSnapshot? _pending;
  List<ReadingChapter> _chapters = const <ReadingChapter>[];
  ReaderBook? _book;
  double _speed = 1;
  DateTime? _lastWrite;
  bool _wasPlaying = false;
  bool _completedHandled = false;
  bool _autoPlay = false;
  bool _restored = false;
  PlaybackNotification? _notification;
  PlaybackNotificationHandle? _handle;
  bool _allowPlainHttp = false;

  @override
  Future<AudioReaderState> build(ReaderBook book) async {
    _book = book;
    _built = false;
    _pending = null;
    _notification = ref.watch(playbackNotificationProvider);
    _allowPlainHttp = ref.watch(plainHttpSettingProvider);
    final ParseResult<List<ReadingChapter>> chaptersResult = await ref.watch(
      readerChaptersProvider(book).future,
    );
    final List<ReadingChapter> chapters;
    switch (chaptersResult) {
      case ParseFailure<List<ReadingChapter>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return AudioReaderState(
          failure: ParseFailure<Never>(kind: kind, rulePath: rulePath),
        );
      case ParseSuccess<List<ReadingChapter>>(:final List<ReadingChapter> data):
        chapters = data;
    }
    _chapters = chapters;

    // 只订阅「章节索引」：进度毫秒每 5 s 变一次，watch 整个 state 会重载音轨。
    final int? chapterIndex = ref.watch(readerChapterIndexProvider(book));
    if (chapterIndex == null || chapters.isEmpty) {
      return AudioReaderState(isLoading: chapterIndex == null);
    }
    if (chapterIndex >= chapters.length) {
      return const AudioReaderState();
    }
    final ReadingChapter chapter = chapters[chapterIndex];

    final ParseResult<List<ReaderAudioTrack>> tracksResult = await ref.watch(
      readerAudioTracksProvider((book, chapter)).future,
    );
    final List<ReaderAudioTrack> tracks;
    switch (tracksResult) {
      case ParseFailure<List<ReaderAudioTrack>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return AudioReaderState(
          failure: ParseFailure<Never>(kind: kind, rulePath: rulePath),
        );
      case ParseSuccess<List<ReaderAudioTrack>>(
        :final List<ReaderAudioTrack> data,
      ):
        tracks = data;
    }

    final ParseFailure<Never>? plainHttp = _plainHttpFailureFor(
      tracks.first.url,
      _allowPlainHttp,
    );
    if (plainHttp != null) {
      return AudioReaderState(tracks: tracks, failure: plainHttp);
    }

    final AudioPlaybackEngine engine = ref.watch(audioPlaybackEngineProvider);
    _engine = engine;
    final StreamSubscription<AudioPlaybackSnapshot> subscription = engine
        .snapshots
        .listen(_onSnapshot);
    ref.onDispose(() => unawaited(subscription.cancel()));

    final ParseResult<void> load = await _command(
      () => engine.load(url: tracks.first.url, headers: tracks.first.headers),
    );
    if (_speed != 1) {
      // 换章保留倍速：这是用户的稳定偏好，不是每章重选的选项。
      unawaited(engine.setSpeed(_speed));
    }

    // 恢复进度只在**第一次**装载时做：换章时 session 已把偏移清零，
    // 再 seek 旧值会把新章拖回旧位置。
    final ReaderSessionState? session = ref
        .read(readerSessionProvider(book))
        .value;
    if (!_restored && load is ParseSuccess<void> && session != null) {
      _restored = true;
      if (session.charOffset > 0) {
        unawaited(engine.seek(Duration(milliseconds: session.charOffset)));
      }
    }
    final bool autoPlay = _autoPlay;
    _autoPlay = false;
    if (autoPlay) {
      unawaited(_command(engine.play));
    }

    final AudioPlaybackSnapshot? pending = _pending;
    _built = true;
    _pending = null;
    _completedHandled = false;
    _wasPlaying = pending?.isPlaying ?? autoPlay;

    unawaited(_attachNotification());
    final AudioReaderState initial = AudioReaderState(
      tracks: tracks,
      speed: _speed,
      isPlaying: pending?.isPlaying ?? autoPlay,
      position: pending?.position ?? Duration.zero,
      duration: pending?.duration,
      failure: switch (load) {
        ParseFailure<void>(:final ParseFailureKind kind, :final rulePath) =>
          ParseFailure<Never>(kind: kind, rulePath: rulePath),
        ParseSuccess<void>() => pending?.failure,
      },
      isCompleted: pending?.isCompleted ?? false,
    );
    unawaited(_syncNotification(initial));

    return initial;
  }

  /// Starts or pauses playback, depending on what the player is doing now.
  Future<void> toggle() async {
    final AudioReaderState? current = state.value;
    final AudioPlaybackEngine? engine = _engine;
    if (current == null || engine == null || !current.hasTrack) {
      return;
    }
    if (current.isPlaying) {
      await _command(engine.pause);
      await _saveProgress();

      return;
    }
    if (current.position >= (current.duration ?? Duration.zero)) {
      await _command(() => engine.seek(Duration.zero));
    }
    await _command(engine.play);
    unawaited(_syncNotification());
  }

  /// Moves the playhead and remembers it.
  Future<void> seek(Duration position) async {
    final AudioReaderState? current = state.value;
    final AudioPlaybackEngine? engine = _engine;
    if (current == null || engine == null) {
      return;
    }
    state = AsyncData<AudioReaderState>(current.copyWith(position: position));
    await _command(() => engine.seek(position));
    // 拖动进度条不产生位置快照（播放器只在 seek 完成后推一帧），所以这里主动把
    // 毫秒偏移交给会话，否则落盘的是**拖动前**的位置。
    final ReaderBook? book = _book;
    if (book != null) {
      ref
          .read(readerSessionProvider(book).notifier)
          .updateOffset(position.inMilliseconds);
    }
    await _saveProgress();
    unawaited(_syncNotification());
  }

  /// Sets the playback speed and keeps it for the following chapters.
  Future<void> setSpeed(double speed) async {
    final AudioPlaybackEngine? engine = _engine;
    final AudioReaderState? current = state.value;
    if (engine == null || current == null) {
      return;
    }
    _speed = speed;
    state = AsyncData<AudioReaderState>(current.copyWith(speed: speed));
    await _command(() => engine.setSpeed(speed));
    unawaited(_syncNotification());
  }

  /// Opens the next chapter and keeps playing when it was playing.
  Future<void> nextChapter() => _switchChapter(next: true);

  /// Opens the previous chapter and keeps playing when it was playing.
  Future<void> previousChapter() => _switchChapter(next: false);

  /// Re-reads the chapter after a failure.
  void retry() => ref.invalidateSelf();

  /// Called when the audio view is disposed: save the position, pause and drop the notification.
  ///
  /// Background playback is about the app being in the background **with the page alive**
  /// (ADR-0054 §决策 4); a page the user left must not keep a voice with no visible source, so this
  /// pauses rather than keeps playing.
  Future<void> onReaderClosed() async {
    await _saveProgress();
    try {
      await _engine?.pause();
      final PlaybackNotificationHandle? handle = _handle;
      _handle = null;
      await handle?.detach();
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('Closing the audio reader failed.', error, stackTrace);
    }
  }

  Future<void> _switchChapter({required bool next}) async {
    final AudioReaderState? current = state.value;
    final ReaderBook? book = _book;
    if (current == null || book == null) {
      return;
    }
    _autoPlay = current.isPlaying;
    final ReaderSession session = ref.read(
      readerSessionProvider(book).notifier,
    );
    if (next) {
      await session.nextChapter();
    } else {
      await session.previousChapter();
    }
  }

  /// Applies one engine snapshot to the state and keeps the progress row warm.
  void _onSnapshot(AudioPlaybackSnapshot snapshot) {
    if (!_built) {
      _pending = snapshot;
      return;
    }
    if (!ref.mounted) {
      return;
    }
    final AudioReaderState? current = state.value;
    if (current == null) {
      return;
    }
    final bool stateChanged =
        current.isPlaying != snapshot.isPlaying ||
        current.isBuffering != snapshot.isBuffering ||
        current.isCompleted != snapshot.isCompleted;
    state = AsyncData<AudioReaderState>(
      current.copyWith(
        isPlaying: snapshot.isPlaying,
        isBuffering: snapshot.isBuffering,
        isCompleted: snapshot.isCompleted,
        position: snapshot.position,
        duration: snapshot.duration,
        failure: snapshot.failure,
      ),
    );
    if (stateChanged) {
      // 通知只需要「不连续点」：播放 / 暂停 / 缓冲 / 片尾。位置由系统按 speed 投影，
      // 每 200 ms 推一次会把通知栏刷成每秒五帧。
      unawaited(_syncNotification());
    }

    if (snapshot.failure == null) {
      _rememberPosition(snapshot.position);
    }
    if (_wasPlaying && !snapshot.isPlaying) {
      // 暂停 / 播放失败 / 播放到片尾都在这里落一次盘，停顿点就是恢复点。
      unawaited(_saveProgress());
    }
    _wasPlaying = snapshot.isPlaying;

    if (snapshot.isCompleted && !_completedHandled) {
      _completedHandled = true;
      unawaited(_advance());
    } else if (!snapshot.isCompleted) {
      _completedHandled = false;
    }
  }

  /// Continues with the next track of this chapter, or the next chapter.
  Future<void> _advance() async {
    final AudioReaderState? current = state.value;
    if (current == null) {
      return;
    }
    if (current.trackIndex + 1 < current.tracks.length) {
      await _playTrack(current.trackIndex + 1);
      return;
    }
    final ReaderBook? book = _book;
    if (book == null || current.tracks.isEmpty) {
      return;
    }
    final ReaderSessionState? session = ref
        .read(readerSessionProvider(book))
        .value;
    final int index = session?.chapterIndex ?? 0;
    if (index + 1 >= _chapters.length) {
      // 最后一章读完：停在片尾，不循环。
      await _saveProgress();
      return;
    }
    _autoPlay = true;
    await ref.read(readerSessionProvider(book).notifier).nextChapter();
  }

  /// Loads [index] of the current chapter and starts it.
  ///
  /// It is only reached when a track finished, so playback always continues: at that moment the
  /// player already reports “not playing”, and resuming the previous flag would stop the chapter.
  Future<void> _playTrack(int index) async {
    final AudioReaderState? current = state.value;
    final AudioPlaybackEngine? engine = _engine;
    if (current == null || engine == null || index >= current.tracks.length) {
      return;
    }
    final ReaderAudioTrack track = current.tracks[index];
    final ParseFailure<Never>? plainHttp = _plainHttpFailureFor(
      track.url,
      _allowPlainHttp,
    );
    if (plainHttp != null) {
      state = AsyncData<AudioReaderState>(
        current.copyWith(failure: plainHttp, isLoading: false),
      );

      return;
    }
    state = AsyncData<AudioReaderState>(
      current.copyWith(
        trackIndex: index,
        position: Duration.zero,
        duration: null,
        isLoading: true,
      ),
    );
    await _command(() => engine.load(url: track.url, headers: track.headers));
    state = AsyncData<AudioReaderState>(
      (state.value ?? current).copyWith(isLoading: false),
    );
    await _command(engine.play);
    unawaited(_syncNotification());
  }

  /// Feeds the session's offset so a chapter switch writes the current millisecond.
  void _rememberPosition(Duration position) {
    final ReaderBook? book = _book;
    if (book == null) {
      return;
    }
    ref
        .read(readerSessionProvider(book).notifier)
        .updateOffset(position.inMilliseconds);

    final DateTime now = ref.read(clockProvider).now();
    final DateTime? last = _lastWrite;
    if (last == null || now.difference(last) >= audioProgressWriteInterval) {
      _lastWrite = now;
      unawaited(_saveProgress());
    }
  }

  /// Writes the current position through the session (which owns the progress port).
  Future<void> _saveProgress() async {
    final ReaderBook? book = _book;
    if (book == null) {
      return;
    }
    _lastWrite = ref.read(clockProvider).now();
    await ref.read(readerSessionProvider(book).notifier).saveProgress();
  }

  /// Binds the media notification once per reader session.
  Future<void> _attachNotification() async {
    final PlaybackNotification? notification = _notification;
    if (notification == null || _handle != null) {
      return;
    }
    try {
      final PlaybackNotificationHandle? handle = await notification.attach(
        controls: PlaybackNotificationControls(
          onPlay: () => unawaited(toggle()),
          // 通知栏只有一个播放/暂停键：两个回调都走 toggle，谁按下都得到正确结果。
          onPause: () => unawaited(toggle()),
          onNext: () => unawaited(nextChapter()),
          onPrevious: () => unawaited(previousChapter()),
          onSeek: (Duration position) => unawaited(seek(position)),
        ),
      );
      _handle = handle;
      await _syncNotification();
    } on Exception catch (error, stackTrace) {
      // 没有通知也必须能听：attach 失败只记 warning，播放器继续工作（C-PLT-1 的降级口径）。
      ref
          .read(appLoggerProvider)
          .warning(
            'The media notification could not be attached.',
            error,
            stackTrace,
          );
    }
  }

  /// Pushes the current chapter and playback facts to the notification.
  Future<void> _syncNotification([AudioReaderState? stateOverride]) async {
    final PlaybackNotificationHandle? handle = _handle;
    final AudioReaderState? current = stateOverride ?? state.value;
    final ReaderBook? book = _book;
    if (handle == null ||
        current == null ||
        book == null ||
        !current.hasTrack) {
      return;
    }
    final ReaderSessionState? session = ref
        .read(readerSessionProvider(book))
        .value;
    final int index = session?.chapterIndex ?? 0;
    final String title = index >= 0 && index < _chapters.length
        ? _chapters[index].title
        : '';
    await handle.update(
      metadata: PlaybackNotificationMetadata(
        id: current.tracks[current.trackIndex].url,
        title: title,
        album: book.name,
        duration: current.duration,
      ),
      state: PlaybackNotificationState(
        isPlaying: current.isPlaying,
        isBuffering: current.isBuffering,
        isCompleted: current.isCompleted,
        position: current.position,
        speed: current.speed,
      ),
    );
  }

  /// Runs an engine command, turning its failure into state instead of an exception.
  ///
  /// `on Exception` is allowed **only** here: this is the presentation notifier boundary that
  /// C-ERR-2 describes, and the catch immediately becomes a failure state plus a log line.
  Future<ParseResult<void>> _command(
    Future<ParseResult<void>> Function() command,
  ) async {
    try {
      final ParseResult<void> result = await command();
      if (result case ParseFailure<void>(
        :final ParseFailureKind kind,
        :final String rulePath,
      )) {
        _setFailure(ParseFailure<Never>(kind: kind, rulePath: rulePath));
      }

      return result;
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('Audio command failed.', error, stackTrace);
      const ParseFailure<Never> failure = ParseFailure<Never>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'reader.audioPlayer',
      );
      _setFailure(failure);

      return failure;
    }
  }

  /// Puts [failure] into the state of an already built notifier.
  ///
  /// During `build` there is no state yet; the failure travels back through the returned
  /// [AudioReaderState] instead of being written here (Riverpod forbids writing while building).
  void _setFailure(ParseFailure<Never> failure) {
    if (!_built) {
      return;
    }
    final AudioReaderState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<AudioReaderState>(
      current.copyWith(failure: failure, isLoading: false, isPlaying: false),
    );
  }
}

/// Rejects a plaintext track unless the user opted in (C-SEC-2, ADR-0056).
///
/// Android also blocks cleartext in the manifest; the switch is what changes the user-visible
/// answer from “this track cannot play” to “turn on plaintext HTTP deliberately”.
ParseFailure<Never>? _plainHttpFailureFor(String url, bool allow) {
  if (allow) {
    return null;
  }
  final Uri? uri = Uri.tryParse(url);

  return uri?.scheme == 'http'
      ? const ParseFailure<Never>(
          kind: ParseFailureKind.unsupportedRule,
          rulePath: 'reader.audioPlainHttp',
        )
      : null;
}
