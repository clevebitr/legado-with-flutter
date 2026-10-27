import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_reader/features/book_source/domain/content_purifier.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_content.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/html_to_text.dart';
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

  /// Fetches [request]'s URL and returns the chapter as a [ChapterContent].
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
  ///
  /// The cache holds the **whole** result, not just the text: a cached read still has to answer the
  /// content-page title and the audio lyrics, and re-fetching for them would defeat the cache.
  Future<ParseResult<ChapterContent>> execute(
    BookSource source,
    ChapterRequest request,
  ) async {
    final String url = request.url;
    final String? cached = await _cache.read(sourceId: source.url, url: url);
    if (cached != null) {
      return ParseSuccess<ChapterContent>(_decode(cached));
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
        // 正文阶段的两条全局绑定（M25/S3b）：`chapter` 是正在读的这一章，`nextChapterUrl` 是目录里
        // 它后面那条地址（上游由 ReadBookViewModel 设进 AnalyzeRule）。
        chapter: JsChapterInfo(
          title: request.title,
          url: url,
          isVip: request.isVip,
          isPay: request.isPay,
          isVolume: request.isVolume,
          updateTime: request.updateTime,
        ),
        nextChapterUrl: request.nextChapterUrl,
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
        failureAt<ChapterContent>(kind: kind, rulePath: failedAt),
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
  Future<ParseResult<ChapterContent>> _readRendered(
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
        return failureAt<ChapterContent>(kind: kind, rulePath: failedAt);
      case ParseSuccess<String>(:final String data):
        html = data;
    }

    final RuleScope pageScope = RuleScope.dom(
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
    );
    final ParseResult<String> body = await _pages.content(
      source.contentRule.content,
      pageScope,
      'contentRule.content',
    );
    final String text;
    switch (body) {
      case ParseFailure<String>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        return failureAt<ChapterContent>(kind: kind, rulePath: failedAt);
      case ParseSuccess<String>(:final String data):
        text = data;
    }

    return _finish(
      source: source,
      request: request,
      pageScope: pageScope,
      body: text,
      headers: headers,
    );
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
  Future<ParseResult<ChapterContent>> _read(
    BookSource source,
    ChapterRequest request,
    PageWalk walk,
  ) async {
    final ParseFailure<Never>? stopped = walk.stoppedBy;
    if (stopped != null) {
      return failureAt<ChapterContent>(
        kind: stopped.kind,
        rulePath: stopped.rulePath,
      );
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
          return failureAt<ChapterContent>(kind: kind, rulePath: failedAt);
        case ParseSuccess<String>(:final String data):
          bodies.add(data);
      }
    }

    return _finish(
      source: source,
      request: request,
      pageScope: walk.pages.first.scope,
      body: bodies.join('\n'),
    );
  }

  /// Finishes one chapter: sub-content, content-page title, then `replaceRegex` + the user's purge
  /// rules, then the cache write (ADR-0078 S2).
  ///
  /// Upstream's order is exactly this one (`BookContent.kt:144-196`): `content` loop →
  /// `subContent` → `title` → `replaceRegex`. It matters: `replaceRegex` is documented to run on
  /// the **assembled** text, so sub-content must already be in it, and the title rule must see the
  /// first page's scope, not the replaced text.
  ///
  /// [headers] is only used by the page the sub-content rule may point at.
  Future<ParseResult<ChapterContent>> _finish({
    required BookSource source,
    required ChapterRequest request,
    required RuleScope pageScope,
    required String body,
    Map<String, String>? headers,
  }) async {
    final ContentRule rules = source.contentRule;
    String text = body;

    // 副文（`subContent`）：文本源追加到正文，音频源作为歌词交给调用方（上游把后者写成章节变量
    // `lyric`）。规则给出 http(s) 地址时先取那一页的正文——上游同样先下载再用。
    final ParseResult<String?> sub = await _pages.field(
      rules.subContent,
      pageScope,
      'contentRule.subContent',
      sourceId: source.url,
    );
    String? lyric;
    final String subContent = sub.dataOrNull ?? '';
    if (subContent.isNotEmpty) {
      final String resolved = await _subContentText(
        source: source,
        request: request,
        value: subContent,
        headers: headers,
      );
      if (source.sourceType == BookSourceType.audio) {
        // 空副文等于没有歌词：留 `null`，别把空串当成「有歌词但是空的」交给调用方。
        lyric = resolved.isEmpty ? null : resolved;
      } else if (resolved.isNotEmpty) {
        // 上游 `appendContent(subContent)`：换行分隔，与分页拼接同一形状。
        text = '$text\n$resolved';
      }
    }

    // 正文页的章节名（`title`）：站点常常只在正文页给真名，还可能在名字里带一张 reviewImg。
    final ParseResult<String?> titleRule = await _pages.field(
      rules.title,
      pageScope,
      'contentRule.title',
      sourceId: source.url,
    );
    final _ContentTitle title = _titleOf(
      titleRule.dataOrNull,
      fallback: request.title,
    );

    // 正文在**统一成纯文本之后**才交给 `replaceRegex` 与净化规则。
    //
    // 上游把正文当 HTML 留着、由自己的富文本视图渲染；本仓的阅读端是纯文本
    // （`readerBodyText` 按换行分段），所以 `@html` / `@all` / 脚本 `outerHTML` 产出的标签必须
    // 在这里摘掉，否则语料里 249 条 `content` 规则中的 83 条会把 `<p>` / `<br>` 印在页面上。
    //
    // 顺序有意把转换放在 `replaceRegex` **之前**：这些替换规则是用户/作者对着**能读的正文**写的
    // （`&nbsp;`、`\<.*` 这类清理 HTML 残留的写法），让它们继续面对标签只会把真文字一起删掉。
    // 差异登记在 `book-source.md` §4.3。
    text = htmlToText(text);

    // `replaceRegex` 与净化用同一个上下文：`@js:` 替换要在沙箱里读到同一页（ADR-0071 §决策 5）。
    final JsPageContext jsContext = JsPageContext(
      baseUrl: request.url,
      source: source.jsSourceInfo,
      headers: headers,
      bookName: request.bookName,
      chapterTitle: request.title,
      book: _bookOf(request),
    );
    // 末尾的 `trim`：`replaceRegex` 删掉一整段之后会留下那一段的换行，阅读端虽然会丢掉空行，
    // 但缓存里的成品不该以空行结尾（正文的「首尾空白」是解析残留，不是内容）。
    final ChapterContent content = ChapterContent(
      body: (await _purifier.purgeContent(
        await _pages.replaceContent(
          rules.replaceRegex,
          text,
          'contentRule.replaceRegex',
          sourceId: source.url,
          jsContext: jsContext,
        ),
        context: jsContext,
      )).trim(),
      title: title.name,
      reviewImg: title.reviewImg,
      lyric: lyric,
    );
    // 缓存的是**成品**：分页已拼好、副文已并入、`replaceRegex` 与净化规则都已跑过，所以命中可直接
    // 跳过整个引擎。整个 ChapterContent 一起存，否则命中的那一章会丢掉正文页标题与歌词。
    // 写只发生在成功路径上：失败在前面就已经返回，不会被当成内容存下来。
    await _cache.write(
      sourceId: source.url,
      url: request.url,
      body: _encode(content),
      // 章节正文知道它属于哪本书（`bookUrl` 本来就在请求上下文里），按书缓存因此不需要新参数。
      bookUrl: request.bookUrl,
    );

    return ParseSuccess<ChapterContent>(content);
  }

  /// The text of a `subContent` value: the value itself, or the body of the page it points at.
  ///
  /// Upstream hands an `http…` value to `AnalyzeUrl(...).getStrResponseAwait().body`
  /// (`BookContent.kt:146-156`); a page that cannot be read yields an empty string, which is the
  /// same thing as an empty rule and never fails the chapter — the body is still readable.
  Future<String> _subContentText({
    required BookSource source,
    required ChapterRequest request,
    required String value,
    Map<String, String>? headers,
  }) async {
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return value;
    }
    final ParseResult<String> page = await _pages.plainBody(
      value,
      rulePath: 'contentRule.subContent',
      context: JsPageContext(
        baseUrl: request.url,
        source: source.jsSourceInfo,
        headers: headers,
        bookName: request.bookName,
        chapterTitle: request.title,
        book: _bookOf(request),
      ),
      headers: headers,
      sourceId: source.url,
    );
    if (page case ParseFailure<String>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      _pages.warn(
        'Sub-content page could not be read: source=${source.url} '
        'field=$rulePath kind=${kind.name}',
      );

      return '';
    }

    return page.dataOrNull ?? '';
  }

  // 上游 `AppPattern.imgRegex = (.*)((?:data|https?):[\s\S]+)$`：最后一个 media URL 是
  // reviewImg，它前面的文字才是标题（`BookContent.kt:169-183`）。本仓按「**最后一个** media URL」
  // 切分，再把标题里残留的标签去掉——上游会把 `<div id=…>` 或半个 `<img src="` 一起当下标，那显然
  // 不是章节名（`book-source.md` §4.1 登记了这处小差异）。
  static _ContentTitle _titleOf(String? value, {required String fallback}) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return const _ContentTitle();
    }
    final Iterable<RegExpMatch> urls = _mediaUrlPattern.allMatches(text);
    if (urls.isEmpty) {
      return _ContentTitle(name: text);
    }
    final RegExpMatch last = urls.last;
    final String before = text
        .substring(0, last.start)
        .replaceAll(_tagPattern, '')
        // 切分点可能落在标签中间（`… 开端<img src="`）：把半截标签也去掉。
        .replaceAll(_openTagPattern, '')
        .trim();
    final String reviewImg = last.group(0) ?? '';

    return _ContentTitle(
      name: before.isEmpty ? fallback : before,
      reviewImg: reviewImg.isEmpty ? null : reviewImg,
    );
  }

  // 只有正文的章节仍然按**纯文本**存：缓存对「正文」这个语义保持旧形状，升级不产生迁移，日志与
  // 调试页读到的也还是正文。带上正文页标题 / reviewImg / 歌词时才写成一行 JSON（带版本号）。
  static String _encode(ChapterContent content) {
    if (content.title == null &&
        content.reviewImg == null &&
        content.lyric == null) {
      return content.body;
    }

    return jsonEncode(<String, Object?>{
      _cacheVersionKey: _cacheVersion,
      'body': content.body,
      'title': content.title,
      'reviewImg': content.reviewImg,
      'lyric': content.lyric,
    });
  }

  static ChapterContent _decode(String cached) {
    if (!cached.startsWith('{')) {
      return ChapterContent(body: cached);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(cached);
    } on FormatException {
      return ChapterContent(body: cached);
    }
    if (decoded is! Map<String, Object?> ||
        decoded[_cacheVersionKey] != _cacheVersion) {
      // 读不懂就当正文：丢掉一个缓存条目的代价是重读一次，不是一章坏正文。
      return ChapterContent(body: cached);
    }

    return ChapterContent(
      body: decoded['body'] is String ? decoded['body']! as String : '',
      title: decoded['title'] is String ? decoded['title']! as String : null,
      reviewImg: decoded['reviewImg'] is String
          ? decoded['reviewImg']! as String
          : null,
      lyric: decoded['lyric'] is String ? decoded['lyric']! as String : null,
    );
  }
}

/// What a `contentRule.title` rule produced: a chapter name and, sometimes, a review image.
final class _ContentTitle {
  const _ContentTitle({this.name, this.reviewImg});

  /// The chapter name, or `null` when the rule matched nothing (keep the TOC's name).
  final String? name;

  /// The image URL the value carried, or `null`.
  final String? reviewImg;
}

// 值里的一个 media URL：止于空白、引号或标签边界。
final RegExp _mediaUrlPattern = RegExp('(?:data|https?):[^\\s"\'<>]+');

// 标题里残留的标签：`<div id="title">`、`<br>` 之类。
final RegExp _tagPattern = RegExp(r'<[^>]*>');

// 切分点之后半截的开标签（`<img src="`）。
final RegExp _openTagPattern = RegExp(r'<[^>]*$');

// 缓存条目的版本号：形状变了就换值，旧条目按纯正文读。
const String _cacheVersionKey = 'v';
const int _cacheVersion = 2;

/// The book bindings a purge script may read, taken from the request.
JsBookInfo _bookOf(ChapterRequest request) => JsBookInfo(
  name: request.bookName,
  author: request.author,
  bookUrl: request.bookUrl,
  tocUrl: request.tocUrl,
  intro: request.intro,
  kind: request.kind,
);
