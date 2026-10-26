import 'dart:async';

import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/audio_service_playback_notification.dart';
import 'package:flutter_reader/core/platform/playback_backend.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';
import 'package:flutter_reader/features/reader/data/bookmark_repository_impl.dart';
import 'package:flutter_reader/features/reader/data/flutter_tts_speech_synthesizer.dart';
import 'package:flutter_reader/features/reader/data/just_audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/data/media_kit_playback_engine.dart';
import 'package:flutter_reader/features/reader/data/reader_settings_repository_impl.dart';
import 'package:flutter_reader/features/reader/data/reading_record_repository_impl.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_track_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/book_source_switcher.dart';
import 'package:flutter_reader/features/reader/domain/repositories/bookmark_repository.dart';
import 'package:flutter_reader/features/reader/domain/repositories/manga_page_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_source_kind_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_record_repository.dart';
import 'package:flutter_reader/features/reader/domain/repositories/speech_synthesizer.dart';
import 'package:flutter_reader/features/reader/domain/usecases/search_in_book.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides the reader's own settings store (`docs/dev/roadmap.md` 5.3).
@Riverpod(keepAlive: true)
Future<ReaderSettingsRepository> readerSettingsRepository(Ref ref) async =>
    ReaderSettingsRepositoryImpl(
      store: await ref.watch(preferenceStoreProvider.future),
    );

/// Provides the chapter-list port, **unbound** by default.
///
/// The composition root overrides it with `book_source`'s `FetchToc` (ADR-0041 §决策 2). The
/// default is the null object, so a forgotten binding is a failure message plus a warning rather
/// than an exception in the middle of reading.
@Riverpod(keepAlive: true)
ChapterListProvider readerChapterList(Ref ref) =>
    UnboundChapterListProvider(logger: ref.watch(appLoggerProvider));

/// Provides the chapter-body port, **unbound** by default.
@Riverpod(keepAlive: true)
ChapterContentProvider readerChapterContent(Ref ref) =>
    UnboundChapterContentProvider(logger: ref.watch(appLoggerProvider));

/// Provides the manga-page port, **unbound** by default
/// (`docs/dev/roadmap.md` §3.10 M16).
@Riverpod(keepAlive: true)
MangaPageProvider readerMangaPages(Ref ref) =>
    UnboundMangaPageProvider(logger: ref.watch(appLoggerProvider));

/// Provides the source-kind port, **unbound** by default: an unbound reader opens text.
@Riverpod(keepAlive: true)
ReaderSourceKindProvider readerSourceKindPort(Ref ref) =>
    UnboundReaderSourceKindProvider(logger: ref.watch(appLoggerProvider));

/// Provides the reading-progress port, **unbound** by default.
///
/// The composition root binds it to `bookshelf`, which owns the table (ADR-0041 §决策 4,
/// ADR-0044 §决策 2).
@Riverpod(keepAlive: true)
ReadingProgressStore readerProgressStore(Ref ref) =>
    UnboundReadingProgressStore(logger: ref.watch(appLoggerProvider));

/// Provides the bookmark store (`docs/dev/roadmap.md` M19, ADR-0066 §决策 3).
///
/// The reader owns this table, so the provider binds the real implementation here instead of
/// waiting for the composition root: nothing outside the feature may write a bookmark.
@Riverpod(keepAlive: true)
BookmarkRepository bookmarkRepository(Ref ref) =>
    BookmarkRepositoryImpl(ref.watch(bookmarkDaoProvider));

/// Provides the reading-record store (`docs/dev/roadmap.md` M19, ADR-0066 §决策 4).
@Riverpod(keepAlive: true)
ReadingRecordRepository readingRecordRepository(Ref ref) =>
    ReadingRecordRepositoryImpl(ref.watch(readRecordDaoProvider));

/// Provides the source-switch port, **unbound** by default.
///
/// The composition root binds it to `book_source`'s `SwitchBookSource` plus the shelf's identity
/// migration (ADR-0051 §决策 3). Unbound it answers an `unsupportedRule` failure, so the sheet shows
/// a message instead of throwing (`docs/dev/platform.md` §2's habit).
@Riverpod(keepAlive: true)
BookSourceSwitcher bookSourceSwitcher(Ref ref) =>
    const UnboundBookSourceSwitcher();

/// Provides the audio player, **unbound** to a platform until it is really needed.
///
/// The adapter creates a native player in its constructor, so this provider is only instantiated
/// when an audio book is opened (or a test overrides it). Its own disposal releases the native
/// player once the page stops watching it.
@riverpod
AudioPlaybackEngine audioPlaybackEngine(Ref ref) {
  final AppLogger logger = ref.watch(appLoggerProvider);
  // Windows 用 media_kit（mpv）；Android / iOS 继续 just_audio（ADR-0061）。
  final AudioPlaybackEngine engine = usesMediaKitPlayback
      ? MediaKitPlaybackEngine(logger: logger)
      : JustAudioPlaybackEngine(logger: logger);
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

/// Provides the in-book search (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// It only needs the chapter-content port: the run is orchestrated here, and the politeness of the
/// requests themselves stays inside `book_source` (rate gate + `HttpPolicy`).
@riverpod
SearchInBook searchInBook(Ref ref) =>
    SearchInBook(content: ref.watch(readerChapterContentProvider));

/// Provides the media-notification binding for this platform
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 3/4).
@riverpod
PlaybackNotification playbackNotification(Ref ref) =>
    createPlaybackNotification(logger: ref.watch(appLoggerProvider));
