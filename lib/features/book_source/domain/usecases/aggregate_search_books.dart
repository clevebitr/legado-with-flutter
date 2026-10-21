import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/search_book.dart';
import 'package:flutter_reader/features/book_source/domain/search_match_mode.dart';
import 'package:flutter_reader/features/book_source/domain/search_result_merger.dart';
import 'package:flutter_reader/features/book_source/domain/search_source_resolver.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';

/// How long one source may take in an aggregate search (`docs/dev/roadmap.md` 3.8).
///
/// Upstream's `withTimeout(60000L)`: a dead source must not hold a worker for the whole batch, while
/// 60 s is generous enough for a slow site that still answers (ADR-0046 §决策 5).
const Duration sourceSearchTimeout = Duration(seconds: 60);

/// One page of an aggregate search (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 5/7).
final class AggregateSearchRequest {
  /// Creates a request.
  AggregateSearchRequest({
    required this.keyword,
    required this.sources,
    required this.matchMode,
    this.page = 1,
    this.concurrency = 1,
  }) {
    if (concurrency < 1) {
      // 并发为 0 会让整批永久停住（5.6 已经为请求层记过同一条坑），这里在构造处就挡住。
      throw ArgumentError.value(concurrency, 'concurrency', 'must be >= 1');
    }
  }

  /// What to search for.
  final String keyword;

  /// The sources to search, already resolved through the scope and the type filter.
  final List<BookSource> sources;

  /// How the hits are bucketed and ordered.
  final SearchMatchMode matchMode;

  /// The 1-based page every source is asked for.
  final int page;

  /// How many sources may be in flight at once.
  final int concurrency;
}

/// What one aggregate search produced.
final class AggregateSearchResult {
  /// Creates a result.
  const AggregateSearchResult({
    required this.books,
    required this.processedSources,
    required this.totalSources,
    required this.failedSources,
    required this.hasMore,
  });

  /// The merged, de-duplicated rows, best bucket first.
  final List<SearchBook> books;

  /// How many sources finished (successfully or not).
  final int processedSources;

  /// How many sources the request named.
  final int totalSources;

  /// How many of them failed (timeout, network, or a broken rule).
  final int failedSources;

  /// Whether another page is worth asking for (`supportsSearchPage` + non-empty + under the cap).
  final bool hasMore;
}

/// A pause latch for one aggregate search (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 6).
///
/// It is **cooperative and coarser than a request**: a worker awaits [waitWhilePaused] before it
/// starts the next source, so pausing never interrupts a request that is already in flight — the HTTP
/// layer has no cancellation primitive (the same reason M10's cancellation is cooperative).
final class SearchPause {
  bool _isPaused = false;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  /// Whether the batch is currently paused.
  bool get isPaused => _isPaused;

  /// Stops the workers before their next source.
  void pause() => _isPaused = true;

  /// Lets the waiting workers continue.
  void resume() {
    _isPaused = false;
    for (final Completer<void> waiter in _waiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _waiters.clear();
  }

  /// Completes when the batch is not paused.
  Future<void> waitWhilePaused() {
    if (!_isPaused) {
      return Future<void>.value();
    }
    final Completer<void> waiter = Completer<void>();
    _waiters.add(waiter);

    return waiter.future;
  }
}

/// Runs one keyword against many sources and merges the hits
/// (`docs/dev/roadmap.md` 3.8, ADR-0046).
///
/// Three behaviours are the whole reason this exists next to `SearchBooks`:
///
/// * **concurrency**: at most [AggregateSearchRequest.concurrency] sources are in flight, so a
///   hundred-source scope does not open a hundred connections;
/// * **one source cannot sink the batch**: a failure or a [sourceSearchTimeout] timeout only counts
///   toward `failedSources`; the batch fails only when *every* source failed (ADR-0046 §决策 5);
/// * **incremental results**: the progress callback is called after every source with the merged list so far,
///   which is what makes the page fill up instead of waiting for the slowest source.
final class AggregateSearchBooks {
  /// Creates the use case.
  const AggregateSearchBooks({
    required this._search,
    required this._logger,
    this.timeout = sourceSearchTimeout,
  });

  final SearchBooks _search;
  final AppLogger _logger;

  /// How long one source may take; injected so a test can shrink it instead of waiting 60 s.
  final Duration timeout;

