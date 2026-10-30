import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/book_list_fields.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/source_login.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';

/// Searches one book source for a keyword through `searchUrl`.
final class SearchBooks {
  /// Creates the use case.
  const SearchBooks({required this._pages});

  final PageFetchService _pages;

  /// Searches [source] for [keyword] and returns the matching books.
  ///
  /// An empty list is a success; a `bookList` rule that matched nothing is a parse failure.
  Future<ParseResult<List<Book>>> execute(
    BookSource source,
    String keyword, {
    int page = 1,
  }) async {
    final String? searchUrl = source.searchUrl;
    if (searchUrl == null || searchUrl.trim().isEmpty) {
      _pages.warn('Book source cannot search: source=${source.url}');

      return failureAt<List<Book>>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'searchUrl',
      );
    }

    // 书源自己的限速要在第一个请求之前进预算。
    _pages.applySourceRate(source);
    // `header` 写成规则时也要在第一个请求之前求值。
    final Map<String, String>? headers = await _pages.headersOf(source);

    final ParseResult<FetchedPage> response = await _pages.fetchRule(
      searchUrl,
      rulePath: 'searchUrl',
      params: <String, String>{
        'key': keyword,
        'page': '$page',
        'baseUrl': source.url,
      },
      // 搜索 URL 还没有页面可读，`baseUrl` 用书源自己的地址；`source` / `header` 供规则里的 `http.*` 使用。
      context: JsPageContext(
        baseUrl: source.url,
        page: page,
        source: source.jsSourceInfo,
        headers: headers,
      ),
      headers: headers,
      keyword: keyword,
      sourceId: source.url,
      page: page,
      source: source.jsSourceInfo,
      login: source.loginGuard,
    );

    return switch (response) {
      ParseFailure<FetchedPage>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Book>>(kind: kind, rulePath: failedAt),
      ParseSuccess<FetchedPage>(:final FetchedPage data) => await _readPage(
        source,
        data,
      ),
    };
  }

  /// Reads the response, as a result list or — when the URL **is** a detail page — as one book
  /// (`bookUrlPattern`, ADR-0078 S2, upstream `BookList.kt:62-84`/`:100-110`).
  ///
  /// Two fallbacks live here, both upstream's:
  /// 1. `bookUrlPattern` matching the **final** URL means this search went straight to a detail
  ///    page: parse it with `ruleBookInfo` and answer a one-item list.
  /// 2. `bookList` matching nothing on a source that declares **no** pattern is usually a
  ///    single-book site as well, so the page is parsed as a detail page too instead of reporting
  ///    「搜索失效」.
  Future<ParseResult<List<Book>>> _readPage(
    BookSource source,
    FetchedPage page,
  ) async {
    if (_matchesBookUrlPattern(source, page.url)) {
      return _asSingleResult(source, page);
    }

    final ParseResult<List<Book>> list = await _read(
      source,
      page.url,
      page.scope,
    );
    if (_hasBookUrlPattern(source)) {
      return list;
    }
    // 没有 `bookUrlPattern` 时，`bookList` 空结果（或一条都没命中）按详情页再读一次
    // （BookList.kt:100-110）：单书站的搜索页往往就是书籍详情页。
    return switch (list) {
      ParseSuccess<List<Book>>(:final List<Book> data) when data.isEmpty =>
        _asSingleResult(source, page),
      ParseFailure<List<Book>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      )
          when kind == ParseFailureKind.parseFailed &&
              rulePath.contains('bookList') =>
        _asSingleResult(source, page),
      _ => list,
    };
  }

  bool _hasBookUrlPattern(BookSource source) {
    final String? pattern = source.bookUrlPattern;

    return pattern != null && pattern.trim().isNotEmpty;
  }

  /// Whether [url] is the detail page [source]'s `bookUrlPattern` describes.
  ///
  /// Full match, like Kotlin's `String.matches(regex)`; an unparsable pattern is a warning and a
  /// non-match — a broken pattern must not cost the search.
  bool _matchesBookUrlPattern(BookSource source, String url) {
    final String? pattern = source.bookUrlPattern;
    if (pattern == null || pattern.trim().isEmpty) {
      return false;
    }
    try {
      return RegExp('^(?:${pattern.trim()})\$').hasMatch(url);
    } on FormatException catch (error) {
      _pages.warn(
        'Ignoring an unusable bookUrlPattern: source=${source.url} '
        'pattern=$pattern error=${error.message}',
      );

      return false;
    }
  }

  // 详情页当一条搜索结果：字段来自 `ruleBookInfo`，地址就是这本书自己。
  Future<ParseResult<List<Book>>> _asSingleResult(
    BookSource source,
    FetchedPage page,
  ) async {
    final ParseResult<BookInfo> info = await FetchBookInfo(pages: _pages)
        .readFromPage(source, page);

    return switch (info) {
      ParseFailure<BookInfo>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Book>>(kind: kind, rulePath: failedAt),
      ParseSuccess<BookInfo>(:final BookInfo data) =>
        data.name.isEmpty
            ? seekSingleFromDetail(source, data)
            : ParseSuccess<List<Book>>(<Book>[_asSearchHit(data)]),
    };
  }

  /// Answers「no results」when a detail page yielded no name at all (upstream adds nothing).
  ///
  /// Upstream's `getInfoItem(...)?.let { ... }` simply adds no entry when the detail read produced
  /// nothing usable (`BookList.kt:70-78`), so a blank name is an empty result, not a failure.
  ParseResult<List<Book>> seekSingleFromDetail(
    BookSource source,
    BookInfo info,
  ) {
    _pages.warn(
      'Detail page yielded no book name: source=${source.url} url=${info.url}',
    );

    return const ParseSuccess<List<Book>>(<Book>[]);
  }

  static Book _asSearchHit(BookInfo info) => Book(
    name: info.name,
    url: info.url,
    author: info.author,
    kind: info.kind,
    coverUrl: info.coverUrl,
    intro: info.intro,
    lastChapter: info.lastChapter,
    wordCount: info.wordCount,
    updateTime: info.updateTime,
  );

  // 与发现页共用同一个列表读取器，避免两套字段解析漂移。
  Future<ParseResult<List<Book>>> _read(
    BookSource source,
    String baseUrl,
    RuleScope scope,
  ) => readBooks(
    _pages,
    source.searchRule.bookList,
    BookListFields.ofSearch(source.searchRule),
    scope,
    baseUrl: baseUrl,
    sourceId: source.url,
    fieldPrefix: 'searchRule',
    noun: 'Search hit',
  );
}
