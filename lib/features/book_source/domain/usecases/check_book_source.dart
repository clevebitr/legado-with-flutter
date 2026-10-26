import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_settings.dart';
import 'package:flutter_reader/features/book_source/domain/source_budget.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_failure.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_keyword.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/explore_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_explore_categories.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';

/// Runs the two upstream check chains against **one** book source (`docs/dev/roadmap.md` §5.10).
///
/// The order and the group tokens are upstream's (`BookSourceCheckRepository.kt:196-247`): a search
/// run followed by an explore run, each of which walks detail → table of contents → body on the
/// first book it found. The result is a [SourceCheckReport] — a **pure verdict** that writes
/// nothing. Whoever ran the check writes it back through the repository (ADR-0043 §决策 1).
///
/// Three behaviours are worth naming:
///
/// * **the stages are switchable** — a stage that is off is not attempted, and the body stages are
///   skipped whenever the detail stage is off, because without `ruleBookInfo` there is no `tocUrl`
///   to read;
/// * **the per-source timeout is a budget, not an interruption** — `defaultSourceCheckTimeout`
///   explains why the abandoned request keeps running on its own policy timeout;
/// * **cancellation is cooperative** — [TaskCancellation] is checked before every stage, so a stop
///   lands between requests and the report comes back as [SourceCheckStatus.cancelled] instead of a
///   failure (upstream's `Cancelled`, not `Failed + Incomplete`, ADR-0043 §后果).
final class CheckBookSource {
  /// Creates the use case.
  const CheckBookSource({
    required this._searchBooks,
    required this._exploreCategories,
    required this._exploreBooks,
    required this._bookInfo,
    required this._toc,
    required this._content,
    required this._clock,
    required this._logger,
  });

  final SearchBooks _searchBooks;
  final FetchExploreCategories _exploreCategories;
  final ExploreBooks _exploreBooks;
  final FetchBookInfo _bookInfo;
  final FetchToc _toc;
  final FetchContent _content;
  final Clock _clock;
  final AppLogger _logger;

  /// Checks [source] and returns its verdict.
  ///
  /// The failure branch is reserved for "there is nothing this call could check": a settings value
  /// with no stage switched on is a caller mistake rather than a verdict about the source, so it
  /// comes back as [ParseFailureKind.invalidBookSource] instead of a report that says "failed" for
  /// a source nobody touched.
  Future<ParseResult<SourceCheckReport>> execute(
    BookSource source,
    SourceCheckSettings settings, {
    TaskCancellation? cancellation,
  }) async {
    if (settings.stages.isEmpty) {
      _logger.warning(
        'Book source check has no stage to run: source=${source.url}',
      );

      return failureAt<SourceCheckReport>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'settings.stages',
      );
    }

    final DateTime startedAt = _clock.now();
    final _CheckRun run = _CheckRun(
      settings: settings,
      clock: _clock,
      // 一个源一份预算，跨全部阶段共用（§3.7-B7、ADR-0049）：前一阶段花掉的时间
      // 直接从后一阶段的余量里扣。
      budget: SourceBudget(settings.timeout, clock: _clock),
      cancellation: cancellation,
    );

    await _search(source, run);
    if (!run.isCancelled) {
      await _explore(source, run);
    }

    final int elapsedMillis = _clock.now().difference(startedAt).inMilliseconds;
    if (run.isCancelled) {
      return ParseSuccess<SourceCheckReport>(
        SourceCheckReport(
          status: SourceCheckStatus.cancelled,
          stages: run.stages,
          elapsedMillis: elapsedMillis,
        ),
      );
    }

    final SourceCheckReport report = SourceCheckReport(
      status: run.invalidGroups.isEmpty
          ? SourceCheckStatus.succeeded
          : SourceCheckStatus.failed,
      stages: run.stages,
      invalidGroups: run.invalidGroups,
      // 上游把「失效分组名」拼成异常消息再写进注释（`getInvalidGroupNames()` → `addErrorComment`），
      // 这里保留同一句话，用户看到的就是「哪几处失效」。
      errorComment: run.invalidGroups.isEmpty
          ? null
          : joinGroups(run.invalidGroups),
      elapsedMillis: elapsedMillis,
    );

    if (report.status == SourceCheckStatus.failed) {
      _logger.warning(
        'Book source check failed: source=${source.url} '
        'groups=${joinGroups(run.invalidGroups)}',
      );
    }

