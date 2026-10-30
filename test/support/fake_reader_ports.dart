import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_source_kind.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_page.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/domain/repositories/manga_page_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_source_kind_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';

/// In-memory [ChapterListProvider] for the reader tests (`docs/dev/testing.md` §4).
final class FakeChapterListProvider implements ChapterListProvider {
  /// The chapters every request answers with.
  List<ReadingChapter> chapters = const <ReadingChapter>[];

  /// When set, every request fails with it instead.
  ParseResult<List<ReadingChapter>>? failure;

  /// The `(sourceUrl, tocUrl)` pairs requested, in order.
  final List<(String, String)> requests = <(String, String)>[];

  /// The `java.get('bookName')` context of every request, in order (ADR-0049).
  final List<String> bookNames = <String>[];

  @override
  Future<ParseResult<List<ReadingChapter>>> fetch({
    required String sourceUrl,
    required String tocUrl,
    String bookName = '',
    String bookUrl = '',
  }) async {
    requests.add((sourceUrl, tocUrl));
    bookNames.add(bookName);

    return failure ?? ParseSuccess<List<ReadingChapter>>(chapters);
  }
}

/// In-memory [ChapterContentProvider] for the reader tests.
final class FakeChapterContentProvider implements ChapterContentProvider {
  /// Bodies per chapter URL.
  final Map<String, String> bodies = <String, String>{};

  /// Failures per chapter URL; anything absent falls back to [bodies].
  final Map<String, ParseFailureKind> failures = <String, ParseFailureKind>{};

  /// The chapter URLs requested, in order.
  final List<String> requests = <String>[];

  /// How long every request takes, so a case can look at how many run at once.
  Duration delay = Duration.zero;

  /// The most requests that were ever in flight at the same time.
  int maxInFlight = 0;

  /// The requests currently in flight.
  int inFlight = 0;

  /// The `(bookName, chapterTitle)` context of every request, in order (ADR-0049).
  final List<(String, String)> contexts = <(String, String)>[];

  @override
  Future<ParseResult<String>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
    String bookUrl = '',
    String tocUrl = '',
    String nextChapterUrl = '',
    bool isVip = false,
    bool isPay = false,
    bool isVolume = false,
    String? updateTime,
  }) async {
    requests.add(chapterUrl);
    contexts.add((bookName, chapterTitle));
    inFlight++;
    if (inFlight > maxInFlight) {
      maxInFlight = inFlight;
    }
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    inFlight--;
    final ParseFailureKind? kind = failures[chapterUrl];
    if (kind != null) {
      return failureAt<String>(kind: kind, rulePath: 'reader.chapterContent');
    }

    return ParseSuccess<String>(bodies[chapterUrl] ?? '');
  }
}

/// In-memory [ReadingProgressStore] for the reader tests.
final class FakeReadingProgressStore implements ReadingProgressStore {
  /// The stored positions, keyed by `sourceUrl|bookUrl`.
  final Map<String, ReadingPosition> positions = <String, ReadingPosition>{};

  /// The writes, in order.
  final List<ReadingPosition> writes = <ReadingPosition>[];

  /// When true, [write] throws (the C-ERR-2 boundary case).
  bool failWrites = false;

  @override
  Future<ReadingPosition?> read({
    required String sourceUrl,
    required String bookUrl,
  }) async => positions['$sourceUrl|$bookUrl'];

  @override
  Future<void> write({
    required String sourceUrl,
    required String bookUrl,
    required ReadingPosition position,
  }) async {
    if (failWrites) {
      throw Exception('the progress store is unavailable');
    }
    writes.add(position);
    positions['$sourceUrl|$bookUrl'] = position;
  }
}

/// In-memory [ReaderSettingsRepository] for the reader tests.
final class FakeReaderSettingsRepository implements ReaderSettingsRepository {
  /// Creates the double with [initial] settings (defaults when omitted).
  FakeReaderSettingsRepository({ReaderSettings? initial})
    : _settings = initial ?? ReaderSettings.defaults;

  ReaderSettings _settings;

  /// The settings currently stored, for assertions.
  ReaderSettings get stored => _settings;

  @override
  Future<ReaderSettings> load() async => _settings;

  @override
  Future<void> save(ReaderSettings settings) async => _settings = settings;
}

/// In-memory [MangaPageProvider] for the reader tests (`docs/dev/roadmap.md` §3.10 M16).
final class FakeMangaPageProvider implements MangaPageProvider {
  /// Pages per chapter URL.
  final Map<String, List<ReadingPage>> pages = <String, List<ReadingPage>>{};

  /// Failures per chapter URL; anything absent falls back to [pages].
  final Map<String, ParseFailureKind> failures = <String, ParseFailureKind>{};

  /// The chapter URLs requested, in order.
  final List<String> requests = <String>[];

  @override
  Future<ParseResult<List<ReadingPage>>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
  }) async {
    requests.add(chapterUrl);
    final ParseFailureKind? kind = failures[chapterUrl];
    if (kind != null) {
      return failureAt<List<ReadingPage>>(
        kind: kind,
        rulePath: 'reader.mangaPages',
      );
    }

    return ParseSuccess<List<ReadingPage>>(
      pages[chapterUrl] ?? const <ReadingPage>[],
    );
  }
}

/// In-memory [ReaderSourceKindProvider] for the reader dispatch tests.
final class FakeReaderSourceKindProvider implements ReaderSourceKindProvider {
  /// The kind every request answers with; text by default.
  ReaderSourceKind kind = ReaderSourceKind.text;

  /// The source URLs asked about, in order.
  final List<String> requests = <String>[];

  @override
  Future<ParseResult<ReaderSourceKind>> of(String sourceUrl) async {
    requests.add(sourceUrl);

    return ParseSuccess<ReaderSourceKind>(kind);
  }
}
