import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_budget.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';

/// One other source that has the book being read (`docs/dev/roadmap.md` §3.9-R3).
final class SourceCandidate {
  /// Creates a candidate.
  const SourceCandidate({
    required this.sourceUrl,
    required this.sourceName,
    required this.bookUrl,
    this.author,
    this.lastChapter,
  });

  /// The candidate source's URL (its key in the repository).
  final String sourceUrl;

  /// The candidate source's display name.
  final String sourceName;

  /// The book's detail URL **inside that source**.
  final String bookUrl;

  /// The author as that source spelled it, when it declared one.
  final String? author;

  /// The latest chapter as that source spelled it, when it declared one.
  final String? lastChapter;
}

/// What one source switch produced (ADR-0051 §决策 3).
final class SourceSwitchResult {
  /// Creates the result.
  const SourceSwitchResult({
    required this.sourceUrl,
    required this.sourceName,
    required this.bookUrl,
    required this.bookName,
    required this.tocUrl,
    required this.chapterUrl,
    required this.chapterName,
    required this.chapterIndex,
    required this.author,
    required this.coverUrl,
    required this.lastChapter,
  });

  /// The new source's URL.
  final String sourceUrl;

  /// The new source's display name.
  final String sourceName;

  /// The book's URL inside the new source — the new half of its shelf identity.
  final String bookUrl;

  /// The book's title as the new source spells it.
  final String bookName;

  /// The new table-of-contents URL.
  final String tocUrl;

  /// The chapter the reader should open: the one aligned to the old chapter.
  final String chapterUrl;

  /// The aligned chapter's title.
  final String chapterName;

  /// The aligned chapter's index in the new book.
  final int chapterIndex;

  /// The author as the new source spells it.
  final String? author;

  /// The cover as the new source spells it.
  final String? coverUrl;

  /// The latest chapter as the new source spells it.
  final String? lastChapter;
}

/// Finds other sources for the book being read, and switches to one of them
/// (`docs/dev/roadmap.md` §3.9-R3, ADR-0051 §决策 3).
///
/// The two halves are one use case because they share the only non-obvious rule: **alignment**. A
/// candidate is only useful if the switch can land on “the same chapter”, and that decision needs
/// the chapter names of both sources — which neither the reader (it has no rules) nor the engine
/// (it has no book) can make.
///
/// It searches **per source** rather than through `AggregateSearchBooks`, because the merger keeps
/// one book URL per merged row (ADR-0046 §决策 4) and a switch needs the URL *inside the candidate
/// source*. The concurrency, the per-source budget and the “a source that found nothing is not a
/// failure” rule are the same as the aggregate search (ADR-0049/ADR-0046), only the result shape
/// differs.
final class SwitchBookSource {
  /// Creates the use case.
  const SwitchBookSource({
    required this._search,
    required this._bookInfo,
    required this._toc,
    this.concurrency = 4,
    this.budget = const Duration(seconds: 60),
  });

  final SearchBooks _search;
  final FetchBookInfo _bookInfo;
  final FetchToc _toc;

  /// How many sources search at once; the candidate list is a side glance, not a full run.
  final int concurrency;

  /// The per-source budget of the candidate search (ADR-0049).
  final Duration budget;