    return ParseSuccess<SourceCheckReport>(report);
  }

  /// Runs the search chain: keyword → first book → detail / table of contents / body.
  Future<void> _search(BookSource source, _CheckRun run) async {
    final String? searchUrl = source.searchUrl;
    if (searchUrl == null || searchUrl.trim().isEmpty) {
      // 上游 `checkSource`：搜索阶段开着但没搜索地址 → 打「搜索链接规则为空」，不是整次失败。
      run.recordFailure(
        SourceCheckStage.search,
        failureKind: ParseFailureKind.invalidBookSource,
        rulePath: 'searchUrl',
        invalidGroup: searchUrlMissingGroup,
      );

      return;
    }

    final String keyword = resolveCheckKeyword(
      checkKeyWord: source.searchRule.checkKeyWord,
      fallback: run.settings.keyword,
    );
    final List<Book>? books = await _stage(
      run,
      SourceCheckStage.search,
      isFromSearch: true,
      rulePath: 'searchUrl',
      emptyGroup: searchInvalidGroup,
      emptyRulePath: 'searchRule.bookList',
      operation: () => _searchBooks.execute(source, keyword),
    );
    if (books == null) {
      return;
    }

    await _checkBook(run, source, books.first, isFromSearch: true);
  }

  /// Runs the explore chain: first URL category → first book → detail / table of contents / body.
  ///
  /// A source without `exploreUrl` is **not** a failure here: upstream only checks the discover
  /// side when the source declares one (`BookSourceCheckRepository.kt:203`), so nothing is written.
  Future<void> _explore(BookSource source, _CheckRun run) async {
    final String? exploreUrl = source.exploreUrl;
    if (exploreUrl == null || exploreUrl.trim().isEmpty) {
      return;
    }

    final List<ExploreCategory>? categories = await _stage(
      run,
      SourceCheckStage.explore,
      isFromSearch: false,
      rulePath: 'exploreUrl',
      emptyGroup: exploreRuleMissingGroup,
      emptyRulePath: 'exploreRule.bookList',
      // 读分类是发现阶段的**前景**而不是它自己的阶段：成功不记一条结果，失败才记，
      // 否则一个阶段会跑出两条 outcome（UI 上的「阶段」就会重复）。
      recordsSuccess: false,
      operation: () => _exploreCategories.execute(source),
    );
    if (categories == null) {
      return;
    }

    // 分类解析已经拒掉了缺 URL 的条目（`book-source.md` §4.2），所以第一条就是可以打开的
    // 那一条 —— 上游 `firstOrNull { it.url.isNotBlank() }` 在这里等价于 `first`。
    final ExploreCategory category = categories.first;

    final List<Book>? books = await _stage(
      run,
      SourceCheckStage.explore,
      isFromSearch: false,
      rulePath: 'exploreUrl',
      emptyGroup: exploreInvalidGroup,
      operation: () => _exploreBooks.execute(source, category),
    );
    if (books == null) {
      return;
    }

    await _checkBook(run, source, books.first, isFromSearch: false);
  }

  /// Walks detail → table of contents → body for one book, stopping at the first broken stage.
  ///
  /// The three stages share one accumulator, so the group tokens keep the origin in their name
  /// (`搜索目录失效` vs `发现目录失效`): the user has to know **which** list the book came from to
  /// know where to look.
  Future<void> _checkBook(
    _CheckRun run,
    BookSource source,
    Book book, {
    required bool isFromSearch,
  }) async {
    // 上游 `checkBook`：详情阶段关掉就直接返回 —— 没有 ruleBookInfo 就拿不到 tocUrl，
    // 后面的目录 / 正文无从谈起。
    if (!run.settings.runs(SourceCheckStage.info)) {
      return;
    }

    final BookInfo? info = await _stage(
      run,
      SourceCheckStage.info,
      isFromSearch: isFromSearch,
      rulePath: 'ruleBookInfo',
      operation: () => _bookInfo.execute(source, book.url),
    );
    if (info == null || !run.settings.runs(SourceCheckStage.toc)) {
      return;
    }

    final List<Chapter>? chapters = await _stage(
      run,
      SourceCheckStage.toc,
      isFromSearch: isFromSearch,
      rulePath: 'ruleToc',
      emptyGroup: isFromSearch ? searchTocInvalidGroup : exploreTocInvalidGroup,
      emptyRulePath: 'tocRule.chapterList',
      operation: () => _toc.execute(source, info.tocUrl),
    );
    if (chapters == null || !run.settings.runs(SourceCheckStage.content)) {
      return;
    }

    await _stage(
      run,
      SourceCheckStage.content,
      isFromSearch: isFromSearch,
      rulePath: 'ruleContent',
      emptyGroup: isFromSearch
          ? searchContentInvalidGroup
          : exploreContentInvalidGroup,
      emptyRulePath: 'contentRule.content',
      // §6 / ADR-0049：校验也知道书名与章节名，顺手喂给 `java.get('bookName' / 'title')`。
      operation: () => _content.execute(
        source,
        ChapterRequest(
          url: chapters.first.url,
          title: chapters.first.name,
          bookName: info.name,
        ),
      ),
    );
  }

  /// Runs one stage and records its outcome, returning its data only when the stage was usable.
  ///
  /// [emptyGroup] turns a successful-but-empty result into a failure: a search page with no hits
  /// and a table of contents with no chapters are what a stale rule looks like, and upstream writes
  /// them into the group list instead of calling them success (`book-source.md` §7).
  Future<T?> _stage<T>(
    _CheckRun run,
    SourceCheckStage stage, {
    required bool isFromSearch,
    required String rulePath,
    required Future<ParseResult<T>> Function() operation,
    String? emptyGroup,
    String? emptyRulePath,
    bool recordsSuccess = true,
  }) async {
    if (run.isCancelled) {
      return null;
    }

    if (run.budget.isExpired) {
      run.recordTimeout(stage, rulePath: rulePath);

      return null;
    }

    // 单源预算（§3.7-B7）：只是「不再等」，底层请求仍按自己的策略超时结束
    // （ADR-0043 §后果），所以这里不发取消。
    final ParseResult<T> result = await run.budget.run(
      operation,
      rulePath: rulePath,
    );
    switch (result) {
      case ParseFailure<T>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        run.recordFailure(
          stage,
          failureKind: kind,
          rulePath: failedAt,
          invalidGroup: checkGroupForFailure(
            stage: stage,
            isFromSearch: isFromSearch,
            kind: kind,
            rulePath: failedAt,
          ),
        );

        return null;
      case ParseSuccess<T>(:final T data):
        if (emptyGroup != null && _isEmpty(data)) {
          run.recordFailure(
            stage,
            failureKind: ParseFailureKind.parseFailed,
            // 空结果指向**列表规则**：`searchUrl` 本身没错，是它读出来的东西不是列表。
            rulePath: emptyRulePath ?? rulePath,
            invalidGroup: emptyGroup,
          );

          return null;
        }
        if (recordsSuccess) {
          run.recordSuccess(stage);
        }

        return data;
    }
  }
}

