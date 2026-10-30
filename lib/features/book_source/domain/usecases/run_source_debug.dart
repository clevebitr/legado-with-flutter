import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_content.dart';
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

// 单次调试最多报告的结果地址数，避免长列表刷屏。
const int _maxReportedUrls = 3;

/// Runs one debug target against one source, reporting events as it goes.
///
/// A stop requested through [TaskCancellation] ends the run as cancelled between steps.
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

  // 搜索目标：关键词走 searchUrl，和真实搜索同一条路径。
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
    // 「来源」事件只报渲染成功的地址；渲染失败由搜索本身报告。
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

  // 上报的只是正文长度，正文本身永不进入控制台。
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
    // 控制台只给一个 URL：书名 / 章节名留空，规则会回落到书源变量。
    final ParseResult<ChapterContent> result = await _content.execute(
      source,
      ChapterRequest(url: chapterUrl),
    );
    if (_stopped(run, cancellation)) {
      return SourceDebugStatus.cancelled;
    }

    return switch (result) {
      ParseFailure<ChapterContent>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        run.fail(kind, rulePath: rulePath),
      ParseSuccess<ChapterContent>(:final ChapterContent data) => run.finish(
        'content: chars=${data.body.length}'
        '${data.title == null ? '' : ' title=${data.title}'}'
        '${data.lyric == null ? '' : ' lyric=${data.lyric!.length}'}',
      ),
    };
  }

  bool _stopped(_DebugRun run, TaskCancellation? cancellation) {
    if (cancellation?.isCancelled ?? false) {
      run.message('cancelled');

      return true;
    }

    return false;
  }

  List<String> _urlsOf(List<Book> books) => <String>[
    for (final Book book in books.take(_maxReportedUrls)) book.url,
  ];
}

// 一次调试运行的共享状态：事件出口与计时时钟。
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

  void message(String text) => _emit(SourceDebugEventKind.message, text: text);

  void source(String url) =>
      _emit(SourceDebugEventKind.source, text: url, url: url);

  // 逐条上报 URL，最后再发终态消息。
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

  SourceDebugStatus fail(ParseFailureKind kind, {required String rulePath}) {
    _emit(
      SourceDebugEventKind.error,
      text: rulePath,
      failureKind: kind,
      rulePath: rulePath,
    );

    return SourceDebugStatus.failed;
  }

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
