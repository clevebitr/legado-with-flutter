import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_debug.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/explore_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';

/// How many result URLs one debug run reports, so a long list does not flood the console.
const int _maxReportedUrls = 3;

/// Runs **one** target of the debug console against one source (`docs/dev/roadmap.md` §5.10).
///
/// The run reports through the event sink as it goes — that is what makes the console live — and
/// answers with the terminal [SourceDebugStatus]. The three event kinds are the console's whole
/// contract:
///
/// * **message** — what the run is doing (`search: books=12`, `content: chars=1532`);
/// * **source** — the URL it just touched, so a user can open it in a browser;
/// * **error** — a `ParseResult` failure, with its kind and rule path kept verbatim.
///
/// Every payload is **data**, never interface copy and never a page body (C-SEC-4, C-ERR-8): ARB
/// owns the labels the page puts next to a line. A stop requested through [TaskCancellation] ends
/// the run as [SourceDebugStatus.cancelled] between two steps.
final class RunSourceDebug {
  /// Creates the use case.
  const RunSourceDebug({
    required this._pages,
    required this._searchBooks,
    required this._exploreBooks,
    required this._bookInfo,
    required this._toc,
    required this._content,
    required this._clock,
  });

  final PageFetchService _pages;
  final SearchBooks _searchBooks;
  final ExploreBooks _exploreBooks;
  final FetchBookInfo _bookInfo;
  final FetchToc _toc;
  final FetchContent _content;
  final Clock _clock;

  /// Runs [target] on [source] with [query], reporting every step to [onEvent].
  ///
  /// The failure branch is the caller's mistake — a blank query means there is nothing to run —
  /// rather than a verdict about the source, which travels through the event stream instead.
  Future<ParseResult<SourceDebugStatus>> execute(
    BookSource source, {
    required SourceDebugTarget target,
    required String query,
    required void Function(SourceDebugEvent event) onEvent,
    TaskCancellation? cancellation,
  }) async {
    final String value = query.trim();
    if (value.isEmpty) {
      return failureAt<SourceDebugStatus>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'sourceDebug.query',
      );
    }

    final DateTime startedAt = _clock.now();
    final _DebugRun run = _DebugRun(
      target: target,
      startedAt: startedAt,
      clock: _clock,
      onEvent: onEvent,
    );

    final SourceDebugStatus status = switch (target) {
      SourceDebugTarget.search => await _search(
        source,
        value,
        run,
        cancellation,
      ),
      SourceDebugTarget.explore => await _explore(
        source,
        value,
        run,
        cancellation,
      ),
      SourceDebugTarget.info => await _info(source, value, run, cancellation),
      SourceDebugTarget.toc => await _tocRun(source, value, run, cancellation),
      SourceDebugTarget.content => await _contentRun(
        source,
        value,
        run,
        cancellation,
      ),
    };

