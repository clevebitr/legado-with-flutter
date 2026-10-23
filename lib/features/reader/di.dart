import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/features/reader/data/reader_settings_repository_impl.dart';
import 'package:flutter_reader/features/reader/domain/repositories/book_source_switcher.dart';
import 'package:flutter_reader/features/reader/domain/repositories/manga_page_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_source_kind_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
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

/// Provides the source-switch port, **unbound** by default.
///
/// The composition root binds it to `book_source`'s `SwitchBookSource` plus the shelf's identity
/// migration (ADR-0051 §决策 3). Unbound it answers an `unsupportedRule` failure, so the sheet shows
/// a message instead of throwing (`docs/dev/platform.md` §2's habit).
@Riverpod(keepAlive: true)
BookSourceSwitcher bookSourceSwitcher(Ref ref) =>
    const UnboundBookSourceSwitcher();
