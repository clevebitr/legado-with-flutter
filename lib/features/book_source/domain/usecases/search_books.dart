import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/book_list_fields.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';

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
    );

    return switch (response) {
      ParseFailure<FetchedPage>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Book>>(kind: kind, rulePath: failedAt),
      ParseSuccess<FetchedPage>(:final FetchedPage data) => await _read(
        source,
        data.url,
        data.scope,
      ),
    };
  }

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
