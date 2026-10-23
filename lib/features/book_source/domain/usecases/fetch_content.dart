import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';

/// Reads the body of one chapter (`docs/dev/roadmap.md` 2.4, `ruleContent`).
///
/// Paging follows `nextContentUrl` and the assembled body is purified by
/// `replaceRegex` (`docs/dev/roadmap.md` 3.5, `book-source.md` §4.1). A finished body is remembered in
/// [ContentCache], so re-entering the same chapter costs no request (`docs/dev/roadmap.md` 5.2).
final class FetchContent {
  /// Creates the use case.
  const FetchContent({required this._pages, required this._cache});

  final PageFetchService _pages;
  final ContentCache _cache;

  /// Fetches [request]'s URL and returns the chapter body as plain text.
  ///
  /// A `content` rule that matched nothing is [ParseFailureKind.parseFailed]
  /// (`book-source.md` §7), because "the page has no body where the rules expect one"
  /// is exactly what a stale rule looks like.
  ///
  /// The cache is consulted **before** anything else — including before the source's rate
  /// declaration, because a hit means this operation sends no request at all — and only a
  /// **successful** body is stored, so a failure is never cached as content.
  /// [request] carries the chapter URL plus the two values a rule may read as
  /// `java.get('bookName')` / `java.get('title')` (`book-source.md` §6, ADR-0049).
  Future<ParseResult<String>> execute(
    BookSource source,
    ChapterRequest request,
  ) async {
    final String url = request.url;
    final String? cached = await _cache.read(sourceId: source.url, url: url);
    if (cached != null) {
      return ParseSuccess<String>(cached);
    }

    // 书源自己的限速要在第一个请求之前进预算（book-source.md §8、ADR-0036）。
    _pages.applySourceRate(source);
    // `header` 写成规则时要在**第一个请求之前**求值（book-source.md §2、M12-A2）。
    final Map<String, String>? headers = await _pages.headersOf(source);
    final ParseResult<PageWalk> walk = await _pages.walk(
      rule: url,
      rulePath: 'ruleContent',
      nextRule: source.contentRule.nextContentUrl,
      nextRulePath: 'contentRule.nextContentUrl',
      context: JsPageContext(
        baseUrl: url,
        source: source.jsSourceInfo,
        headers: headers,
        bookName: request.bookName,
        chapterTitle: request.title,
      ),
      headers: headers,
      sourceId: source.url,
      source: source.jsSourceInfo,
    );

    return switch (walk) {
      ParseFailure<PageWalk>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<String>(kind: kind, rulePath: failedAt),
      ParseSuccess<PageWalk>(:final PageWalk data) => await _read(
        source,
        url,
        data,
      ),
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
  Future<ParseResult<String>> _read(
    BookSource source,
    String url,
    PageWalk walk,
  ) async {
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

    final String content = await _pages.replaceContent(
      source.contentRule.replaceRegex,
      bodies.join('\n'),
      'contentRule.replaceRegex',
      sourceId: source.url,
      // 净化规则拿得到它读的那一页：上游 `getString(replaceRegex, contentStr)` 同样有上下文。
      jsContext: JsPageContext(
        baseUrl: walk.pages.first.url,
        source: source.jsSourceInfo,
      ),
    );
    // 缓存的是**成品**：分页已拼好、`replaceRegex` 已跑过，所以命中可以直接跳过整个引擎。
    // 写只发生在成功路径上：失败在前面就已经返回，不会被当成内容存下来。
    await _cache.write(sourceId: source.url, url: url, body: content);

    return ParseSuccess<String>(content);
  }
}
