import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/source_login.dart';
import 'package:flutter_reader/features/book_source/domain/source_regex.dart';
import 'package:flutter_reader/features/book_source/domain/url_rule.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:html/parser.dart' as parser;

// 翻页遍历的页数上限：到顶就停止并记录一条警告。
const int _maxPagingPages = 50;

// 翻页模板允许的 URL 变量。
const Set<String> _pagingTemplateVariables = <String>{'page', 'baseUrl'};

/// Matches one `{{name}}` placeholder of a paging URL template.
final RegExp _templatePlaceholder = RegExp(r'\{\{([^{}]*)\}\}');

// 整段是 URL、只用已知变量且不含 `@` 时才是模板，否则交给规则引擎。
bool _isPagingTemplate(String rule) {
  if (rule.contains('@')) {
    return false;
  }

  final Iterable<RegExpMatch> matches = _templatePlaceholder.allMatches(rule);

  return matches.isNotEmpty &&
      matches.every(
        (RegExpMatch match) =>
            _pagingTemplateVariables.contains((match.group(1) ?? '').trim()),
      );
}

/// One fetched page: its absolute URL and the parsed scope of its body.
///
/// The URL travels with the scope because a relative target on that page can only be
/// resolved against it.
final class FetchedPage {
  /// Creates a fetched page.
  const FetchedPage({required this.url, required this.scope});

  /// The absolute URL the page was fetched from.
  final String url;

  /// The page parsed into a scope its rules can read.
  final RuleScope scope;
}

/// The pages one paging walk reached, and why it stopped.
final class PageWalk {
  /// Creates a walk result.
  const PageWalk({required this.pages, this.stoppedBy});

  /// The pages that were read, in reading order: the requested one first.
  final List<FetchedPage> pages;

  /// The failure that ended the walk early, or `null` when it ended on its own.
  final ParseFailure<Never>? stoppedBy;
}

/// Fetches pages of a book source and reads rules from them.
///
/// Failures are always [ParseResult]s. Optional fields degrade to "no value" with a
/// warning, while a top-level list or content rule that matches nothing fails the stage.
final class PageFetchService {
  /// Creates the service.
  PageFetchService({
    required this._engine,
    required this._http,
    required this._logger,
    this._webPages,
  });

  final RuleEngine _engine;
  final HttpClient _http;
  final AppLogger _logger;
  final WebPageFetcher? _webPages;

  /// Fetches one **URL rule** and parses the body into a page scope
  /// (`book-source.md` §4.3).
  ///
  /// A URL field is not a plain address: real sources write
  /// `…/search.php,{"method":"POST","body":"searchkey={{key}}","charset":"gbk"}`, and
  /// sending that comma as part of the address is what made half of a published collection
  /// fail at the very first request. So this method owns the whole rule:
  ///
  /// * [parseUrlRule] splits the address from its `,{…}` suffix;
  /// * the address and the body are rendered through [RuleEngine.renderUrl], so `{{key}}` /
  ///   `{{page}}` and matrix #18's JavaScript work in both;
  /// * the keyword is **escaped only where the site expects an escape**: a form body and a
  ///   query string carry `%XX` (in the rule's declared `charset`), a JSON body carries it
  ///   verbatim — upstream draws the same line;
  /// * the suffix's `charset` also decodes the response (a declaration beats the sniff,
  ///   `book-source.md` §5);
  /// * suffix headers are merged **over** the source's own `header`, which is what upstream
  ///   does and what a site asking for a per-request `Referer` expects.
  ///
  /// Option fields this repository cannot honour (`webJs`, `retry`, …) are logged by name and
  /// ignored, so a source degrades instead of disappearing (ADR-0032's stance for unknown syntax).
  /// `webView` is **not** ignored: a GET or POST request is routed through the [WebPageFetcher]
  /// port and rendered, and only a platform without a WebView falls back to plain HTTP
  /// (ADR-0062 §决策 1). [headers] stays the **source-level** table; the caller keeps passing the
  /// same map it would pass to [fetch].
  ///
  /// [login] carries the source's login fields: a non-blank `loginCheckJs` runs as a response
  /// interceptor over the page this call produced (`book-source.md` §6, ADR-0068 addendum).
  ///
  /// [sourceRegex] is `ruleContent.sourceRegex`: the body is cut to its first match **before** the
  /// scope exists, so every rule on the page (and the login interceptor) sees the fragment
  /// (`source_regex.dart`, ADR-0068 §决策 7).
  Future<ParseResult<FetchedPage>> fetchRule(
    String rule, {
    required String rulePath,
    required Map<String, String> params,
    required JsPageContext context,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int page = 1,
    JsSourceInfo? source,
    SourceLoginGuard? login,
    String? sourceRegex,
  }) async {
    final ParseResult<UrlRule> parsed = parseUrlRule(rule, rulePath: rulePath);
    final UrlRule urlRule;
    switch (parsed) {
      case ParseFailure<UrlRule>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        return failureAt<FetchedPage>(kind: kind, rulePath: failedAt);
      case ParseSuccess<UrlRule>(:final UrlRule data):
        urlRule = data;
    }
    final UrlRuleOptions textOptions =
        urlRule.options ?? const UrlRuleOptions();

    final ParseResult<String> address = await _engine.renderUrl(
      urlRule.template,
      rulePath: rulePath,
      params: params,
      context: context,
      charset: textOptions.charset,
    );
    final String rendered;
    switch (address) {
      case ParseFailure<String>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        return failureAt<FetchedPage>(kind: kind, rulePath: failedAt);
      case ParseSuccess<String>(:final String data):
        rendered = data;
    }

    // 渲染后的地址可能自带 `,{…}`（`@js:` 规则返回「URL + 选项」是真实语料的常见写法）。
    // 必须在绝对化之前再切一次，否则 `{` 会被 `Uri.resolve` 编码成 `%7B`，选项就变成路径了。
    final UrlRule renderedRule = switch (parseUrlRule(
      rendered,
      rulePath: rulePath,
    )) {
      ParseSuccess<UrlRule>(:final UrlRule data) => data,
      ParseFailure<UrlRule>() => UrlRule(template: stripUrlOptions(rendered)),
    };
    final UrlRuleOptions options = renderedRule.options ?? textOptions;
    // `webView` 有真正的实现时不要再报「忽略」；只有平台没有 WebView 才回落。
    // POST/body 不再排除在外：表单型站点（ADR-0062 §决策 1）只有提交之后才有结果页。
    // `webView` 现在是 UrlRuleOptions 的**字段**（M21a，ADR-0068 §决策 6），不再是「被忽略的选项」。
    final bool canWebView =
        options.webView && (_webPages?.isSupported ?? false);
    for (final String ignored in options.unsupported) {
      _logger.warning(
        'Ignoring an unsupported URL option: rule=$rulePath '
        'option=$ignored source=${sourceId ?? 'unknown'}',
      );
    }
    final String url = resolveAbsoluteUrl(
      renderedRule.template.trim(),
      context.baseUrl,
    );

    final Map<String, String> requestHeaders = <String, String>{
      ...?headers,
      ...options.headers,
    };

    String? body;
    if (options.body != null) {
      final ParseResult<String> renderedBody = await _engine.renderUrl(
        options.body!,
        rulePath: rulePath,
        params: params,
        context: context,
        charset: options.charset,
        // JSON / XML 载荷里关键词必须原样出现（上游同样跳过表单编码）。
        encodeKeyword: !_isStructuredBody(options.body!),
      );
      switch (renderedBody) {
        case ParseFailure<String>(
          :final ParseFailureKind kind,
          rulePath: final String failedAt,
        ):
          return failureAt<FetchedPage>(kind: kind, rulePath: failedAt);
        case ParseSuccess<String>(:final String data):
          body = data;
      }
    }

    if (canWebView) {
      final bool post = options.method == UrlRequestMethod.post;
      if (post) {
        // 页面自己带的脚本会按这个头解析 body；规则没写就按载荷形状定（ADR-0062 §决策 1）。
        requestHeaders.putIfAbsent(
          'Content-Type',
          () => _contentTypeOf(body ?? ''),
        );
      }
      final ParseResult<FetchedWebPage> rendered = await _requireWebPages()
          .fetch(
            url: url,
            headers: requestHeaders,
            rulePath: rulePath,
            method: post ? WebPageRequestMethod.post : WebPageRequestMethod.get,
            body: post ? body : null,
            javaScript: options.webJs,
            delayTime: options.webViewDelayTime,
            overrideUrlRegex: options.overrideUrlRegex,
          );
      switch (rendered) {
        case ParseSuccess<FetchedWebPage>(:final FetchedWebPage data):
          return _pageOf(
            ParseSuccess<HttpResponse>(
              HttpResponse(
                statusCode: 200,
                headers: const <String, List<String>>{},
                body: data.body,
                url: data.url,
              ),
            ),
            url: data.url,
            headers: requestHeaders,
            page: page,
            source: source,
            bookName: context.bookName,
            chapterTitle: context.chapterTitle,
            book: context.book,
            rulePath: rulePath,
            login: login,
            sourceRegex: sourceRegex,
          );
        case ParseFailure<FetchedWebPage>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ):
          // WebView 失败时回落到普通 GET：有的站点只在部分页面需要 JS，能取到就用。
          _logger.warning(
            'WebView fetch failed, falling back to HTTP: rule=$rulePath '
            'kind=${kind.name} source=${sourceId ?? 'unknown'}',
          );
      }
    }

