import 'dart:async';

import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/search_book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/search_match_mode.dart';
import 'package:flutter_reader/features/book_source/domain/search_result_merger.dart';
import 'package:flutter_reader/features/book_source/domain/search_source_resolver.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/aggregate_search_books.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'aggregate_search_notifier.freezed.dart';
part 'aggregate_search_notifier.g.dart';

/// Where an aggregate search stands (`docs/dev/roadmap.md` 3.8, ADR-0046).
enum AggregateSearchStatus {
  /// Nothing was searched yet in this session.
  idle,

  /// Sources are being searched (or waiting while paused).
  running,

  /// The search finished, with or without hits.
  done,

  /// The search could not run, or every source failed.
  failed,
}

/// What the search page shows (`docs/dev/roadmap.md` 3.8, ADR-0046).
@freezed
abstract class AggregateSearchState with _$AggregateSearchState {
  /// Creates a search state.
  const factory AggregateSearchState({
    /// Where the run stands.
    @Default(AggregateSearchStatus.idle) AggregateSearchStatus status,

    /// The merged, de-duplicated rows.
    @Default(<SearchBook>[]) List<SearchBook> books,

    /// How many sources finished (successfully or not).
    @Default(0) int processedSources,

    /// How many sources the scope resolved to.
    @Default(0) int totalSources,

    /// How many of them failed.
    @Default(0) int failedSources,

    /// Whether another page is worth asking for.
    @Default(false) bool hasMore,

    /// Whether the user paused a running search.
    @Default(false) bool isPaused,

    /// The page the next [AggregateSearch.loadMore] will ask for.
    @Default(1) int page,

    /// Why the run failed, when [status] is [AggregateSearchStatus.failed].
    ParseFailureKind? failureKind,

    /// Why no source could be searched, when the scope resolved to nothing.
    @Default(<String, SearchSourceSkip>{})
    Map<String, SearchSourceSkip> skipped,

    /// Whether the scope named something that no longer exists, so every enabled source ran.
    ///
    /// 回退不是一个内部细节：用户选了一个已经不存在的分组，却看到全库的结果，不告诉他就会读成
    /// 「范围筛选失效」（ADR-0058）。
    @Default(false) bool scopeFellBack,

    /// The match mode the next run uses.
    @Default(SearchMatchMode.defaultMode) SearchMatchMode matchMode,

    /// The source-type filter the next run uses.
    @Default(defaultSearchSourceTypes) Set<BookSourceType> types,
  }) = _AggregateSearchState;
}

/// The stored scope and the only place that changes it (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).
@Riverpod(keepAlive: true)
class SearchScopeSelection extends _$SearchScopeSelection {
  @override
  Future<BookSearchScope> build() async =>
      (await ref.watch(searchScopeStoreProvider.future)).load();

  /// Replaces the scope and stores it.
  Future<void> select(BookSearchScope scope) async {
    await (await ref.read(searchScopeStoreProvider.future)).save(scope);
    state = AsyncData<BookSearchScope>(scope);
  }
}

/// Runs the aggregate search and publishes its progress (`docs/dev/roadmap.md` 3.8).
///
/// It owns three things the domain does not:
///
/// * **the scope → sources step**: `resolveSearchSources` over the loaded rows, so the page only
///   hands in "what the list knows" and the answer is the same one the check page will use;
/// * **the pause latch and the cancellation token**: both are rebuilt per run, and pausing only
///   takes effect between sources (ADR-0046 §决策 6);
/// * **paging**: [loadMore] runs the same use case one page further and keeps the merged list, so
///   the page never merges two different result shapes itself.
///
/// It is `keepAlive`: a search of a hundred sources is minutes of work and must survive walking to a
/// book and back.
@Riverpod(keepAlive: true)
class AggregateSearch extends _$AggregateSearch {
  SearchPause? _pause;
  TaskCancellation? _cancellation;
  SearchResultMerger? _merger;

  @override
  AggregateSearchState build() => const AggregateSearchState();

  /// Starts a new search for [keyword] over [rows] (the loaded sources).
  ///
  /// A blank keyword does nothing: the page already disables its button for that case, and a search
  /// that answered "invalid" would be a failure the user did not ask for.
  Future<void> search({
    required String keyword,
    required List<StoredBookSource> rows,
    required BookSearchScope scope,
  }) async {
    final String trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final SearchSourceResolution resolution = resolveSearchSources(
      rows: rows,
      scope: scope,
      types: state.types,
    );
    final int concurrency = budgetOrDefault(
      ref.read(concurrencySettingProvider),
      ref.read(appLoggerProvider),
    );
    _pause = SearchPause();
    _cancellation = TaskCancellation();
    _merger = null;
    state = AggregateSearchState(
      status: AggregateSearchStatus.running,
      totalSources: resolution.sources.length,
      skipped: resolution.skipped,
      scopeFellBack: resolution.scopeFellBack,
      page: 1,
      matchMode: state.matchMode,
      types: state.types,
    );
    if (resolution.sources.isEmpty) {
      // 范围里一条可搜索的源都没有：不是「搜完没结果」，而是「没得搜」。
      state = state.copyWith(
        status: AggregateSearchStatus.failed,
        failureKind: ParseFailureKind.invalidBookSource,
      );

      return;
    }

    await _run(
      keyword: trimmed,
      sources: resolution.sources,
      page: 1,
      concurrency: concurrency,
    );
  }