/// Whether a stage's value counts as "nothing was read".
///
/// Lists and strings are the two shapes a stage can answer with, and both use the same meaning of
/// empty that `PageFetchService` applies to a top-level rule (`book-source.md` §7): a page whose
/// list matched nothing, or a body that is only whitespace, is what a stale rule looks like.
bool _isEmpty(Object? value) => switch (value) {
  final String text => text.trim().isEmpty,
  final Iterable<Object?> items => items.isEmpty,
  _ => false,
};

/// One check in progress: the outcomes so far, the groups it produced and its budget.
///
/// It is created per [CheckBookSource.execute] call and never escapes, which is what keeps the use
/// case itself stateless (ADR-0025: no state shared across calls, C-SRC-9).
final class _CheckRun {
  _CheckRun({
    required this.settings,
    required this.clock,
    required this.budget,
    this.cancellation,
  });

  final SourceCheckSettings settings;
  final Clock clock;
  final SourceBudget budget;
  final TaskCancellation? cancellation;
  final List<SourceCheckStageOutcome> stages = <SourceCheckStageOutcome>[];
  final List<String> invalidGroups = <String>[];

  /// Whether the user has asked to stop; the stages are checked against it one by one.
  bool get isCancelled => cancellation?.isCancelled ?? false;

  /// Records a stage that produced a usable value.
  void recordSuccess(SourceCheckStage stage) => stages.add(
    SourceCheckStageOutcome(stage: stage, status: SourceCheckStatus.succeeded),
  );

  /// Records a stage failure and the group token it writes into the source.
  void recordFailure(
    SourceCheckStage stage, {
    required ParseFailureKind failureKind,
    required String rulePath,
    required String invalidGroup,
  }) {
    stages.add(
      SourceCheckStageOutcome(
        stage: stage,
        status: SourceCheckStatus.failed,
        failureKind: failureKind,
        rulePath: rulePath,
        invalidGroup: invalidGroup,
      ),
    );
    if (!invalidGroups.contains(invalidGroup)) {
      invalidGroups.add(invalidGroup);
    }
  }

  /// Records the per-source budget running out at [stage].
  void recordTimeout(SourceCheckStage stage, {required String rulePath}) =>
      recordFailure(
        stage,
        failureKind: ParseFailureKind.networkTimeout,
        rulePath: rulePath,
        invalidGroup: checkTimeoutGroup,
      );
}