  /// Every **other** enabled source that has a book called [bookName].
  ///
  /// Exact title matches come first, then titles that contain the name; the current source is
  /// excluded. At most [limit] candidates come back.
  Future<ParseResult<List<SourceCandidate>>> candidates({
    required String bookName,
    required List<BookSource> sources,
    required String currentSourceUrl,
    int limit = 20,
  }) async {
    final String name = bookName.trim();
    if (name.isEmpty || sources.isEmpty) {
      return const ParseSuccess<List<SourceCandidate>>(<SourceCandidate>[]);
    }

    final List<BookingHit> hits = <BookingHit>[];
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final int index = next++;
        if (index >= sources.length) {
          return;
        }
        final BookSource source = sources[index];
        if (source.url == currentSourceUrl) {
          continue;
        }
        final ParseResult<List<Book>> found = await SourceBudget(budget)
            .run(() => _search.execute(source, name), rulePath: 'searchUrl');
        switch (found) {
          case ParseSuccess<List<Book>>(:final List<Book> data):
            final Book? hit = _bestMatch(data, name);
            if (hit != null) {
              hits.add(BookingHit(source: source, book: hit));
            }
          case ParseFailure<List<Book>>():
            // 这个源没搜到 / 挂了：换源面板少一条候选，不是整次要失败。
            break;
        }
      }
    }

    await Future.wait(<Future<void>>[
      for (var index = 0; index < (concurrency < 1 ? 1 : concurrency); index++)
        worker(),
    ]);

    final List<BookingHit> exact = <BookingHit>[
      for (final BookingHit hit in hits)
        if (hit.book.name.trim().toLowerCase() == name.toLowerCase()) hit,
    ];
    final List<BookingHit> partial = <BookingHit>[
      for (final BookingHit hit in hits)
        if (!exact.contains(hit)) hit,
    ];

    return ParseSuccess<List<SourceCandidate>>(
      <SourceCandidate>[
        for (final BookingHit hit in <BookingHit>[...exact, ...partial])
          SourceCandidate(
            sourceUrl: hit.source.url,
            sourceName: hit.source.name,
            bookUrl: hit.book.url,
            author: hit.book.author,
            lastChapter: hit.book.lastChapter,
          ),
      ].take(limit).toList(growable: false),
    );
  }

  /// The hit of [data] closest to [name], or `null` when none is close enough.
  Book? _bestMatch(List<Book> data, String name) {
    final String wanted = name.toLowerCase();
    Book? exact;
    Book? partial;
    for (final Book book in data) {
      final String title = book.name.trim().toLowerCase();
      if (title == wanted) {
        exact ??= book;
      } else if (title.contains(wanted) || wanted.contains(title)) {
        partial ??= book;
      }
    }

    return exact ?? partial;
  }

  /// Switches to [candidate] and answers where the reader should continue.
  ///
  /// The alignment order is ADR-0051 §决策 3: an exactly equal chapter name, then a name that
  /// contains the old one (or is contained by it), then the **same index** clamped into the new
  /// list — a source that renumbered everything still opens a plausible chapter instead of failing.
  Future<ParseResult<SourceSwitchResult>> switchTo({
    required BookSource target,
    required SourceCandidate candidate,
    required String currentChapterName,
    required int currentChapterIndex,
  }) async {
    final ParseResult<BookInfo> info = await _bookInfo.execute(
      target,
      candidate.bookUrl,
    );
    final BookInfo bookInfo;
    switch (info) {
      case ParseFailure<BookInfo>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<SourceSwitchResult>(kind: kind, rulePath: rulePath);
      case ParseSuccess<BookInfo>(:final BookInfo data):
        bookInfo = data;
    }

    final ParseResult<List<Chapter>> toc = await _toc.execute(
      target,
      bookInfo.tocUrl,
      bookName: bookInfo.name,
    );
    final List<Chapter> chapters;
    switch (toc) {
      case ParseFailure<List<Chapter>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<SourceSwitchResult>(kind: kind, rulePath: rulePath);
      case ParseSuccess<List<Chapter>>(:final List<Chapter> data):
        if (data.isEmpty) {
          return failureAt<SourceSwitchResult>(
            kind: ParseFailureKind.parseFailed,
            rulePath: 'tocRule.chapterList',
          );
        }
        chapters = data;
    }

    final int index = alignChapterIndex(
      chapters,
      currentChapterName,
      fallbackIndex: currentChapterIndex,
    );
    final Chapter aligned = chapters[index];

    return ParseSuccess<SourceSwitchResult>(
      SourceSwitchResult(
        sourceUrl: target.url,
        sourceName: target.name,
        bookUrl: bookInfo.url,
        bookName: bookInfo.name,
        tocUrl: bookInfo.tocUrl,
        chapterUrl: aligned.url,
        chapterName: aligned.name,
        chapterIndex: index,
        author: bookInfo.author,
        coverUrl: bookInfo.coverUrl,
        lastChapter: bookInfo.lastChapter,
      ),
    );
  }

  /// The index of the chapter of [chapters] that corresponds to [name] (ADR-0051 §决策 3).
  int alignChapterIndex(
    List<Chapter> chapters,
    String name, {
    required int fallbackIndex,
  }) {
    final String wanted = name.trim().toLowerCase();
    if (wanted.isNotEmpty) {
      for (var index = 0; index < chapters.length; index++) {
        if (chapters[index].name.trim().toLowerCase() == wanted) {
          return index;
        }
      }
      for (var index = 0; index < chapters.length; index++) {
        final String candidate = chapters[index].name.trim().toLowerCase();
        if (candidate.contains(wanted) || wanted.contains(candidate)) {
          return index;
        }
      }
    }

    return fallbackIndex.clamp(0, chapters.length - 1);
  }
}

/// One source's best hit, kept together with the source it came from.
final class BookingHit {
  /// Creates a hit.
  const BookingHit({required this.source, required this.book});

  /// The source that found [book].
  final BookSource source;

  /// The hit inside [source].
  final Book book;
}
