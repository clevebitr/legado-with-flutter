import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/book_list_fields.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// Searches one book source for a keyword (`docs/dev/roadmap.md` 2.4, `searchUrl`).
final class SearchBooks {
  /// Creates the use case.
  const SearchBooks({required this._pages});

  final PageFetchService _pages;

  /// Searches [source] for [keyword] and returns the matching books.
  ///
  /// The keyword is rendered into `searchUrl` by `renderUrlTemplate`, which
  /// form-encodes it exactly once (C-SRC-5, `book-source.md` §4).
  ///
  /// Failures come back as a [ParseResult] instead of reaching the UI as an
  /// exception (C-ERR-1). An empty result list is a **success** — the source
  /// answered and found nothing — while a `bookList` rule that matched nothing is
  /// [ParseFailureKind.parseFailed] (`book-source.md` §7).
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

    // 书源自己的限速要在第一个请求之前进预算（book-source.md §8、ADR-0036）。
    _pages.applySourceRate(source);

    final ParseResult<String> rendered = await _pages.renderUrl(
      searchUrl,
      <String, String>{
        'key': keyword,
        'page': '$page',
        // `{{baseUrl}}` 是 M0 变量（§4）：当模板渲染，不必为一个纯量值拉起 JS 沙箱。
        'baseUrl': source.url,
      },
      rulePath: 'searchUrl',
      // 搜索 URL 还没有页面可读，所以 `baseUrl` 用书源自己的地址（上游 `AnalyzeUrl` 也
      // 以书源为基准）；`source` / `header` 随上下文带上，规则里的 `http.*` 要用它（C-NET-4）。
      context: JsPageContext(
        baseUrl: source.url,
        page: page,
        source: source.jsSourceInfo,
        headers: source.headers,
      ),
    );
    final String url;
    switch (rendered) {
      case ParseFailure<String>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<List<Book>>(kind: kind, rulePath: rulePath);
      case ParseSuccess<String>(:final String data):
        // §4：相对 searchUrl（`/search?q={{key}}`）以书源 URL 为基准解析成绝对地址。
        url = resolveAbsoluteUrl(data, source.url);
    }
    final ParseResult<RuleScope> response = await _pages.fetch(
      url,
      rulePath: 'searchUrl',
      headers: source.headers,
      keyword: keyword,
      sourceId: source.url,
      source: source.jsSourceInfo,
    );

    return switch (response) {
      ParseFailure<RuleScope>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Book>>(kind: kind, rulePath: failedAt),
      ParseSuccess<RuleScope>(:final RuleScope data) => await _read(
        source,
        url,
        data,
      ),
    };
  }

  /// Reads every search hit out of [scope] through the shared list reader.
  ///
  /// The nine list fields and `updateTime` are read by [readBooks], which the explore stage uses
  /// too: `SearchRule` and `ExploreRule` carry the same shape by upstream's `BookListRule`
  /// interface (`book-source.md` §2), so one reader keeps them from drifting apart.
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
