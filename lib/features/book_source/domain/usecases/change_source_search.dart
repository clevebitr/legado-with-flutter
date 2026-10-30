import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/error_text.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/search_book.dart';
import 'package:flutter_reader/features/book_source/domain/source_budget.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/aggregate_search_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';

/// How good a source's hit is for the book being switched (ADR-0091 §决策 2).
///
/// The order is the display order: an exactly equal title beats a contained one, which beats a hit
/// that only matched the author.
enum ChangeSourceMatch {
  /// The title equals the keyword, folded for case and surrounding spaces.
  exact,

  /// The title and the keyword contain each other (`剑来（精校版）` vs `剑来`).
  partial,

  /// The title could not be read, so only the author proved the hit is the same book.
  authorOnly,
}

/// One other source that has the book being switched (ADR-0091 §决策 1).
final class ChangeSourceCandidate {
  /// Creates a candidate.
  const ChangeSourceCandidate({
    required this.source,
    required this.book,
    required this.match,
    this.tocUrl,
    this.chapterCount,
  });

  /// The source that found this book.
  final BookSource source;

  /// The hit as that source spelled it — possibly enriched by `loadInfo` (decision 4).
  final Book book;

  /// How the hit was matched; it decides the display order.
  final ChangeSourceMatch match;

  /// The table of contents to read after switching; `null` until `loadInfo` asked for it.
  final String? tocUrl;

  /// How many chapters that source publishes, when `loadToc` was on.
  final int? chapterCount;

  /// The candidate's source URL — the identity the switch and the shelf use.
  String get sourceUrl => source.url;

  /// The candidate's source name, as shown in the list.
  String get sourceName => source.name;
}

/// What one change-source search needs (ADR-0091 §决策 1).
final class ChangeSourceRequest {
  /// Creates a request.
  ChangeSourceRequest({
    required this.keyword,
    required this.sources,
    this.author,
    this.checkAuthor = false,
    this.loadInfo = false,
    this.loadToc = false,
    this.concurrency = 1,
  }) {
    if (concurrency < 1) {
      // 并发为 0 会让整批永久停住；与 `AggregateSearchRequest` 同一条理由，在构造处就挡住。
      throw ArgumentError.value(concurrency, 'concurrency', 'must be >= 1');
    }
  }

  /// The title to search for; it may be empty, and then [author] carries the search.
  ///
  /// A book whose `name` rule failed has no title at all — that is exactly the case that used to
  /// answer "no other source has this book" (ADR-0091 §决策 3, `DECISIONS.md` #75).
  final String keyword;

  /// The author of the book being switched, when the caller knows it.
  final String? author;

  /// The sources to search, already resolved through the scope and the type filter.
  final List<BookSource> sources;

  /// Whether a candidate's author must contain [author] before it is accepted.
  final bool checkAuthor;

  /// Whether each candidate's detail page is read (cover, latest chapter, `tocUrl`).
  final bool loadInfo;

  /// Whether each candidate's table of contents is read (chapter count).
  final bool loadToc;

  /// How many sources may be in flight at once.
  final int concurrency;

  /// The text every source is searched with: the title, or the author when there is no title.
  String get searchKeyword =>
      keyword.trim().isNotEmpty ? keyword.trim() : (author ?? '').trim();
}

/// A snapshot of a change-source search in flight (ADR-0091 §决策 1).
final class ChangeSourceProgress {
  /// Creates a snapshot.
  const ChangeSourceProgress({
    required this.candidates,
    required this.processedSources,
    required this.totalSources,
    required this.failedSources,
    this.currentSourceName,
  });

  /// The candidates found so far, already ordered.
  final List<ChangeSourceCandidate> candidates;

  /// How many sources finished (successfully or not).
  final int processedSources;

  /// How many sources the request named.
  final int totalSources;

  /// How many of them failed (timeout, network, or a broken rule).
  final int failedSources;

  /// The source that just finished, for the progress line.
  final String? currentSourceName;
}

