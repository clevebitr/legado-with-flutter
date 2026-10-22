import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/features/reader/data/reader_settings_repository_impl.dart';
import 'package:flutter_reader/features/reader/domain/repositories/manga_page_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_source_kind_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
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

/// Provides the manga-page port, **unbound** by default
/// (`docs/dev/roadmap.md` §3.10 M16).
@riverpod
MangaPageProvider readerMangaPages(Ref ref) =>
    UnboundMangaPageProvider(logger: ref.watch(appLoggerProvider));

/// Provides the source-kind port, **unbound** by default: an unbound reader opens text.
@riverpod
ReaderSourceKindProvider readerSourceKindPort(Ref ref) =>
    UnboundReaderSourceKindProvider(logger: ref.watch(appLoggerProvider));

/// Provides the reading-progress port, **unbound** by default.
///
/// The composition root binds it to `bookshelf`, which owns the table (ADR-0041 §决策 4,
/// ADR-0044 §决策 2).
@riverpod
ReadingProgressStore readerProgressStore(Ref ref) =>
    UnboundReadingProgressStore(logger: ref.watch(appLoggerProvider));
