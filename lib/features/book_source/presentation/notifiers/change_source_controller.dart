import 'dart:async';

import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/search_source_resolver.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/aggregate_search_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/change_source_search.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'change_source_controller.freezed.dart';
part 'change_source_controller.g.dart';

/// The book a change-source page works on, plus where the reader currently is.
///
/// A record rather than a class: the notifier is a family keyed by it, and structural equality is
/// exactly what a provider argument needs.
typedef ChangeSourceTarget = ({
  String sourceUrl,
  String bookUrl,
  String name,
  String? author,
  String chapterName,
  int chapterIndex,
});

/// Where a change-source run stands.
enum ChangeSourceStatus {
  /// Nothing was searched yet: the page shows a 「开始搜索」 button.
  idle,

  /// Sources are being searched (or waiting while paused).
  searching,

  /// The run finished, with or without candidates.
  done,

  /// The search could not run at all (no source in scope, or every source failed).
  failed,
}

/// What the change-source page shows (ADR-0091 §决策 1–4).
@freezed
abstract class ChangeSourceState with _$ChangeSourceState {
  /// Creates a page state.
  const factory ChangeSourceState({
    /// Where the run stands.
    @Default(ChangeSourceStatus.idle) ChangeSourceStatus status,

    /// The keyword every source is searched with; defaults to the book's title.
    @Default('') String keyword,

    /// The candidates found so far, already ordered.
    @Default(<ChangeSourceCandidate>[]) List<ChangeSourceCandidate> candidates,

    /// How many sources finished (successfully or not).
    @Default(0) int processedSources,

    /// How many sources the scope resolved to.
    @Default(0) int totalSources,

    /// How many of them failed.
    @Default(0) int failedSources,

    /// Whether the user paused a running search.
    @Default(false) bool isPaused,

    /// Whether a candidate's author must contain the book's author.
    @Default(false) bool checkAuthor,

    /// Whether each candidate's detail page is read.
    @Default(false) bool loadInfo,

    /// Whether each candidate's chapter list is read (chapter count).
    @Default(false) bool loadToc,

    /// The source that just finished, for the progress line.
    String? currentSourceName,

    /// Why the run failed, when [status] is [ChangeSourceStatus.failed].
    ParseFailureKind? failureKind,

    /// The candidate the user picked; `null` on the list step.
    ChangeSourceCandidate? selected,

    /// The picked candidate's table of contents.
    @Default(<Chapter>[]) List<Chapter> chapters,

    /// The chapter to align to, or `-1` while the list is still empty.
    @Default(-1) int chapterIndex,

    /// Whether the picked candidate's table of contents is being read.
    @Default(false) bool isLoadingChapters,

    /// Why that chapter list could not be read.
    ParseFailureKind? chaptersFailure,
  }) = _ChangeSourceState;
}

/// The change-source page's state machine: search → pick a source → pick a chapter.
///
/// It is a family keyed by [ChangeSourceTarget] and auto-disposed, so leaving the page drops the
/// run; the switch itself is **not** performed here — the page answers the picked source and
/// chapter, and the caller (the detail page or the composition root) applies it (ADR-0091 §决策 1).
@riverpod
class ChangeSourceController extends _$ChangeSourceController {
  SearchPause? _pause;
  TaskCancellation? _cancellation;

  @override
  ChangeSourceState build(ChangeSourceTarget target) {
    // 页面被关掉（或 provider 重建）时把在跑的那批停下来：剩余的 worker 只会在两个源之间
    // 看到取消并退出，不会再回到一个已经销毁的 Ref 上写 state（真机日志里的
    // `UnmountedRefException` 就是漏了这一条）。
    ref.onDispose(() {
      _cancellation?.cancel();
      _pause?.resume();
    });

    return ChangeSourceState(keyword: target.name.trim());
  }

  /// Replaces the keyword typed by the user.
  void setKeyword(String keyword) => state = state.copyWith(keyword: keyword);

  /// Turns 「校验作者」 on or off; it applies to the next run.
  void setCheckAuthor({required bool enabled}) =>
      state = state.copyWith(checkAuthor: enabled);

  /// Turns 「加载详情」 on or off; it applies to the next run.
  void setLoadInfo({required bool enabled}) =>
      state = state.copyWith(loadInfo: enabled);

  /// Turns 「加载目录」 on or off; it applies to the next run.
  void setLoadToc({required bool enabled}) =>
      state = state.copyWith(loadToc: enabled);

