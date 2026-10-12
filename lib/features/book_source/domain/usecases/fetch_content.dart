import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';

/// Reads the body of one chapter (`PLAN.md` 2.4, `ruleContent`).
///
/// Paging (`nextContentUrl`) and `replaceRegex` belong to `PLAN.md` 3.5, so this
/// stage reads exactly the page it is given.
final class FetchContent {
  /// Creates the use case.
  const FetchContent({required this._pages});

  final PageFetchService _pages;

  /// Fetches [url] and returns the chapter body as plain text.
  ///
  /// A `content` rule that matched nothing is [ParseFailureKind.parseFailed]
  /// (`book-source.md` §7), because "the page has no body where the rules expect one"
  /// is exactly what a stale rule looks like.
  Future<ParseResult<String>> execute(BookSource source, String url) async {
    final ParseResult<RuleScope> page = await _pages.fetch(
      url,
      rulePath: 'ruleContent',
      headers: source.headers,
      sourceId: source.url,
    );

    return switch (page) {
      ParseFailure<RuleScope>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<String>(kind: kind, rulePath: failedAt),
      ParseSuccess<RuleScope>(:final RuleScope data) => _pages.content(
        source.contentRule.content,
        data,
        'contentRule.content',
      ),
    };
  }
}
