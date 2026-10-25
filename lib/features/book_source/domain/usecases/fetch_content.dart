import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_reader/features/book_source/domain/content_purifier.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/source_login.dart';
import 'package:html/parser.dart' as html_parser;

/// Reads the body of one chapter (`docs/dev/roadmap.md` 2.4, `ruleContent`).
///
/// Paging follows `nextContentUrl` and the assembled body is purified by
/// `replaceRegex` (`docs/dev/roadmap.md` 3.5, `book-source.md` §4.1) and then by the user's
/// 替换净化 rules (`docs/dev/roadmap.md` M20, ADR-0070 §决策 3). A finished body is remembered in
/// [ContentCache], so re-entering the same chapter costs no request (`docs/dev/roadmap.md` 5.2).
final class FetchContent {
  /// Creates the use case.
  const FetchContent({
    required this._pages,
    required this._cache,
    this._purifier = const ContentPurifier(),
  });

  final PageFetchService _pages;
  final ContentCache _cache;

  /// The user's purge rules; the default purges nothing, which is what「没接上净化」looks like.
  final ContentPurifier _purifier;

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

    // `ruleContent.webJs`（M21a，ADR-0068 §决策 7）：正文页必须由 WebView 渲染后才能在页面里
    // 执行脚本。这条路径不跟 `nextContentUrl` 翻页——脚本产出的是整段正文，再翻页没有语义。
    final String? webJs = source.contentRule.webJs;
    if (webJs != null && webJs.trim().isNotEmpty) {
      return _readRendered(source, request, webJs, headers);
    }

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
        book: JsBookInfo(
          name: request.bookName,
          author: request.author,
          bookUrl: request.bookUrl,
          tocUrl: request.tocUrl,
          intro: request.intro,
          kind: request.kind,
        ),
      ),
      headers: headers,
      sourceId: source.url,
      source: source.jsSourceInfo,
      login: source.loginGuard,
      // `ruleContent.sourceRegex`：截取后的片段才是规则读的页面（ADR-0068 §决策 7）。
      sourceRegex: source.contentRule.sourceRegex,
    );

    return switch (walk) {
      ParseFailure<PageWalk>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<String>(kind: kind, rulePath: failedAt),
      ParseSuccess<PageWalk>(:final PageWalk data) => await _read(
        source,
        request,
        data,
      ),
    };
  }

  /// Reads a chapter whose page must be rendered before its script can run (`webJs`).
  ///
  /// The rendered body becomes the scope of `ruleContent.content`, and the result goes through the
  /// same `replaceRegex` + cache as a plain read, so the rest of the pipeline cannot tell the two
  /// paths apart.
  Future<ParseResult<String>> _readRendered(
    BookSource source,
    ChapterRequest request,
    String webJs,
    Map<String, String>? headers,
  ) async {
    final ParseResult<String> rendered = await _pages.fetchRendered(
      request.url,
      rulePath: 'contentRule.webJs',
      script: webJs,
      headers: headers,
      sourceId: source.url,
      source: source.jsSourceInfo,
      bookName: request.bookName,
      chapterTitle: request.title,
    );
    final String html;
    switch (rendered) {
      case ParseFailure<String>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        return failureAt<String>(kind: kind, rulePath: failedAt);
      case ParseSuccess<String>(:final String data):
        html = data;
    }

    final ParseResult<String> body = await _pages.content(
      source.contentRule.content,
      RuleScope.dom(
        html_parser.parse(html),
        body: html,
        jsContext: JsPageContext(
          baseUrl: request.url,
          source: source.jsSourceInfo,
          headers: headers,
          bookName: request.bookName,
          chapterTitle: request.title,
          book: JsBookInfo(
            name: request.bookName,
            author: request.author,
            bookUrl: request.bookUrl,
            tocUrl: request.tocUrl,
            intro: request.intro,
            kind: request.kind,
          ),
        ),
      ),
      'contentRule.content',
    );
    final String text;
    switch (body) {
      case ParseFailure<String>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        return failureAt<String>(kind: kind, rulePath: failedAt);
      case ParseSuccess<String>(:final String data):
        text = data;
    }

    final String content = await _purifier.purge(
      await _pages.replaceContent(
        source.contentRule.replaceRegex,
        text,
        'contentRule.replaceRegex',
        sourceId: source.url,
        jsContext: JsPageContext(
          baseUrl: request.url,
          source: source.jsSourceInfo,
        ),
      ),
    );
    await _cache.write(
      sourceId: source.url,
      url: request.url,
      body: content,
      bookUrl: request.bookUrl,
    );

    return ParseSuccess<String>(content);
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
    ChapterRequest request,
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

    final String content = await _purifier.purge(
      await _pages.replaceContent(
        source.contentRule.replaceRegex,
        bodies.join('\n'),
        'contentRule.replaceRegex',
        sourceId: source.url,
        // 净化规则拿得到它读的那一页：上游 `getString(replaceRegex, contentStr)` 同样有上下文。
        jsContext: JsPageContext(
          baseUrl: walk.pages.first.url,
          source: source.jsSourceInfo,
        ),
      ),
    );
    // 缓存的是**成品**：分页已拼好、`replaceRegex` 与净化规则都已跑过，所以命中可直接跳过整个引擎。
    // 也正因为如此，改净化规则必须作废缓存（ADR-0070 增补 §7）。
    // 写只发生在成功路径上：失败在前面就已经返回，不会被当成内容存下来。
    await _cache.write(
      sourceId: source.url,
      url: request.url,
      body: content,
      // 章节正文知道它属于哪本书（`bookUrl` 本来就在请求上下文里），按书缓存因此不需要新参数。
      bookUrl: request.bookUrl,
    );

    return ParseSuccess<String>(content);
  }
}
