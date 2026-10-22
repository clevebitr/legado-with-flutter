import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/book_list_fields.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';

/// Opens one discover-page category and reads its book list (`book-source.md` §4.2).
///
/// Two decisions live here, and this is their only implementation point:
///
/// * **which rule set reads the page** — `ruleExplore` when it declares a `bookList`, otherwise the
///   **whole** `searchRule` (ADR-0035 §决策 2). The fallback is per rule set, never per field: a
///   page read half by one rule and half by the other is exactly the situation where “the list
///   count does not add up” cannot be explained;
/// * **the category URL** is rendered through the shared URL path (C-SRC-5), so `{{page}}` /
///   `{{baseUrl}}` keep their template semantics and every other `{{…}}` stays in the sandbox,
///   with a rule head refused by name (`book-source.md` §4, matrix #18).
///
/// One call reads **one page**: the page number comes from the caller and the stage never walks
/// pages on its own, so it does not spend the paging bound of §9 (ADR-0035 §决策 5). A single
/// failed category therefore only costs that category.
final class ExploreBooks {
  /// Creates the use case.
  const ExploreBooks({required this._pages});

  final PageFetchService _pages;

  /// Fetches [category] and reads the books it lists.
  ///
  /// [page] is the 1-based page number the URL template renders with, defaulting to the first
  /// page; the discover page has no keyword, so no `key` is bound anywhere on this path
  /// (ADR-0035 §决策 5).
  Future<ParseResult<List<Book>>> execute(
    BookSource source,
    ExploreCategory category, {
    int page = 1,
  }) async {
    // 书源自己的限速要在第一个请求之前进预算（book-source.md §8、ADR-0036）。
    _pages.applySourceRate(source);
    // `header` 写成规则时要在**第一个请求之前**求值（book-source.md §2、M12-A2）。
    final Map<String, String>? headers = await _pages.headersOf(source);

    final ExploreRule? explore = source.exploreRule;
    final bool fallsBack =
        explore == null || (explore.bookList ?? '').trim().isEmpty;
    final BookListFields fields = fallsBack
        ? BookListFields.ofSearch(source.searchRule)
        : BookListFields.ofExplore(explore);
    final String listRule = fallsBack
        ? (source.searchRule.bookList ?? '')
        : (explore.bookList ?? '');
    final String fieldPrefix = fallsBack ? 'searchRule' : 'exploreRule';

    // 分类 URL 也是一条 **URL 规则**：它可以带 `,{…}` 后缀（POST / charset），见
    // `book-source.md` §4.3，所以走同一台 fetchRule。
    final ParseResult<FetchedPage> response = await _pages.fetchRule(
      category.url,
      rulePath: 'exploreUrl',
      params: <String, String>{'page': '$page', 'baseUrl': source.url},
      context: JsPageContext(
        baseUrl: source.url,
        page: page,
        source: source.jsSourceInfo,
        headers: headers,
      ),
      headers: headers,
      sourceId: source.url,
      source: source.jsSourceInfo,
    );

    return switch (response) {
      ParseFailure<FetchedPage>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<List<Book>>(kind: kind, rulePath: rulePath),
      ParseSuccess<FetchedPage>(:final FetchedPage data) => await readBooks(
        _pages,
        listRule,
        fields,
        data.scope,
        baseUrl: data.url,
        sourceId: source.url,
        fieldPrefix: fieldPrefix,
        noun: 'Explore item',
      ),
    };
  }
}
