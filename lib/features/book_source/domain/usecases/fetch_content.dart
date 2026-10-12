import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';

/// Reads the body of one chapter (`PLAN.md` 2.4, `ruleContent`).
///
/// Paging follows `nextContentUrl` and the assembled body is purified by
/// `replaceRegex` (`PLAN.md` 3.5, `book-source.md` §4.1).
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
    final ParseResult<PageWalk> walk = await _pages.walk(
      url: url,
      rulePath: 'ruleContent',
      nextRule: source.contentRule.nextContentUrl,
      nextRulePath: 'contentRule.nextContentUrl',
      headers: source.headers,
      sourceId: source.url,
    );

    return switch (walk) {
      ParseFailure<PageWalk>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<String>(kind: kind, rulePath: failedAt),
      ParseSuccess<PageWalk>(:final PageWalk data) => await _read(source, data),
    };
  }

  /// Reads every walked page and joins the pieces into one body.
  ///
  /// A page that fails at any point fails the chapter, unlike the table of contents:
  /// a body missing its later pages is **not** a usable body, so returning the prefix
  /// as a success would hide the failure. §9 marks such a chapter failed instead.
  ///
  /// Pages are joined with a newline, the way upstream `appendContent` does
  /// (`BookContent.kt:70-76`), and the joined text is then purified once by the
  /// source's `replaceRegex` — upstream applies that rule to the assembled text, not
  /// to each page (`BookContent.kt:190-193`).
  Future<ParseResult<String>> _read(BookSource source, PageWalk walk) async {
    final ParseFailure<Never>? stopped = walk.stoppedBy;
    if (stopped != null) {
      return failureAt<String>(kind: stopped.kind, rulePath: stopped.rulePath);
    }

    final List<String> bodies = <String>[];

    for (final FetchedPage page in walk.pages) {
      final ParseResult<String> body = await _pages.content(
        source.contentRule.content,
        page.scope,
        'contentRule.content',
      );

      switch (body) {
        case ParseFailure<String>(
          :final ParseFailureKind kind,
          rulePath: final String failedAt,
        ):
          return failureAt<String>(kind: kind, rulePath: failedAt);
        case ParseSuccess<String>(:final String data):
          bodies.add(data);
      }
    }

    return ParseSuccess<String>(
      await _pages.replaceContent(
        source.contentRule.replaceRegex,
        bodies.join('\n'),
        'contentRule.replaceRegex',
        sourceId: source.url,
      ),
    );
  }
}