/// Finds the other sources that have the book being switched (ADR-0091).
///
/// It replaces the one-shot candidate search of ADR-0051 §决策 3 with a **progressive** one: every
/// finished source publishes a snapshot through `onProgress`, the workers are gated by
/// [SearchPause], and a [TaskCancellation] keeps whatever was already found. Concurrency and the
/// per-source budget are the aggregate search's (ADR-0046 §决策 5/6) — a hundred-source scope must
/// not open a hundred connections, and one dead source must not sink the list.
final class ChangeSourceSearch {
  /// Creates the use case.
  const ChangeSourceSearch({
    required this._search,
    required this._bookInfo,
    required this._toc,
    required this._logger,
    this.timeout = sourceSearchTimeout,
    this.limit = maxChangeSourceCandidates,
    this._clock = const SystemClock(),
  });

  final SearchBooks _search;
  final FetchBookInfo _bookInfo;
  final FetchToc _toc;
  final AppLogger _logger;
  final Clock _clock;

  /// How long one source may take for the whole candidate (search + optional detail/TOC).
  final Duration timeout;

  /// How many candidates are kept; the rest of the scope still runs.
  final int limit;

  /// Searches every source of [request] and answers the candidates in display order.
  ///
  /// [onProgress] is called after every source; [pause] and [cancellation] behave exactly like the
  /// aggregate search's. An empty answer is a **success**: "no other source has this book" is a
  /// normal outcome, not a failure.
  Future<ParseResult<List<ChangeSourceCandidate>>> execute(
    ChangeSourceRequest request, {
    void Function(ChangeSourceProgress progress)? onProgress,
    SearchPause? pause,
    TaskCancellation? cancellation,
  }) async {
    if (request.sources.isEmpty) {
      return failureAt<List<ChangeSourceCandidate>>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'changeSource.scope',
      );
    }
    if (request.searchKeyword.isEmpty) {
      // 没有标题也没有作者：没有可搜的东西。这不是失败，而是「先补上标题」——界面会提示，
      // 所以这里只记一条日志并交回空表（ADR-0091 §决策 3）。
      _logger.warning(
        'Change source has nothing to search with: sources=${request.sources.length}',
      );

      return const ParseSuccess<List<ChangeSourceCandidate>>(
        <ChangeSourceCandidate>[],
      );
    }

    final List<ChangeSourceCandidate> found = <ChangeSourceCandidate>[];
    var processed = 0;
    var failed = 0;
    ParseFailureKind? firstFailureKind;

    void publish(String sourceName) => onProgress?.call(
      ChangeSourceProgress(
        candidates: _ordered(found),
        processedSources: processed,
        totalSources: request.sources.length,
        failedSources: failed,
        currentSourceName: sourceName,
      ),
    );

    var next = 0;
    Future<void> worker() async {
      while (true) {
        if (cancellation?.isCancelled ?? false) {
          return;
        }
        final int index = next++;
        if (index >= request.sources.length) {
          return;
        }
        final BookSource source = request.sources[index];
        if (pause != null) {
          await pause.waitWhilePaused();
        }
        if (cancellation?.isCancelled ?? false) {
          return;
        }

        // 每个源一份整份预算（§3.7-B7、ADR-0049）：搜索 + 详情 + 目录都算在 60 s 里。
        final SourceBudget budget = SourceBudget(timeout, clock: _clock);
        final ParseResult<ChangeSourceCandidate?> candidate;
        try {
          candidate = await budget.run(
            () => _searchOne(source, request),
            rulePath: 'searchUrl',
          );
        } on Exception catch (error, stackTrace) {
          // 一个源抛异常不能把整批清掉（ADR-0046 §决策 5）：读成这个源失败，记一条日志。
          failed++;
          processed++;
          _logger.warning(
            'Change source search threw on one source: source=${source.url} '
            'error=${describeError(error)}',
            error,
            stackTrace,
          );
          publish(source.name);

          continue;
        }

        switch (candidate) {
          case ParseSuccess<ChangeSourceCandidate?>(
            data: final ChangeSourceCandidate hit,
          ):
            found.add(hit);
          case ParseSuccess<ChangeSourceCandidate?>(data: null):
            // 这个源没有这本书：少一条候选，不是失败。
            _logger.debug(
              'Change source found nothing in one source: source=${source.url}',
            );
          case ParseFailure<ChangeSourceCandidate?>(
            :final ParseFailureKind kind,
            :final String rulePath,
          ):
            if (_isNoMatch(kind, rulePath)) {
              _logger.debug(
                'Change source got an empty list from one source: '
                'source=${source.url}',
              );
            } else {
              failed++;
              firstFailureKind ??= kind;
              _logger.warning(
                'Change source failed on one source: source=${source.url} '
                'kind=${kind.name}',
              );
            }
        }
        processed++;
        publish(source.name);
      }
    }