  /// Runs the candidate search over the current scope.
  ///
  /// Nothing happens before this is called: the page's first frame is a button, not a spinner
  /// (`DECISIONS.md` #74).
  Future<void> start({required BookSearchScope scope}) async {
    final ChangeSourceTarget target = this.target;
    final List<StoredBookSource> rows = await ref.read(
      bookSourceListProvider.future,
    );
    if (!ref.mounted) {
      // 等书源表的这几帧里用户可能已经关掉页面：再往下走就是「对已销毁的 Ref 写状态」。
      return;
    }
    final SearchSourceResolution resolution = resolveSearchSources(
      rows: rows,
      scope: scope,
    );
    final List<BookSource> sources = <BookSource>[
      for (final BookSource source in resolution.sources)
        if (source.url != target.sourceUrl) source,
    ];
    _pause = SearchPause();
    _cancellation = TaskCancellation();
    state = state.copyWith(
      status: ChangeSourceStatus.searching,
      candidates: const <ChangeSourceCandidate>[],
      processedSources: 0,
      totalSources: sources.length,
      failedSources: 0,
      isPaused: false,
      failureKind: null,
      selected: null,
      chapters: const <Chapter>[],
      chapterIndex: -1,
      chaptersFailure: null,
    );
    if (sources.isEmpty) {
      // 范围里一条可搜的源都没有：不是「没这本书」，而是「没得搜」。
      state = state.copyWith(
        status: ChangeSourceStatus.failed,
        failureKind: ParseFailureKind.invalidBookSource,
      );

      return;
    }

    final ParseResult<List<ChangeSourceCandidate>> result;
    try {
      result = await ref
          .read(changeSourceSearchProvider)
          .execute(
            ChangeSourceRequest(
              keyword: state.keyword,
              author: target.author,
              sources: sources,
              checkAuthor: state.checkAuthor,
              loadInfo: state.loadInfo,
              loadToc: state.loadToc,
              concurrency: budgetOrDefault(
                ref.read(concurrencySettingProvider),
                ref.read(appLoggerProvider),
              ),
            ),
            pause: _pause,
            cancellation: _cancellation,
            onProgress: (ChangeSourceProgress progress) {
              // 页面关掉后 worker 还会把最后一个源跑完：这一帧不能再写状态。
              if (!ref.mounted) {
                return;
              }
              state = _searching(progress);
            },
          );
    } on Exception catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      ref
          .read(appLoggerProvider)
          .error('Change source search threw.', error, stackTrace);
      state = _settled(failureKind: ParseFailureKind.parseFailed);

      return;
    }
    if (!ref.mounted) {
      return;
    }

    switch (result) {
      case ParseFailure<List<ChangeSourceCandidate>>(
        :final ParseFailureKind kind,
      ):
        // 停止不是失败：已经找到的候选留在屏幕上（ADR-0091 §决策 1）。
        state = _settled(
          failureKind: (_cancellation?.isCancelled ?? false) ? null : kind,
        );
      case ParseSuccess<List<ChangeSourceCandidate>>(
        :final List<ChangeSourceCandidate> data,
      ):
        state = state.copyWith(
          status: ChangeSourceStatus.done,
          candidates: data,
          isPaused: false,
        );
    }
  }

  /// Pauses the run between two sources.
  void pause() {
    if (state.status != ChangeSourceStatus.searching) {
      return;
    }
    _pause?.pause();
    state = state.copyWith(isPaused: true);
  }

  /// Resumes a paused run.
  void resume() {
    _pause?.resume();
    state = state.copyWith(isPaused: false);
  }

  /// Stops the run; what was already found stays on screen.
  void stop() => _cancellation?.cancel();

  /// Moves to the chapter step for [candidate] and reads its table of contents.
  Future<void> openCandidate(ChangeSourceCandidate candidate) async {
    state = state.copyWith(
      selected: candidate,
      chapters: const <Chapter>[],
      chapterIndex: -1,
      isLoadingChapters: true,
      chaptersFailure: null,
    );
    final ChangeSourceTarget target = this.target;
    final ParseResult<List<Chapter>> toc = await ref
        .read(fetchTocProvider)
        .execute(
          candidate.source,
          candidate.tocUrl ?? candidate.book.url,
          bookName: candidate.book.name,
          bookUrl: candidate.book.url,
        );
    if (!ref.mounted) {
      return;
    }
    switch (toc) {
      case ParseSuccess<List<Chapter>>(:final List<Chapter> data):
        state = state.copyWith(
          chapters: data,
          chapterIndex: ref
              .read(switchBookSourceProvider)
              .alignChapterIndex(
                data,
                target.chapterName,
                fallbackIndex: target.chapterIndex,
              ),
          isLoadingChapters: false,
        );
      case ParseFailure<List<Chapter>>(:final ParseFailureKind kind):
        state = state.copyWith(
          isLoadingChapters: false,
          chaptersFailure: kind,
          // 目录读不到时仍然允许「换源」：对齐到读者原来那一章的序号，比什么都不做更接近
          // 他的位置（ADR-0051 §决策 3 的第三档回落）。
          chapterIndex: target.chapterIndex < 0 ? 0 : target.chapterIndex,
        );
    }
  }

  /// Goes back to the candidate list without dropping the run.
  void backToCandidates() => state = state.copyWith(
    selected: null,
    chapters: const <Chapter>[],
    chapterIndex: -1,
    chaptersFailure: null,
  );

  /// Picks the chapter to align to.
  void selectChapter(int index) {
    if (index < 0 || index >= state.chapters.length) {
      return;
    }
    state = state.copyWith(chapterIndex: index);
  }

  /// The state of a run that is still in flight.
  ChangeSourceState _searching(ChangeSourceProgress progress) => state.copyWith(
    status: ChangeSourceStatus.searching,
    candidates: progress.candidates,
    processedSources: progress.processedSources,
    totalSources: progress.totalSources,
    failedSources: progress.failedSources,
    currentSourceName: progress.currentSourceName,
  );

  /// The state of a run that just ended; already found candidates are kept.
  ChangeSourceState _settled({required ParseFailureKind? failureKind}) =>
      state.copyWith(
        status: state.candidates.isEmpty && failureKind != null
            ? ChangeSourceStatus.failed
            : ChangeSourceStatus.done,
        failureKind: failureKind,
        isPaused: false,
      );
}

/// The stored change-source scope; the only place that changes it (ADR-0091 §决策 5).
@Riverpod(keepAlive: true)
class ChangeSourceScopeSelection extends _$ChangeSourceScopeSelection {
  @override
  Future<BookSearchScope> build() async =>
      (await ref.watch(changeSourceScopeStoreProvider.future)).load();

  /// Replaces the scope and stores it.
  Future<void> select(BookSearchScope scope) async {
    await (await ref.read(changeSourceScopeStoreProvider.future)).save(scope);
    state = AsyncData<BookSearchScope>(scope);
  }
}