    final ParseResult<HttpResponse> response =
        options.method == UrlRequestMethod.post
        ? await _http.post(
            url,
            rulePath: rulePath,
            body: body,
            headers: requestHeaders,
            keyword: keyword,
            sourceId: sourceId,
            declaredCharset: options.charset,
            maxRetries: options.retry,
            receiveTimeout: options.readTimeout,
          )
        : await _http.get(
            url,
            rulePath: rulePath,
            headers: requestHeaders,
            keyword: keyword,
            sourceId: sourceId,
            declaredCharset: options.charset,
            maxRetries: options.retry,
            receiveTimeout: options.readTimeout,
          );

    // `bodyJs`（URL 选项）：对响应体跑脚本，返回值就是新的 body（ADR-0068 §决策 7）。它先于
    // `sourceRegex`，所以「用脚本拼出真实正文，再按正则截一刀」的两段式规则也对得上。
    final ParseResult<HttpResponse> shaped = await _applyBodyJs(
      response,
      options.bodyJs,
      context: JsPageContext(
        baseUrl: url,
        page: page,
        source: source,
        headers: requestHeaders,
        bookName: context.bookName,
        chapterTitle: context.chapterTitle,
        book: context.book,
      ),
    );

    return _pageOf(
      shaped,
      url: url,
      headers: requestHeaders,
      page: page,
      source: source,
      bookName: context.bookName,
      chapterTitle: context.chapterTitle,
      book: context.book,
      rulePath: rulePath,
      login: login,
      sourceRegex: sourceRegex,
    );
  }

  /// The WebView port, which is non-null whenever the `webView` branch was taken.
  WebPageFetcher _requireWebPages() => _webPages!;

  /// Fetches [url] in a WebView and answers its body, for `ruleContent.webJs`
  /// (ADR-0068 §决策 7).
  ///
  /// The script runs **inside** the page, so a site whose body is assembled by its own JavaScript
  /// is read the way a browser reads it. Without a platform WebView the call fails as
  /// `unsupportedRule`; the caller reports it instead of parsing an unrendered page.
  Future<ParseResult<String>> fetchRendered(
    String url, {
    required String rulePath,
    required String script,
    Map<String, String>? headers,
    String? sourceId,
    JsSourceInfo? source,
    String? bookName,
    String? chapterTitle,
  }) async {
    final WebPageFetcher? pages = _webPages;
    if (pages == null || !pages.isSupported) {
      return const ParseFailure<String>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'contentRule.webJs',
      );
    }
    final ParseResult<FetchedWebPage> page = await pages.fetch(
      url: url,
      headers: headers,
      rulePath: rulePath,
      javaScript: script,
    );

    return switch (page) {
      ParseSuccess<FetchedWebPage>(:final FetchedWebPage data) =>
        ParseSuccess<String>(data.body),
      ParseFailure<FetchedWebPage>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        ParseFailure<String>(kind: kind, rulePath: rulePath),
    };
  }

  /// Whether [body] is a JSON / XML payload rather than a form (`AnalyzeUrl.analyzeFields`).
  bool _isStructuredBody(String body) {
    final String trimmed = body.trimLeft();

    return trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        trimmed.startsWith('<');
  }

  /// The `Content-Type` a WebView POST declares when the rule declares none.
  ///
  /// Upstream sends the same three shapes through a WebView, and a page whose script reads
  /// `request.getParameter` needs the form type to be present: a body sent as
  /// `text/plain` reaches the site but parses to nothing (ADR-0062 §决策 1).
  String _contentTypeOf(String body) {
    final String trimmed = body.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return 'application/json';
    }
    if (trimmed.startsWith('<')) {
      return 'application/xml';
    }

    return 'application/x-www-form-urlencoded';
  }

  /// Fetches [url] and parses the body into a page scope.
  ///
  /// The scope carries both the parsed DOM and the raw body, because the **rule**
  /// decides which of the two it reads (matrix #12 / #13), and one fetched page is
  /// read by a whole field set whose rules need not agree: a `bookList` of `$.data…`
  /// and a `content` of `class.content@text` may come from the same response.
  ///
  /// [rulePath] names the book source field the request belongs to, so a failure
  /// stays locatable (C-SRC-8); [keyword] is passed through so the HTTP client can
  /// keep a search keyword out of its failure logs (ADR-0006 §5).
  ///
  /// [headers] are the book source's own `header` field (`book-source.md` §2, an M0
  /// field). They are request overrides for the policy defaults — a source that needs
  /// a browser `User-Agent`, or a `Referer` without which its pages 404, declares it
  /// there (C-NET-4). Cookies are still added by the `CookieManager` and a source must
  /// never spell them out (C-NET-5).
  ///
  /// [sourceId] is the book source URL. It travels only for the logs the HTTP layer
  /// owns — the tolerant-decode warning of ADR-0031 §决策 2 names the source, which is
  /// what C-ERR-8 asks for (C-SEC-4 still forbids the body).
  ///
  /// [page] and [source] fill the `page` / `source` bindings a `@js:` rule sees
  /// (`book-source.md` §6); they default to the first page and an empty source so a caller
  /// that has no book source context still gets a valid context. [login] carries the source's
  /// login fields, which run over this page exactly as they do in [fetchRule].
  Future<ParseResult<RuleScope>> fetch(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int page = 1,
    JsSourceInfo? source,
    String? bookName,
    String? chapterTitle,
    JsBookInfo? book,
    SourceLoginGuard? login,
    String? sourceRegex,
  }) async {
    final ParseResult<HttpResponse> response = await _http.get(
      url,
      rulePath: rulePath,
      headers: headers,
      keyword: keyword,
      sourceId: sourceId,
    );

    final ParseResult<FetchedPage> fetched = await _pageOf(
      response,
      url: url,
      headers: headers,
      page: page,
      source: source,
      bookName: bookName,
      chapterTitle: chapterTitle,
      book: book,
      rulePath: rulePath,
      login: login,
      sourceRegex: sourceRegex,
    );

    return switch (fetched) {
      ParseFailure<FetchedPage>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<RuleScope>(kind: kind, rulePath: failedAt),
      ParseSuccess<FetchedPage>(:final FetchedPage data) => ParseSuccess(
        data.scope,
      ),
    };
  }

  /// Turns a response into a fetched page (its URL + scope) and runs the source's
  /// `loginCheckJs` interceptor over it, or carries the failure.
  Future<ParseResult<FetchedPage>> _pageOf(
    ParseResult<HttpResponse> response, {
    required String url,
    required Map<String, String>? headers,
    required int page,
    required JsSourceInfo? source,
    required String rulePath,
    String? bookName,
    String? chapterTitle,
    JsBookInfo? book,
    SourceLoginGuard? login,
    String? sourceRegex,
  }) async {
    switch (response) {
      case ParseFailure<HttpResponse>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        return failureAt<FetchedPage>(kind: kind, rulePath: failedAt);
      case ParseSuccess<HttpResponse>(:final HttpResponse data):
        // 页面地址是它**最终**被读到的地址：上游 `StrResponse` 里也是 OkHttp 跟随重定向之后
        // 的请求地址，相对链接、`baseUrl` 与 `loginCheckJs` 的 `url()` 都以它为准
        // （`http_response.dart`）。没重定向时它就是请求地址。
        final String pageUrl = data.url.isEmpty ? url : data.url;
        final ParseResult<String> cut = _cutBody(data, sourceRegex);
        final String body;
        switch (cut) {
          case ParseFailure<String>(
            :final ParseFailureKind kind,
            rulePath: final String failedAt,
          ):
            return failureAt<FetchedPage>(kind: kind, rulePath: failedAt);
          case ParseSuccess<String>(:final String data):
            body = data;
        }
        final JsPageContext context = JsPageContext(
          baseUrl: pageUrl,
          page: page,
          source: source,
          headers: headers,
          // §6 的 `java.get('bookName' / 'title')`：书与章节是**页面**的属性，所以它必须
          // 建在页面 scope 上，再由引擎继承到每个条目与每条规则（ADR-0049）。
          bookName: bookName,
          chapterTitle: chapterTitle,
          book: book,
        );
        final FetchedPage pageScope = FetchedPage(
          url: pageUrl,
          scope: RuleScope.dom(
            parser.parse(body),
            body: body,
            jsContext: context,
          ),
        );

        return _interceptLogin(
          pageScope,
          HttpResponse(
            statusCode: data.statusCode,
            headers: data.headers,
            body: body,
            url: data.url,
          ),
          context: context,
          body: body,
          rulePath: rulePath,
          login: login,
        );
    }
  }

  /// Runs the source's `loginCheckJs` over one fetched page (ADR-0068 addendum).
  ///
  /// Upstream hands this script the **response**, not the page text (`AnalyzeUrl.evalJS(... result =
  /// StrResponse)`), and replaces the response with whatever the script returns. So:
  ///
  /// * `null` / `undefined` → the page stays as it is (the common `if (…) ` without an `else`);
  /// * a response-shaped object → its body (and URL) become the page the rules read;
  /// * a bare string → replaces the body (tolerance, `readLoginCheckResult`);
  /// * anything else, when the source declares `loginUrl` / `loginUi`, is
  ///   [ParseFailureKind.loginRequired]: the script could not fix the session, and the one
  ///   actionable answer the UI can offer is 「去登录」. Without those fields it stays a
  ///   [ParseFailureKind.parseFailed], because there is nothing to sign in with.
  ///
  /// A failing **job** (script error, timeout, or a verification the user cancelled) is carried
  /// through unchanged: the interceptor is the source's own answer to a blocked page, and
  /// swallowing it would parse a body nobody vouched for.
  Future<ParseResult<FetchedPage>> _interceptLogin(
    FetchedPage page,
    HttpResponse response, {
    required JsPageContext context,
    required String body,
    required String rulePath,
    required SourceLoginGuard? login,
  }) async {
    final String? script = login?.checkScript;
    if (script == null || script.trim().isEmpty) {
      return ParseSuccess<FetchedPage>(page);
    }

    final ParseResult<Object?> evaluated = await _engine.evaluateJs(
      script,
      rulePath: 'loginCheckJs',
      context: context,
      response: JsResponseView(
        url: page.url,
        body: response.body,
        code: response.statusCode,
        headers: _flatHeaders(response.headers),
      ),
    );
    switch (evaluated) {
      case ParseFailure<Object?>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        return failureAt<FetchedPage>(kind: kind, rulePath: failedAt);
      case ParseSuccess<Object?>(:final Object? data):
        final ParseResult<LoginReplacement?> replacement = readLoginCheckResult(
          data,
        );
        switch (replacement) {
          case ParseSuccess<LoginReplacement?>(:final LoginReplacement? data):
            return _replaced(page, data, context: context, currentBody: body);
          case ParseFailure<LoginReplacement?>():
            final bool canSignIn = login?.canSignIn ?? false;
            _logger.warning(
              'loginCheckJs did not return a response: field=$rulePath '
              'canSignIn=$canSignIn',
            );

            return failureAt<FetchedPage>(
              kind: canSignIn
                  ? ParseFailureKind.loginRequired
                  : ParseFailureKind.parseFailed,
              rulePath: 'loginCheckJs',
            );
        }
    }
  }

  /// The page a `loginCheckJs` replacement describes, or [page] itself when nothing changed.
  ParseResult<FetchedPage> _replaced(
    FetchedPage page,
    LoginReplacement? replacement, {
    required JsPageContext context,
    required String currentBody,
  }) {
    if (replacement == null) {
      return ParseSuccess<FetchedPage>(page);
    }
    final String url = replacement.url ?? page.url;
    final String body = replacement.body;
    if (url == page.url && body == currentBody) {
      // 脚本做了判断但没改响应（`return result` 是最常见的写法）：不重建 DOM。
      return ParseSuccess<FetchedPage>(page);
    }

    return ParseSuccess<FetchedPage>(
      FetchedPage(
        url: url,
        scope: RuleScope.dom(
          parser.parse(body),
          body: body,
          jsContext: JsPageContext(
            baseUrl: url,
            page: context.page,
            source: context.source,
            headers: context.headers,
            bookName: context.bookName,
            chapterTitle: context.chapterTitle,
            book: context.book,
          ),
        ),
      ),
    );
  }

  /// The body the page scope is built from: `sourceRegex`'s first match, or the response body.
  ///
  /// The cut runs **before** the scope exists, so the DOM, the `@json:`/`$` rules and the login
  /// interceptor all read the same fragment (`source_regex.dart`).
  ParseResult<String> _cutBody(HttpResponse data, String? sourceRegex) {
    final String? pattern = sourceRegex;
    if (pattern == null || pattern.trim().isEmpty) {
      return ParseSuccess<String>(data.body);
    }

    return cutBySourceRegex(
      pattern,
      data.body,
      rulePath: 'contentRule.sourceRegex',
    );
  }

  /// Replaces the response body with what a `bodyJs` URL option computed (`book-source.md` §4.3).
  ///
  /// The script sees the body as `result` (a plain string, like any `@js:` rule that follows a
  /// page) and must answer a string; anything else is [ParseFailureKind.parseFailed], because a
  /// body nobody produced cannot be parsed. A blank option, or a response that already failed,
  /// passes through untouched.
  Future<ParseResult<HttpResponse>> _applyBodyJs(
    ParseResult<HttpResponse> response,
    String? script, {
    required JsPageContext context,
  }) async {
    if (script == null || script.trim().isEmpty) {
      return response;
    }
    switch (response) {
      case ParseFailure<HttpResponse>():
        return response;
      case ParseSuccess<HttpResponse>(:final HttpResponse data):
        final ParseResult<Object?> evaluated = await _engine.evaluateJs(
          script,
          rulePath: 'bodyJs',
          context: context,
          result: data.body,
        );
        switch (evaluated) {
          case ParseFailure<Object?>(
            :final ParseFailureKind kind,
            rulePath: final String failedAt,
          ):
            return failureAt<HttpResponse>(kind: kind, rulePath: failedAt);
          case ParseSuccess<Object?>(data: final Object? value):
            if (value is! String) {
              return failureAt<HttpResponse>(
                kind: ParseFailureKind.parseFailed,
                rulePath: 'bodyJs',
              );
            }

            return ParseSuccess<HttpResponse>(
              HttpResponse(
                statusCode: data.statusCode,
                headers: data.headers,
                body: value,
                url: data.url,
              ),
            );
        }
    }
  }

  /// Flattens response headers for the sandbox's `result.headers()` view.
  static Map<String, String> _flatHeaders(Map<String, List<String>> headers) =>
      <String, String>{
        for (final MapEntry<String, List<String>> entry in headers.entries)
          entry.key: entry.value.join(', '),
      };

  /// The request headers [source] declares, evaluating a **rule** header first
  /// (`book-source.md` §2, M12-A2).
  ///
  /// Upstream evaluates `header` when it starts with `@js:` / `<js>` and parses the script's
  /// result as a JSON object (`BaseSource.getHeaderMap`); a source that signs its requests
  /// (`Referer`, a timestamped token) is unusable without it. The evaluation runs **before**
  /// the request, which is exactly why it cannot be a rule engine field like the others: it
  /// has no page to read.
  ///
  /// A broken header rule is **not** fatal: it is logged and the request goes out with the
  /// static headers (usually none). The alternative — failing the stage — would turn "this
  /// source's signature script broke" into "this source has no books", and the request will
  /// fail loudly on its own if the header really was required (ADR-0026 §决策 2).
  Future<Map<String, String>?> headersOf(BookSource source) async {
    final String? rule = source.headerRule;
    if (rule == null) {
      return source.headers;
    }

    final ParseResult<Object?> evaluated = await _engine.evaluateJs(
      _headerScript(rule),
      rulePath: 'header',
      context: JsPageContext(
        baseUrl: source.url,
        source: source.jsSourceInfo,
        headers: source.headers,
      ),
    );
    switch (evaluated) {
      case ParseFailure<Object?>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        _logger.warning(
          'Header rule failed, sending the static headers: source=${source.url} '
          'kind=${kind.name} rule=$failedAt',
        );

        return source.headers;
      case ParseSuccess<Object?>(:final Object? data):
        final Map<String, String>? headers = _headersOfScriptResult(data);
        if (headers == null) {
          _logger.warning(
            'Header rule did not produce a JSON object, sending the static headers: '
            'source=${source.url}',
          );

          return source.headers;
        }

        return <String, String>{...?source.headers, ...headers};
    }
  }

  /// The bare script inside a `header` rule.
  String _headerScript(String rule) {
    final String trimmed = rule.trim();
    if (trimmed.toLowerCase().startsWith('<js>')) {
      final int end = trimmed.toLowerCase().lastIndexOf('</js>');

      return end < 0 ? trimmed.substring(4) : trimmed.substring(4, end);
    }

    return trimmed.toLowerCase().startsWith('@js:')
        ? trimmed.substring(4)
        : trimmed;
  }

  /// The header map a header script produced: a JSON object, or its text.
  Map<String, String>? _headersOfScriptResult(Object? data) {
    final Object? decoded = switch (data) {
      final String text => _tryDecodeHeaderJson(text),
      final Map<Object?, Object?> map => map,
      _ => null,
    };
    if (decoded is! Map<Object?, Object?>) {
      return null;
    }

    return <String, String>{
      for (final MapEntry<Object?, Object?> entry in decoded.entries)
        if (entry.key is String && entry.value is String)
          entry.key! as String: entry.value! as String,
    };
  }

  /// Decodes a header rule's JSON text, accepting the single-quoted dialect GSON accepts.
  Object? _tryDecodeHeaderJson(String text) {
    final String trimmed = text.trim();
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      if (trimmed.contains('"')) {
        return null;
      }
      try {
        return jsonDecode(trimmed.replaceAll("'", '"'));
      } on FormatException {
        return null;
      }
    }
  }

  /// Applies [source]'s own `concurrentRate` to the request budget (`book-source.md` §8).
  ///
  /// The use cases call this when an operation starts, because they are the layer that holds
  /// the model: the request layer knows only the source id it is given, and the rate gate has to
  /// be keyed by it so a `@js:` rule's `http.*` calls (which see only that id, §6) pass the same
  /// gate (ADR-0036 §决策 5).
  void applySourceRate(BookSource source) =>
      _http.applySourceRate(source.url, source.concurrentRate);

  /// Returns the first value of [rule] in [scope], or the failure that stopped it.
  ///
  /// A `null` value means the rule matched nothing, which is a **success** here: the
  /// caller decides whether that field is required, because only the caller knows
  /// whether the rule is top-level (`book-source.md` §7).
  ///
  /// A non-top-level field whose rule was **rejected** or is **malformed** degrades to
  /// `null` plus a warning carrying `rulePath` and the book source id (ADR-0026
  /// §决策 2/4): one bad optional field must not cost the whole stage, and for the
  /// caller “unsupported syntax” and “broken rule” have the same consequence — losing
  /// that one field. Escalating a malformed rule instead would be worse than useless:
  /// the callers read `dataOrNull`, so it would turn into a silent `null` with no
  /// record at all. C-SRC-4 is satisfied by the explicit degradation plus its warning.
  ///
  /// Asynchronous because the engine is: the rule may hold a `@js:` segment
  /// (ADR-0029 §决策 1). Every caller awaits it in turn, so the use cases stay
  /// `Future`-returning without a second evaluation path.
  Future<ParseResult<String?>> field(
    String? rule,
    RuleScope scope,
    String rulePath, {
    required String sourceId,
  }) async {
    final ParseResult<String?> parsed = await _engine.extractFirst(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (parsed) {
      ParseFailure<String?>(:final ParseFailureKind kind)
          when kind == ParseFailureKind.unsupportedRule ||
              kind == ParseFailureKind.parseFailed =>
        _degrade(sourceId, rulePath, kind),
      _ => parsed,
    };
  }

  /// Logs a degraded optional field and turns it into “no value” (ADR-0026).
  ///
  /// The message carries the field, the failure kind and the source, never a page body
  /// or a keyword (C-ERR-8, C-SEC-4).
  ParseResult<String?> _degrade(
    String sourceId,
    String rulePath,
    ParseFailureKind kind,
  ) {
    _warnDegraded(sourceId, rulePath, kind, 'empty');

    return const ParseSuccess<String?>(null);
  }

  /// Logs an optional rule whose failure was degraded to its empty consequence.
  ///
  /// [consequence] spells out what “empty” means for the field that degraded — no
  /// value, no next page, no replacement — so the log keeps one shape per outcome
  /// while each call site keeps its own fallback. It must never name a page body or a
  /// keyword (C-ERR-8, C-SEC-4).
  void _warnDegraded(
    String sourceId,
    String rulePath,
    ParseFailureKind kind,
    String consequence,
  ) {
    _logger.warning(
      'Field rule degraded to $consequence: source=$sourceId field=$rulePath '
      'kind=${kind.name}',
    );
  }

  /// Returns every match of a **top-level list** rule.
  ///
  /// Matching nothing is [ParseFailureKind.parseFailed] (`book-source.md` §7).
  Future<ParseResult<List<RuleScope>>> list(
    String? rule,
    RuleScope scope,
    String rulePath,
  ) async {
    final ParseResult<List<RuleScope>> result = await _engine.selectAll(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (result) {
      ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) =>
        data.isEmpty ? _noMatch(rulePath) : ParseSuccess<List<RuleScope>>(data),
      ParseFailure<List<RuleScope>>() => result,
    };
  }

  /// Returns the scope [rule] selects on [scope] — the `ruleBookInfo.init` entry
  /// (`book-source.md` §2).
  ///
  /// Upstream evaluates `init` and makes its **result** the content every later
  /// `ruleBookInfo` field is read from (`BookInfo.kt:58-64`), so this returns a scope and not a
  /// value: a JSON rule yields a [JsonScope] (the later fields then read that sub-structure,
  /// which is the shape the real corpus uses — `init: "$.data.bookInfo"`), a DOM rule yields
  /// the [DomScope] of a matched element.
  ///
  /// Unlike [field] it **never degrades**: `init` decides where every later field is read, so a
  /// rule that was rejected, is malformed or matched nothing is the stage's failure (upstream fails
  /// the same way when nothing matched, because `setContent(null)` throws). Matching several things
  /// keeps the first, the element semantics of `RuleEngine.selectAll` (`book-source.md` §2).
  Future<ParseResult<RuleScope>> selectScope(
    String? rule,
    RuleScope scope,
    String rulePath,
  ) async {
    final ParseResult<List<RuleScope>> result = await _engine.selectAll(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (result) {
      ParseFailure<List<RuleScope>>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<RuleScope>(kind: kind, rulePath: failedAt),
      ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) =>
        data.isEmpty ? _noMatch(rulePath) : ParseSuccess<RuleScope>(data.first),
    };
  }

  /// Returns the single value of the **top-level content** rule.
  ///
  /// Matching nothing is [ParseFailureKind.parseFailed] (`book-source.md` §7).
  ///
  /// A rejected `content` rule stays a failure: it is top-level, so ADR-0026 §决策 1
  /// applies and the degradation of [field] deliberately does not. The engine is
  /// therefore called directly here.
  ///
  /// Asynchronous for the same reason as [field]: the engine's value API is.
  Future<ParseResult<String>> content(
    String? rule,
    RuleScope scope,
    String rulePath,
  ) async {
    final ParseResult<String?> parsed = await _engine.extractFirst(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (parsed) {
      ParseFailure<String?>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<String>(kind: kind, rulePath: failedAt),
      ParseSuccess<String?>(:final String? data) =>
        data == null || data.isEmpty ? _noMatch(rulePath) : ParseSuccess(data),
    };
  }

  /// Runs a **pre-fetch script** of a stage (`ruleToc.preUpdateJs`, ADR-0078 S2).
  ///
  /// The script runs on the page context only — there is no page yet, which is the point: upstream
  /// uses it to warm a cookie or a token before the request. A failure is the **caller's** failure
  /// (upstream aborts the TOC update), so it comes back as a [ParseFailure] here.
  Future<ParseResult<Object?>> script(
    String script, {
    required String rulePath,
    required JsPageContext context,
  }) => _engine.evaluateJs(script, rulePath: rulePath, context: context);

  /// Runs a `ruleToc.formatJs` rule over [chapters] (ADR-0078 S2).
  ///
  /// One JS job for the whole list; see `RuleEngine.formatTitles` for why.
  Future<ParseResult<List<String?>>> formatTitles({
    required String script,
    required List<Chapter> chapters,
    required JsPageContext context,
    required String rulePath,
  }) => _engine.formatTitles(
    script: script,
    chapters: <JsChapterInfo>[
      for (final Chapter chapter in chapters)
        JsChapterInfo(
          title: chapter.name,
          url: chapter.url,
          isVip: chapter.isVip,
          isPay: chapter.isPay,
          isVolume: chapter.isVolume,
          updateTime: chapter.updateTime,
        ),
    ],
    context: context,
    rulePath: rulePath,
  );

  /// Returns the **whole content** [rule] matches as one newline-joined string (upstream
  /// `getString`).
  ///
  /// `ruleContent.content` is read this way for **every** book type upstream, so an image source
  /// whose rule is `$.data[*].image` plus a `@js:` tail gets one joined string as `result`
  /// (ADR-0069 G9). A rejected rule stays a failure; matching nothing answers an empty string and
  /// the caller decides whether that is a failure.
  Future<ParseResult<String>> joined(
    String rule,
    RuleScope scope,
    String rulePath,
  ) => _engine.extractJoined(rule, scope, rulePath: rulePath);

  /// Returns every value a **top-level list** rule produces on [scope].
  ///
  /// Matching nothing is [ParseFailureKind.parseFailed] (`book-source.md` §7), the same
  /// rule [content] follows: a top-level rule that no longer fits its page is the stage's
  /// failure, not an empty result. Used by the image and audio stages, where one matched
  /// value is one page / one track (ADR-0053 §决策 2, ADR-0054 §决策 2).
  ///
  /// A rejected rule stays [ParseFailureKind.unsupportedRule] (C-SRC-4); unlike [field]
  /// it is not degraded, because the whole stage depends on this list.
  Future<ParseResult<List<String>>> valueList(
    String? rule,
    RuleScope scope,
    String rulePath,
  ) async {
    final ParseResult<List<String>> parsed = await _engine.extractAll(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (parsed) {
      ParseSuccess<List<String>>(:final List<String> data)
          when data.isNotEmpty =>
        ParseSuccess<List<String>>(data),
      ParseSuccess<List<String>>() => _noMatch<List<String>>(rulePath),
      ParseFailure<List<String>>() => parsed,
    };
  }

  /// Fetches the page [rule] names and walks every page [nextRule] names
  /// (`book-source.md` §4.1).
  ///
  /// [rule] is the stage's **URL rule**, not a URL: `tocUrl` / the chapter address can carry
  /// the `,{…}` suffix of §4.3 too, so the first page goes through [fetchRule].
  ///
  /// A **first** page that cannot be fetched is the stage's failure, exactly as before;
  /// a **later** one stops the walk and is reported through [PageWalk.stoppedBy], so
  /// each stage can decide what a partial walk means.
  ///
  /// The walk is a queue, not a fixed chain: a paging rule may name one page or several
  /// (`nextTocUrl` is a list upstream), so every fetched page contributes its own next
  /// URLs. Four bounds keep it finite without trusting the site — a page is never read
  /// twice, a paging rule cannot name the page it was read on ([nextPageUrls]), the
  /// walk stops at the §9 page bound and logs a warning, and the paging rule itself
  /// degrades to “no next page” when it is rejected.
  ///
  /// [rulePath] is the stage's field (`ruleToc`, `ruleContent`) and travels into every
  /// request, so a failure stays locatable (C-SRC-8); [nextRulePath] is the paging
  /// field (`tocRule.nextTocUrl`, `contentRule.nextContentUrl`). [context], [headers],
  /// [sourceId] and [source] are the book source's own request overrides, id and sandbox view
  /// (C-NET-4, C-ERR-8, §6), passed the same way [fetch] takes them.
  Future<ParseResult<PageWalk>> walk({
    required String rule,
    required String rulePath,
    required String? nextRule,
    required String nextRulePath,
    required JsPageContext context,
    Map<String, String>? headers,
    required String sourceId,
    JsSourceInfo? source,
    SourceLoginGuard? login,
    String? sourceRegex,
  }) async {
    final List<FetchedPage> pages = <FetchedPage>[];
    final Set<String> visited = <String>{};
    // 第一页是一条 **URL 规则**（可能带 `,{…}` 后缀，`book-source.md` §4.3），后面的页是
    // 翻页规则渲染出的绝对 URL。
    final ParseResult<FetchedPage> first = await fetchRule(
      rule,
      rulePath: rulePath,
      params: const <String, String>{},
      context: context,
      headers: headers,
      sourceId: sourceId,
      source: source,
      login: login,
      sourceRegex: sourceRegex,
    );
    switch (first) {
      case ParseFailure<FetchedPage>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        return failureAt<PageWalk>(kind: kind, rulePath: failedAt);
      case ParseSuccess<FetchedPage>(:final FetchedPage data):
        visited.add(data.url);
        pages.add(data);
    }

    final List<String> pending = <String>[
      ...await nextPageUrls(
        nextRule,
        pages.first.scope,
        nextRulePath,
        currentUrl: pages.first.url,
        page: 2,
        sourceId: sourceId,
      ),
    ];

    while (pending.isNotEmpty) {
      if (pages.length >= _maxPagingPages) {
        _logger.warning(
          'Paging stopped at $_maxPagingPages pages: source=$sourceId '
          'field=$rulePath',
        );
        break;
      }

      final String pageUrl = pending.removeAt(0);
      if (!visited.add(pageUrl)) {
        // 翻页规则指回了已经读过的页（本站的页码列表常同时列出上一页）：跳过而不是重读。
        continue;
      }

      final ParseResult<RuleScope> page = await fetch(
        pageUrl,
        rulePath: rulePath,
        headers: headers,
        sourceId: sourceId,
        // 正在取的这一页就是 `pages.length + 1`（1-based），与翻页规则里的 `{{page}}` 同口径。
        page: pages.length + 1,
        source: source,
        bookName: context.bookName,
        chapterTitle: context.chapterTitle,
        book: context.book,
        login: login,
        sourceRegex: sourceRegex,
      );

      switch (page) {
        case ParseFailure<RuleScope>(
          :final ParseFailureKind kind,
          rulePath: final String failedAt,
        ):
          return ParseSuccess<PageWalk>(
            PageWalk(
              pages: pages,
              stoppedBy: failureAt<Never>(kind: kind, rulePath: failedAt),
            ),
          );
        case ParseSuccess<RuleScope>(:final RuleScope data):
          pages.add(FetchedPage(url: pageUrl, scope: data));
          pending.addAll(
            await nextPageUrls(
              nextRule,
              data,
              nextRulePath,
              currentUrl: pageUrl,
              // 刚读到的这一页是 `pages.length`（1-based），它指向的下一页就是下一号。
              page: pages.length + 1,
              sourceId: sourceId,
            ),
          );
      }
    }

    return ParseSuccess<PageWalk>(PageWalk(pages: pages));
  }

  /// Returns the absolute URLs a **paging** rule points at (`book-source.md` §4.1).
  ///
  /// [rule] is read as a **list** because `nextTocUrl` / `nextContentUrl` may name one
  /// page or a whole array of them (upstream `getStringList`,
  /// `BookChapterList.kt:210-218`); taking only the first value would silently drop
  /// pages. Every value is resolved against the page it was read on (C-SRC-5), and the
  /// current page plus any repeat are dropped — upstream filters `redirectUrl`
  /// (`BookChapterList.kt:212`) and stops its chapter loop on a URL it already has.
  ///
  /// The field is also a place where `book-source.md` §4 allows the URL variables
  /// `{{page}}` and `{{baseUrl}}` ([page] is the 1-based number the value becomes,
  /// `{{baseUrl}}` is [currentUrl]), so every value is rendered before it is requested,
  /// and a rule that **is** a template is rendered as a whole — the engine has no node
  /// to extract from it. Section 4 forbids letting a literal `{{...}}` reach the
  /// request, so a value that renders to nothing is dropped.
  ///
  /// A rejected or malformed rule degrades to **no next page** plus a warning
  /// (ADR-0026 §决策 2): the field is not top-level, so it must not cost the stage —
  /// paging simply stops where it is. Asynchronous because the rule may hold a `@js:`
  /// segment (ADR-0029 §决策 1).
  Future<List<String>> nextPageUrls(
    String? rule,
    RuleScope scope,
    String rulePath, {
    required String currentUrl,
    required int page,
    required String sourceId,
  }) async {
    if (rule == null || rule.trim().isEmpty) {
      return const <String>[];
    }

    final String text = rule.trim();
    final JsPageContext context = _pagingContext(
      scope,
      currentUrl: currentUrl,
      page: page,
    );
    if (_isPagingTemplate(text)) {
      return _pagingUrls(
        <String>[text],
        currentUrl,
        page,
        rulePath: rulePath,
        context: context,
        sourceId: sourceId,
      );
    }

    final ParseResult<List<String>> parsed = await _engine.extractAll(
      text,
      scope,
      rulePath: rulePath,
    );

    return switch (parsed) {
      ParseSuccess<List<String>>(:final List<String> data) => _pagingUrls(
        data,
        currentUrl,
        page,
        rulePath: rulePath,
        context: context,
        sourceId: sourceId,
      ),
      // 降级 warning 用**字段路径**而不是引擎报的 `unsupported:<语法>`：与 [field] 同
      // 一口径，书源里要改的是哪个字段（C-SRC-8、ADR-0026 §决策 2）。
      ParseFailure<List<String>>(:final ParseFailureKind kind) => _noNextPage(
        sourceId,
        rulePath,
        kind,
      ),
    };
  }

  /// Renders, resolves, filters and de-duplicates paging values, keeping rule order.
  ///
  /// [page] is the 1-based number the value becomes and `{{baseUrl}}` is [currentUrl],
  /// which is what §4.1 fixes for these two fields under queue paging. Rendering goes
  /// through [renderUrl], so a paging value may also carry matrix #18's `{{…}}` JavaScript;
  /// when that fails the field degrades to “no next page” plus a warning (ADR-0026 §决策 2),
  /// exactly like a rejected paging rule.
  Future<List<String>> _pagingUrls(
    List<String> values,
    String currentUrl,
    int page, {
    required String rulePath,
    required JsPageContext context,
    required String sourceId,
  }) async {
    final List<String> urls = <String>[];
    final Map<String, String> params = <String, String>{
      'page': '$page',
      'baseUrl': currentUrl,
    };

    for (final String value in values) {
      if (value.trim().isEmpty) {
        continue;
      }

      final ParseResult<String> rendered = await renderUrl(
        value,
        params,
        rulePath: rulePath,
        context: context,
      );
      if (rendered case ParseFailure<String>(:final ParseFailureKind kind)) {
        // 降级 warning 用**字段路径**而不是引擎报的 `unsupported:<语法>`：与 [field] 同
        // 一口径，书源里要改的是哪个字段（C-SRC-8、ADR-0026 §决策 2）。
        return _noNextPage(sourceId, rulePath, kind);
      }
      final String url0 = (rendered as ParseSuccess<String>).data.trim();
      if (url0.isEmpty) {
        continue;
      }

      // 翻页值也可能带 `,{…}`：与章节地址同一口径（先切选项再绝对化）。
      final String url = resolveUrlRule(url0, currentUrl);
      if (url == currentUrl || urls.contains(url)) {
        continue;
      }

      urls.add(url);
    }

    return urls;
  }

  /// Builds the page context a **paging** rule's `{{…}}` JavaScript runs against.
  ///
  /// `{{baseUrl}}` / the `baseUrl` binding is the page the rule was read on and `page` is
  /// the number the value becomes (§4.1); the source and its headers travel from the page's
  /// own context, so `http.*` of a paging script keeps using them (C-NET-4).
  JsPageContext _pagingContext(
    RuleScope scope, {
    required String currentUrl,
    required int page,
  }) {
    final JsPageContext? context = switch (scope) {
      DomScope(:final JsPageContext? jsContext) => jsContext,
      JsonScope(:final JsPageContext? jsContext) => jsContext,
    };

    return JsPageContext(
      baseUrl: currentUrl,
      page: page,
      source: context?.source,
      headers: context?.headers,
      // §6 的 `java.get('bookName' / 'title')`：翻页规则与它读到的那一页同属一本书。
      bookName: context?.bookName,
      chapterTitle: context?.chapterTitle,
      book: context?.book,
    );
  }

  /// Logs a degraded paging rule and turns it into “no next page” (ADR-0026).
  List<String> _noNextPage(
    String sourceId,
    String rulePath,
    ParseFailureKind kind,
  ) {
    _warnDegraded(sourceId, rulePath, kind, 'no next page');

    return const <String>[];
  }

  /// Applies the `ruleContent.replaceRegex` purification to [content].
  ///
  /// The rule is a **standalone** `##regex##replacement` rule run on the joined
  /// chapter text (matrix #9, `book-source.md` §4.1), so it goes through
  /// [RuleEngine.applyReplaceRule] rather than [field]: there is no page left to read.
  /// Upstream's surrounding per-line trim and re-indent (`BookContent.kt:191-194`) is
  /// reader-side formatting and is deliberately not applied here.
  ///
  /// A rejected or malformed rule degrades to **no replacement** plus a warning
  /// (ADR-0026 §决策 2), which for a transform means “keep the text as it was
  /// extracted” instead of losing the whole chapter. Asynchronous because the engine's
  /// evaluation API is (ADR-0029 §决策 1).
  ///
  /// [jsContext] is the page a `@js:` purification rule runs against — the caller has it (it
  /// fetched the chapter), and without it a rule reading `baseUrl` would silently get an
  /// empty string.
  Future<String> replaceContent(
    String? rule,
    String content,
    String rulePath, {
    required String sourceId,
    required JsPageContext jsContext,
  }) async {
    if (rule == null || rule.trim().isEmpty) {
      return content;
    }

    final ParseResult<String> replaced = await _engine.applyReplaceRule(
      rule,
      content,
      rulePath: rulePath,
      jsContext: jsContext,
    );

    return switch (replaced) {
      ParseSuccess<String>(:final String data) => data,
      // 同 [nextPageUrls]：降级 warning 指向字段而不是 `unsupported:<语法>`。
      ParseFailure<String>(:final ParseFailureKind kind) => _noReplacement(
        sourceId,
        rulePath,
        kind,
        content,
      ),
    };
  }

  /// Logs a degraded replacement rule and hands back [content] untouched (ADR-0026).
  String _noReplacement(
    String sourceId,
    String rulePath,
    ParseFailureKind kind,
    String content,
  ) {
    _warnDegraded(sourceId, rulePath, kind, 'no replacement');

    return content;
  }

  /// Renders a URL template with the well-known variables of `book-source.md` §4 and the
  /// `{{…}}` JavaScript / nested rules of matrix #18.
  ///
  /// Kept here so the logger stays encapsulated: the renderer warns about undefined
  /// variables without any use case having to hold a logger of its own. Asynchronous
  /// because a `{{…}}` that names neither `key` / `page` / `baseUrl` nor an entry of
  /// [params] is evaluated by the sandbox (ADR-0029 §决策 1).
  Future<ParseResult<String>> renderUrl(
    String template,
    Map<String, String> params, {
    required String rulePath,
    required JsPageContext context,
  }) => _engine.renderUrl(
    template,
    rulePath: rulePath,
    params: params,
    context: context,
  );

  /// Logs a page-level warning.
  ///
  /// Exposed so a use case can report a partially usable page without taking a
  /// logger of its own; the message must never carry a page body or a keyword
  /// (C-ERR-8, C-SEC-4).
  void warn(String message) => _logger.warning(message);

  /// Builds the failure for a top-level rule that matched nothing.
  ParseFailure<T> _noMatch<T>(String rulePath) =>
      failureAt<T>(kind: ParseFailureKind.parseFailed, rulePath: rulePath);
}