  /// Searches every source of [request] and answers the merged page.
  ///
  /// [onProgress] receives the merged rows and the progress counters after each source; [pause]
  /// gates the workers; [cancellation] stops the batch between sources and keeps what was found.
  Future<ParseResult<AggregateSearchResult>> execute(
    AggregateSearchRequest request, {
    void Function(AggregateSearchResult progress)? onProgress,
    SearchPause? pause,
    TaskCancellation? cancellation,
  }) async {
    if (request.keyword.trim().isEmpty) {
      return failureAt<AggregateSearchResult>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'search.keyword',
      );
    }
    if (request.sources.isEmpty) {
      return failureAt<AggregateSearchResult>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'search.scope',
      );
    }

    final SearchResultMerger merger = SearchResultMerger(
      keyword: request.keyword.trim(),
      mode: request.matchMode,
    );
    var processed = 0;
    var failed = 0;
    var hasMore = false;

    void publish() => onProgress?.call(
      AggregateSearchResult(
        books: merger.books,
        processedSources: processed,
        totalSources: request.sources.length,
        failedSources: failed,
        hasMore: hasMore,
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
        if (request.page > 1 && !supportsSearchPage(source.searchUrl)) {
          // 不支持翻页的源在第 2 页起直接跳过，不记成失败（ADR-0046 §决策 7）。
          processed++;
          publish();
          continue;
        }

        final ParseResult<List<Book>> result;
        try {
          result = await _search
              .execute(source, request.keyword, page: request.page)
              .timeout(timeout);
        } on TimeoutException {
          failed++;
          processed++;
          _logger.warning(
            'Aggregate search timed out on one source: source=${source.url} '
            'page=${request.page}',
          );
          publish();
          continue;
        }

        switch (result) {
          case ParseSuccess<List<Book>>(:final List<Book> data):
            if (data.isNotEmpty) {
              merger.add(data, sourceUrl: source.url);
              hasMore = hasMore || supportsSearchPage(source.searchUrl);
            }
          case ParseFailure<List<Book>>(
                :final ParseFailureKind kind,
                :final String rulePath,
              )
              when _isNoMatch(kind, rulePath):
            // 列表规则一个都没命中 = 这个源「没搜到」，不是失败（book-source.md §7 把它报成
            // parseFailed，聚合搜索必须把它读成空结果，否则一次空搜索会被说成「全部失败」）。
            _logger.debug(
              'Aggregate search found nothing in one source: source=${source.url}',
            );
          case ParseFailure<List<Book>>(:final ParseFailureKind kind):
            failed++;
            // 单源失败只记日志：它不该把整批结果清空（C-ERR-8：不写关键词、不写正文）。
            _logger.warning(
              'Aggregate search failed on one source: source=${source.url} '
              'kind=${kind.name} page=${request.page}',
            );
        }
        processed++;
        publish();
      }
    }

    // `AggregateSearchRequest` 已经拒绝 < 1 的并发，这里直接用。
    await Future.wait(<Future<void>>[
      for (var index = 0; index < request.concurrency; index++) worker(),
    ]);

    if (committedNothing(
      merger: merger,
      failed: failed,
      total: request.sources.length,
    )) {
      return failureAt<AggregateSearchResult>(
        kind: ParseFailureKind.networkFailed,
        rulePath: 'search.aggregate',
      );
    }

    return ParseSuccess<AggregateSearchResult>(
      AggregateSearchResult(
        books: merger.books,
        processedSources: processed,
        totalSources: request.sources.length,
        failedSources: failed,
        hasMore:
            hasMore &&
            !merger.resultLimitReached &&
            !(cancellation?.isCancelled ?? false),
      ),
    );
  }

  /// Whether [kind] / [rulePath] means "this source found nothing" rather than "it broke".
  ///
  /// A top-level list rule that matched nothing is what `book-source.md` §7 reports as
  /// `parseFailed`; in an aggregate search that is an empty page, not an error, and counting it as
  /// a failure would turn "no source has this book" into "every source is broken"
  /// (ADR-0046 §决策 5).
  bool _isNoMatch(ParseFailureKind kind, String rulePath) =>
      kind == ParseFailureKind.parseFailed && rulePath.startsWith('searchRule');

  /// Whether the batch ended with nothing to show **and** every source failed.
  ///
  /// A batch where every source returned an empty list is a legitimate "no match", not a failure:
  /// only an all-failed batch is reported as one (ADR-0046 §决策 5).
  bool committedNothing({
    required SearchResultMerger merger,
    required int failed,
    required int total,
  }) => merger.count == 0 && failed == total;
}