    await Future.wait(<Future<void>>[
      for (var index = 0; index < request.concurrency; index++) worker(),
    ]);

    // 全都失败才报失败：一个源都没成功、也没停止时，用户看到的是「整批坏了」而不是「没这本书」。
    if (found.isEmpty && failed == request.sources.length) {
      return failureAt<List<ChangeSourceCandidate>>(
        kind: firstFailureKind ?? ParseFailureKind.networkFailed,
        rulePath: 'changeSource.aggregate',
      );
    }

    return ParseSuccess<List<ChangeSourceCandidate>>(_ordered(found));
  }

  /// Searches [source] and answers its best hit, or `null` when it has no such book.
  Future<ParseResult<ChangeSourceCandidate?>> _searchOne(
    BookSource source,
    ChangeSourceRequest request,
  ) async {
    final ParseResult<List<Book>> searched = await _search.execute(
      source,
      request.searchKeyword,
    );
    final List<Book> hits;
    switch (searched) {
      case ParseFailure<List<Book>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<ChangeSourceCandidate?>(
          kind: kind,
          rulePath: rulePath,
        );
      case ParseSuccess<List<Book>>(:final List<Book> data):
        hits = data;
    }

    final _Match? match = _bestMatch(hits, request);
    if (match == null) {
      return const ParseSuccess<ChangeSourceCandidate?>(null);
    }

    Book book = match.book;
    var tocUrl = book.url;
    int? chapterCount;

    // 两个可选加载都是「锦上添花」：拿不到就保留搜索页给的字段，候选不能因此消失。
    if (request.loadInfo) {
      final ParseResult<BookInfo> info = await _bookInfo.execute(
        source,
        book.url,
      );
      switch (info) {
        case ParseSuccess<BookInfo>(:final BookInfo data):
          book = _enrich(book, data);
          tocUrl = data.tocUrl;
        case ParseFailure<BookInfo>(:final ParseFailureKind kind):
          _logger.warning(
            'Change source could not read the detail page: source=${source.url} '
            'kind=${kind.name}',
          );
      }
    }

    if (request.loadToc) {
      final ParseResult<List<Chapter>> toc = await _toc.execute(
        source,
        tocUrl,
        bookName: book.name,
        bookUrl: book.url,
      );
      switch (toc) {
        case ParseSuccess<List<Chapter>>(:final List<Chapter> data):
          chapterCount = data.length;
        case ParseFailure<List<Chapter>>(:final ParseFailureKind kind):
          _logger.warning(
            'Change source could not read the table of contents: '
            'source=${source.url} kind=${kind.name}',
          );
      }
    }

    return ParseSuccess<ChangeSourceCandidate?>(
      ChangeSourceCandidate(
        source: source,
        book: book,
        match: match.kind,
        tocUrl: request.loadInfo ? tocUrl : null,
        chapterCount: chapterCount,
      ),
    );
  }

  /// [book] with the detail page's fields, keeping the hit's own values where it had none.
  Book _enrich(Book book, BookInfo info) => book.copyWith(
    name: info.name.trim().isEmpty ? book.name : info.name,
    author: info.author ?? book.author,
    kind: info.kind ?? book.kind,
    coverUrl: info.coverUrl ?? book.coverUrl,
    intro: info.intro ?? book.intro,
    lastChapter: info.lastChapter ?? book.lastChapter,
    wordCount: info.wordCount ?? book.wordCount,
    updateTime: info.updateTime ?? book.updateTime,
  );

  /// The best hit of one source, or `null` when none of them can be this book (ADR-0091 §决策 2).
  _Match? _bestMatch(List<Book> hits, ChangeSourceRequest request) {
    final String wanted = mergeKeyOf(request.keyword);
    final String wantedAuthor = mergeKeyOf(request.author ?? '');
    _Match? exact;
    _Match? partial;
    _Match? byAuthor;

    for (final Book book in hits) {
      final String name = mergeKeyOf(book.name);
      final String author = mergeKeyOf(book.author ?? '');
      if (!_authorPasses(author, wantedAuthor, request.checkAuthor)) {
        continue;
      }
      if (wanted.isEmpty) {
        // 没有标题：只认作者（ADR-0091 §决策 2 的第 3 行）。
        if (_authorMatches(author, wantedAuthor)) {
          byAuthor ??= _Match(book, ChangeSourceMatch.authorOnly);
        }

        continue;
      }
      if (name == wanted) {
        exact ??= _Match(book, ChangeSourceMatch.exact);
      } else if (name.isNotEmpty &&
          (name.contains(wanted) || wanted.contains(name))) {
        partial ??= _Match(book, ChangeSourceMatch.partial);
      } else if (_authorMatches(author, wantedAuthor)) {
        // 书名读不出来时，作者对上也算：这正是「有的源拿不到标题」那条报障的兜底。
        byAuthor ??= _Match(book, ChangeSourceMatch.authorOnly);
      }
    }

    return exact ?? partial ?? byAuthor;
  }

  /// Whether a candidate's [author] survives the 「校验作者」 switch.
  ///
  /// An unknown author (empty) passes: the switch is there to reject a book we can prove is a
  /// different one, not to reject the sources that publish no author at all.
  bool _authorPasses(String author, String wantedAuthor, bool checkAuthor) {
    if (!checkAuthor || wantedAuthor.isEmpty || author.isEmpty) {
      return true;
    }

    return author.contains(wantedAuthor);
  }

  /// Whether [author] proves the hit belongs to the book with [wantedAuthor].
  bool _authorMatches(String author, String wantedAuthor) {
    if (wantedAuthor.isEmpty || author.isEmpty) {
      return false;
    }

    return author == wantedAuthor || author.contains(wantedAuthor);
  }

  /// [list] in display order: match kind first, then source name.
  List<ChangeSourceCandidate> _ordered(List<ChangeSourceCandidate> list) {
    final List<ChangeSourceCandidate> ordered =
        List<ChangeSourceCandidate>.of(list)
          ..sort((ChangeSourceCandidate left, ChangeSourceCandidate right) {
            final int byMatch = left.match.index.compareTo(right.match.index);

            return byMatch != 0
                ? byMatch
                : left.sourceName.compareTo(right.sourceName);
          });

    return ordered.length <= limit
        ? List<ChangeSourceCandidate>.unmodifiable(ordered)
        : List<ChangeSourceCandidate>.unmodifiable(ordered.take(limit));
  }

  /// Whether [kind] / [rulePath] means "this source has no such book" rather than "it broke".
  ///
  /// A top-level list rule that matched nothing is what `book-source.md` §7 reports as
  /// `parseFailed`; in a candidate search that is an empty source, not an error (ADR-0046 §决策 5).
  bool _isNoMatch(ParseFailureKind kind, String rulePath) =>
      kind == ParseFailureKind.parseFailed && rulePath.startsWith('searchRule');
}

/// How many candidates one change-source search keeps (ADR-0051 §决策 3's cap).
const int maxChangeSourceCandidates = 20;

/// One source's best hit together with how it matched.
final class _Match {
  const _Match(this.book, this.kind);

  final Book book;
  final ChangeSourceMatch kind;
}