    return ParseSuccess<SourceDebugStatus>(status);
  }

  /// Runs the search target: the keyword goes through `searchUrl` like a real search.
  Future<SourceDebugStatus> _search(
    BookSource source,
    String keyword,
    _DebugRun run,
    TaskCancellation? cancellation,
  ) async {
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    final String? searchUrl = source.searchUrl;
    if (searchUrl == null || searchUrl.trim().isEmpty) {
      return run.fail(
        ParseFailureKind.invalidBookSource,
        rulePath: 'searchUrl',
      );
    }

    run.message('search: keyword=$keyword');
    // 「来源」事件要报的是真正发出去的地址：渲染失败时不报，搜索本身会把失败讲清楚。
    final ParseResult<String> rendered = await _pages.renderUrl(
      searchUrl,
      <String, String>{'key': keyword, 'page': '1', 'baseUrl': source.url},
      rulePath: 'searchUrl',
      context: JsPageContext(
        baseUrl: source.url,
        source: source.jsSourceInfo,
        headers: source.headers,
      ),
    );
    if (rendered case ParseSuccess<String>(:final String data)) {
      run.source(data);
    }

    final ParseResult<List<Book>> result = await _searchBooks.execute(
      source,
      keyword,
    );
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    return switch (result) {
      ParseFailure<List<Book>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        run.fail(kind, rulePath: rulePath),
      ParseSuccess<List<Book>>(:final List<Book> data) => run.finish(
        'search: books=${data.length}',
        urls: _urlsOf(data),
      ),
    };
  }

  /// Runs the explore target: [categoryUrl] is opened as a discover-page category.
  Future<SourceDebugStatus> _explore(
    BookSource source,
    String categoryUrl,
    _DebugRun run,
    TaskCancellation? cancellation,
  ) async {
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    run.source(categoryUrl);
    final ParseResult<List<Book>> result = await _exploreBooks.execute(
      source,
      ExploreCategory(title: categoryUrl, url: categoryUrl),
    );
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    return switch (result) {
      ParseFailure<List<Book>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        run.fail(kind, rulePath: rulePath),
      ParseSuccess<List<Book>>(:final List<Book> data) => run.finish(
        'explore: books=${data.length}',
        urls: _urlsOf(data),
      ),
    };
  }

  /// Runs the detail target on the book URL in [bookUrl].
  Future<SourceDebugStatus> _info(
    BookSource source,
    String bookUrl,
    _DebugRun run,
    TaskCancellation? cancellation,
  ) async {
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    run.source(bookUrl);
    final ParseResult<BookInfo> result = await _bookInfo.execute(
      source,
      bookUrl,
    );
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    return switch (result) {
      ParseFailure<BookInfo>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        run.fail(kind, rulePath: rulePath),
      ParseSuccess<BookInfo>(:final BookInfo data) => run.finish(
        'info: name=${data.name}',
        urls: <String>[data.tocUrl],
      ),
    };
  }

  /// Runs the table-of-contents target on the table-of-contents URL.
  Future<SourceDebugStatus> _tocRun(
    BookSource source,
    String tocUrl,
    _DebugRun run,
    TaskCancellation? cancellation,
  ) async {
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    run.source(tocUrl);
    final ParseResult<List<Chapter>> result = await _toc.execute(
      source,
      tocUrl,
    );
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    return switch (result) {
      ParseFailure<List<Chapter>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        run.fail(kind, rulePath: rulePath),
      ParseSuccess<List<Chapter>>(:final List<Chapter> data) => run.finish(
        'toc: chapters=${data.length}',
        urls: <String>[for (final Chapter chapter in data) chapter.url],
      ),
    };
  }

  /// Runs the body target on the chapter URL.
  ///
  /// The reported payload is the **length** of the body; the text itself never reaches the console
  /// (C-SEC-4).
  Future<SourceDebugStatus> _contentRun(
    BookSource source,
    String chapterUrl,
    _DebugRun run,
    TaskCancellation? cancellation,
  ) async {
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    run.source(chapterUrl);
    // 控制台只拿到一个 URL：书名 / 章节名留空，`java.get('bookName' / 'title')` 会回落到
    // 书源变量（§6、ADR-0049）。
    final ParseResult<String> result = await _content.execute(
      source,
      ChapterRequest(url: chapterUrl),
    );
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    return switch (result) {
      ParseFailure<String>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        run.fail(kind, rulePath: rulePath),
      ParseSuccess<String>(:final String data) => run.finish(
        'content: chars=${data.length}',
      ),
    };
  }

  /// Whether a stop was requested before this step started.
  bool _stopped(_DebugRun run, TaskCancellation? cancellation) {
    if (cancellation?.isCancelled ?? false) {
      run.message('cancelled');

      return true;
    }

    return false;
  }

  /// At most [_maxReportedUrls] URLs of [books], so a 300-hit search stays readable.
  List<String> _urlsOf(List<Book> books) => <String>[
    for (final Book book in books.take(_maxReportedUrls)) book.url,
  ];
}

/// One debug run: the event sink plus the clock the elapsed times are measured on.
final class _DebugRun {
  _DebugRun({
    required this.target,
    required this.startedAt,
    required this.clock,
    required this.onEvent,
  });

  final SourceDebugTarget target;
  final DateTime startedAt;
  final Clock clock;
  final void Function(SourceDebugEvent event) onEvent;

  /// Reports a message line.
  void message(String text) => _emit(SourceDebugEventKind.message, text: text);

  /// Reports a URL the run touched.
  void source(String url) =>
      _emit(SourceDebugEventKind.source, text: url, url: url);

  /// Reports one URL line per entry of [urls], then the terminal message.
  SourceDebugStatus finish(
    String text, {
    List<String> urls = const <String>[],
  }) {
    for (final String url in urls.take(_maxReportedUrls)) {
      source(url);
    }
    message(text);

    return SourceDebugStatus.succeeded;
  }

  /// Reports a failure line and answers with the terminal state.
  SourceDebugStatus fail(ParseFailureKind kind, {required String rulePath}) {
    _emit(
      SourceDebugEventKind.error,
      text: rulePath,
      failureKind: kind,
      rulePath: rulePath,
    );

    return SourceDebugStatus.failed;
  }

  /// Emits one line with the elapsed time measured from the start of the run.
  void _emit(
    SourceDebugEventKind kind, {
    required String text,
    String? url,
    ParseFailureKind? failureKind,
    String? rulePath,
  }) => onEvent(
    SourceDebugEvent(
      kind: kind,
      target: target,
      text: text,
      url: url,
      failureKind: failureKind,
      rulePath: rulePath,
      elapsedMillis: clock.now().difference(startedAt).inMilliseconds,
    ),
  );
}
