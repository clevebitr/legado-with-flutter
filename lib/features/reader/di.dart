import 'dart:async';

import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/platform/audio_service_playback_notification.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';
import 'package:flutter_reader/features/reader/data/flutter_tts_speech_synthesizer.dart';
import 'package:flutter_reader/features/reader/data/just_audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/data/reader_settings_repository_impl.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_media_kind.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_track_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
import 'package:flutter_reader/features/reader/domain/repositories/source_kind_provider.dart';
import 'package:flutter_reader/features/reader/domain/repositories/speech_synthesizer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides the reader's own settings store (`docs/dev/roadmap.md` 5.3).
@riverpod
Future<ReaderSettingsRepository> readerSettingsRepository(Ref ref) async =>
    ReaderSettingsRepositoryImpl(
      store: await ref.watch(preferenceStoreProvider.future),
    );

/// Provides the chapter-list port, **unbound** by default.
///
/// The composition root overrides it with `book_source`'s `FetchToc` (ADR-0041 §决策 2). The
/// default is the null object, so a forgotten binding is a failure message plus a warning rather
/// than an exception in the middle of reading.
@riverpod
ChapterListProvider readerChapterList(Ref ref) =>
    UnboundChapterListProvider(logger: ref.watch(appLoggerProvider));

/// Provides the chapter-body port, **unbound** by default.
@riverpod
ChapterContentProvider readerChapterContent(Ref ref) =>
    UnboundChapterContentProvider(logger: ref.watch(appLoggerProvider));

/// Provides the reading-progress port, **unbound** by default.
///
/// The composition root binds it to `bookshelf`, which owns the table (ADR-0041 §决策 4,
/// ADR-0044 §决策 2).
@riverpod
ReadingProgressStore readerProgressStore(Ref ref) =>
    UnboundReadingProgressStore(logger: ref.watch(appLoggerProvider));

/// Provides the audio player, **unbound** to a platform until it is really needed.
///
/// The adapter creates a native player in its constructor, so this provider is only instantiated
/// when an audio book is opened (or a test overrides it). Its own disposal releases the native
/// player once the page stops watching it.
@riverpod
AudioPlaybackEngine audioPlaybackEngine(Ref ref) {
  final AudioPlaybackEngine engine = JustAudioPlaybackEngine(
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(() => unawaited(engine.dispose()));

  return engine;
}

/// Provides the system TTS engine (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
@riverpod
SpeechSynthesizer speechSynthesizer(Ref ref) {
  final SpeechSynthesizer engine = FlutterTtsSpeechSynthesizer(
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(() => unawaited(engine.dispose()));

  return engine;
}

/// Provides the audio-track port, **unbound** by default.
///
/// The composition root binds it to `book_source`'s `FetchAudioTracks` (ADR-0041 §决策 2).
@riverpod
AudioTrackProvider readerAudioTrack(Ref ref) =>
    UnboundAudioTrackProvider(logger: ref.watch(appLoggerProvider));

/// Provides the source-kind port, **unbound** by default (text).
@riverpod
SourceKindProvider readerSourceKind(Ref ref) =>
    UnboundSourceKindProvider(logger: ref.watch(appLoggerProvider));

/// What the open book source serves; the reader page dispatches on it
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 1).
@riverpod
Future<ReaderMediaKind> readerMediaKind(Ref ref, String sourceUrl) =>
    ref.watch(readerSourceKindProvider).kindOf(sourceUrl: sourceUrl);

/// Provides the media-notification binding for this platform
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 3/4).
@riverpod
PlaybackNotification playbackNotification(Ref ref) =>
    createPlaybackNotification(logger: ref.watch(appLoggerProvider));