  /// Asks every page-capable source for the next page and extends the list.
  Future<void> loadMore({
    required String keyword,
    required List<StoredBookSource> rows,
    required BookSearchScope scope,
  }) async {
    if (state.status != AggregateSearchStatus.done || !state.hasMore) {
      return;
    }
    final SearchSourceResolution resolution = resolveSearchSources(
      rows: rows,
      scope: scope,
      types: state.types,
    );
    final int concurrency = budgetOrDefault(
      ref.read(concurrencySettingProvider),
      ref.read(appLoggerProvider),
    );
    _pause = SearchPause();
    _cancellation = TaskCancellation();
    state = state.copyWith(
      status: AggregateSearchStatus.running,
      page: state.page + 1,
      isPaused: false,
      scopeFellBack: resolution.scopeFellBack,
    );

    await _run(
      keyword: keyword.trim(),
      sources: resolution.sources,
      page: state.page,
      concurrency: concurrency,
      // 继续往同一个 merger 里合并，避免「第 1 页的书被第 2 页的合并结果挤掉」。
      merger: _merger,
    );
  }

  /// Pauses the running search between two sources.
  void pause() {
    if (state.status != AggregateSearchStatus.running) {
      return;
    }
    _pause?.pause();
    state = state.copyWith(isPaused: true);
  }

  /// Resumes a paused search.
  void resume() {
    _pause?.resume();
    state = state.copyWith(isPaused: false);
  }

  /// Stops the running search; what was found stays on screen (ADR-0046 §决策 6).
  void cancel() => _cancellation?.cancel();

  /// Replaces the match mode of the **next** run.
  void setMatchMode(SearchMatchMode mode) =>
      state = state.copyWith(matchMode: mode);

  /// Replaces the source-type filter of the next run.
  void setTypes(Set<BookSourceType> types) =>
      state = state.copyWith(types: types);

  /// Runs one page and folds the outcome into the state.
  Future<void> _run({
    required String keyword,
    required List<BookSource> sources,
    required int page,
    required int concurrency,
    SearchResultMerger? merger,
  }) async {
    final ParseResult<AggregateSearchResult> result;
    try {
      result = await ref
          .read(aggregateSearchBooksProvider)
          .execute(
            AggregateSearchRequest(
              keyword: keyword,
              sources: sources,
              matchMode: state.matchMode,
              page: page,
              concurrency: concurrency,
            ),
            pause: _pause,
            cancellation: _cancellation,
            merger: merger,
            onProgress: (AggregateSearchResult progress) {
              _merger = progress.merger;
              state = state.copyWith(
                status: AggregateSearchStatus.running,
                books: progress.books,
                processedSources: progress.processedSources,
                totalSources: progress.totalSources,
                failedSources: progress.failedSources,
              );
            },
          );
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Aggregate search threw.', error, stackTrace);
      // 已经发布的命中不能被一次 "整批异常" 抹掉（用户看到的是「结果变少」，不是「结果消失」）。
      state = _settled(
        kind: ParseFailureKind.parseFailed,
        isCancelled: _cancellation?.isCancelled ?? false,
      );

      return;
    }

    switch (result) {
      case ParseFailure<AggregateSearchResult>(:final ParseFailureKind kind):
        // 取消不是失败：已找到的结果保留，状态回到 done（ADR-0046 §决策 6）。
        state = _settled(
          kind: kind,
          isCancelled: _cancellation?.isCancelled ?? false,
        );
      case ParseSuccess<AggregateSearchResult>(
        :final AggregateSearchResult data,
      ):
        _merger = data.merger;
        state = state.copyWith(
          status: AggregateSearchStatus.done,
          books: data.books,
          processedSources: data.processedSources,
          totalSources: data.totalSources,
          failedSources: data.failedSources,
          hasMore: data.hasMore,
          isPaused: false,
        );
    }
  }

  /// Folds a failed run into the state **without discarding hits already published**.
  ///
  /// A failure that *replaces* the list is the bug the user sees as “one broken source wiped every
  /// good result”: progress already delivered rows, and the failure path used to overwrite the whole
  /// screen with an error. So the rule is: keep the rows, and keep `done` when there is something to
  /// show; only an empty run reports `failed` (ADR-0046 §决策 5).
  AggregateSearchState _settled({
    required ParseFailureKind kind,
    required bool isCancelled,
  }) {
    final bool hasBooks = state.books.isNotEmpty;

    return state.copyWith(
      status: isCancelled || hasBooks
          ? AggregateSearchStatus.done
          : AggregateSearchStatus.failed,
      failureKind: isCancelled ? null : kind,
      hasMore: false,
      isPaused: false,
    );
  }
}

/// Derived facts the page reads off an [AggregateSearchState].
extension AggregateSearchStateX on AggregateSearchState {
  /// Whether a run is in flight (possibly paused).
  bool get isRunning => status == AggregateSearchStatus.running;

  /// Whether there are no hits to show although the run finished.
  bool get isEmptyResult =>
      status == AggregateSearchStatus.done && books.isEmpty;
}
