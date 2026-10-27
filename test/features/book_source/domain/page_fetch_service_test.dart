import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/source_login_header.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/source_login.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:logger/logger.dart';

import '../../../support/fake_http_client.dart';
import '../../../support/fake_js_bridge.dart';
import '../../../support/fake_log_printer.dart';

/// A JSON page scope, i.e. what a `@json:` rule reads (matrix #13).
RuleScope _jsonPage(String body) => RuleScope.json(body, jsContext: _context());

/// The page context of the corpus source, so a `@js:` rule has its bindings (§6).
JsPageContext _context() => const JsPageContext(
  baseUrl: 'https://example-novel.test/book/1/',
  page: 1,
  source: JsSourceInfo(name: '示例书源', url: 'https://example-novel.test'),
);

/// A DOM page scope with the same context, for the paging tests.
RuleScope _domPage(String html) =>
    RuleScope.dom(parser.parse(html), body: html, jsContext: _context());

/// A book source with the fields [PageFetchService] reads.
BookSource _source({Map<String, String>? headers, String? headerRule}) =>
    BookSource(
      name: '示例书源',
      url: 'https://example-novel.test',
      headers: headers,
      headerRule: headerRule,
      searchUrl: 'https://example-novel.test/s?q={{key}}',
      searchRule: const SearchRule(bookList: 'class.result'),
      tocRule: const TocRule(chapterList: 'class.c'),
      contentRule: const ContentRule(content: 'class.body'),
    );

/// A WebView double that records what it was asked to load and answers with a fixed page.
final class _FakeWebPages implements WebPageFetcher {
  /// URLs handed to the WebView, in order.
  final List<String> urls = <String>[];

  /// The verbs handed to the WebView, in order (ADR-0062 §决策 1).
  final List<WebPageRequestMethod> methods = <WebPageRequestMethod>[];

  /// The bodies handed to the WebView, in order.
  final List<String?> bodies = <String?>[];

  /// The scripts handed to the WebView, in order (`webJs` / `java.webView`).
  final List<String?> javaScripts = <String?>[];

  /// The headers of the last request.
  Map<String, String>? headers;

  /// The body the fake page answers with.
  String body = '<div class="body">from-webview</div>';

  /// When set, the fake WebView fails instead of rendering.
  bool fail = false;

  @override
  bool get isSupported => true;

  @override
  Future<ParseResult<FetchedWebPage>> fetch({
    required String url,
    Map<String, String>? headers,
    required String rulePath,
    WebPageRequestMethod method = WebPageRequestMethod.get,
    String? body,
    String? javaScript,
    Duration? delayTime,
    String? overrideUrlRegex,
  }) async {
    urls.add(url);
    methods.add(method);
    bodies.add(body);
    javaScripts.add(javaScript);
    this.headers = headers;
    if (fail) {
      return failureAt<FetchedWebPage>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'webView',
      );
    }

    return ParseSuccess<FetchedWebPage>(
      FetchedWebPage(url: url, body: this.body),
    );
  }
}

/// Returns the data of [result], failing the test when it failed.
T _data<T>(ParseResult<T> result) => switch (result) {
  ParseSuccess<T>(:final T data) => data,
  ParseFailure<T>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

/// Returns the failure of [result], failing the test when it succeeded.
ParseFailure<Never> _failure<T>(ParseResult<T> result) => switch (result) {
  ParseFailure<T>(:final ParseFailureKind kind, :final String rulePath) =>
    ParseFailure<Never>(kind: kind, rulePath: rulePath),
  ParseSuccess<T>() => fail('Expected a failure.'),
};

/// Builds the service under test around [jsBridge].
({PageFetchService pages, FakeLogPrinter printer}) _service(
  FakeJsBridge jsBridge, {
  SourceLoginHeaderStore? loginHeaders,
}) {
  final FakeLogPrinter printer = FakeLogPrinter();

  return (
    pages: PageFetchService(
      engine: RuleEngine(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
        jsBridge: jsBridge,
        variables: JsVariableStore(),
      ),
      http: FakeHttpClient(),
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      loginHeaders: loginHeaders,
    ),
    printer: printer,
  );
}

void main() {
  group('PageFetchService nextPageUrls', () {
    test('nextPageUrls_givenAJsonScope_rendersTheTemplate', () async {
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(FakeJsBridge());

      // JSON 接口源的页面也可以是翻页规则的 scope（矩阵 #13 的 scope 判定在规则上），
      // 所以 `_pagingContext` 必须两种 scope 都能回答。
      final List<String> urls = await service.pages.nextPageUrls(
        'toc_{{page}}.html',
        _jsonPage('{"data":{}}'),
        'tocRule.nextTocUrl',
        currentUrl: 'https://example-novel.test/book/1/',
        page: 2,
        sourceId: 'https://example-novel.test',
      );

      expect(urls, <String>['https://example-novel.test/book/1/toc_2.html']);
    });

    test('nextPageUrls_givenAnExtractedTemplate_rendersEachValue', () async {
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(FakeJsBridge());

      final List<String> urls = await service.pages.nextPageUrls(
        '@css:a#next @href',
        _domPage(
          '<div><a id="next" href="toc_2.html">下一章</a>'
          '<a id="next" href="toc_3.html">下一章</a></div>',
        ),
        'tocRule.nextTocUrl',
        currentUrl: 'https://example-novel.test/book/1/',
        page: 2,
        sourceId: 'https://example-novel.test',
      );

      expect(urls, <String>[
        'https://example-novel.test/book/1/toc_2.html',
        'https://example-novel.test/book/1/toc_3.html',
      ]);
    });

    test(
      'nextPageUrls_givenAFailingTemplateValue_degradesToNoNextPage',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..failure = failureAt<Never>(
            kind: ParseFailureKind.parseFailed,
            rulePath: 'tocRule.nextTocUrl:js:error',
          );
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(bridge);

        // 选择器读出的值本身带 `{{…}}`：渲染失败同样降级为「没有下一页」+ warning。
        final List<String> urls = await service.pages.nextPageUrls(
          '@css:a#next @href',
          _domPage('<a id="next" href="{{result}}">下一章</a>'),
          'tocRule.nextTocUrl',
          currentUrl: 'https://example-novel.test/book/1/',
          page: 2,
          sourceId: 'https://example-novel.test',
        );

        expect(urls, isEmpty);
        expect(
          service.printer.events.last.message.toString(),
          contains('no next page'),
        );
      },
    );

    test('nextPageUrls_givenAFailingTemplate_degradesToNoNextPage', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'tocRule.nextTocUrl:js:error',
        );
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(bridge);

      final List<String> urls = await service.pages.nextPageUrls(
        '{{result}}',
        _domPage('<div>page</div>'),
        'tocRule.nextTocUrl',
        currentUrl: 'https://example-novel.test/book/1/',
        page: 2,
        sourceId: 'https://example-novel.test',
      );

      // 渲染失败按 ADR-0026 §决策 2 降级为「没有下一页」+ warning（字段路径，
      // 不是引擎报的 `unsupported:<语法>`）。
      expect(urls, isEmpty);
      expect(
        service.printer.events.last.message.toString(),
        contains('no next page'),
      );
      expect(
        service.printer.events.last.message.toString(),
        contains('field=tocRule.nextTocUrl'),
      );
    });
  });

  group('PageFetchService fetchRule', () {
    test(
      'fetchRule_givenARedirectedResponse_readsThePageFromItsFinalAddress',
      () async {
        // 站点用 `302` 换地址时（ASP 的 `?token` 交接），页面的地址是**跳完之后**的地址：
        // 相对链接要按它解析，`loginCheckJs` 的 `url()` 也看它（上游 `StrResponse` 同义）。
        final FakeLogPrinter printer = FakeLogPrinter();
        final FakeHttpClient http = FakeHttpClient()
          ..serve(
            'https://example-novel.test/s?q=key',
            '<div id="content">正文</div>',
            finalUrl: 'https://example-novel.test/book/9/?9bdb14',
          );
        final PageFetchService pages = PageFetchService(
          engine: RuleEngine(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
            jsBridge: FakeJsBridge(),
            variables: JsVariableStore(),
          ),
          http: http,
          logger: AppLogger(level: LogLevel.debug, printer: printer),
        );

        final ParseResult<FetchedPage> fetched = await pages.fetchRule(
          'https://example-novel.test/s?q=key',
          rulePath: 'searchUrl',
          params: const <String, String>{},
          context: _context(),
          sourceId: 'https://example-novel.test',
        );

        final FetchedPage page = switch (fetched) {
          ParseSuccess<FetchedPage>(:final FetchedPage data) => data,
          ParseFailure<FetchedPage>() => fail('Expected the page.'),
        };
        expect(page.url, 'https://example-novel.test/book/9/?9bdb14');
        final RuleScope scope = page.scope;
        final JsPageContext? jsContext = switch (scope) {
          DomScope(:final JsPageContext? jsContext) => jsContext,
          JsonScope(:final JsPageContext? jsContext) => jsContext,
        };
        expect(jsContext?.baseUrl, 'https://example-novel.test/book/9/?9bdb14');
      },
    );

    test(
      'fetchRule_givenAPostSuffix_sendsTheBodyAndMergesTheHeaders',
      () async {
        // `url,{…}` 后缀：动词、body、charset 与 headers 全部要落到请求上
        // （book-source.md §4.3）。没有这条，50/128 条真实书源的搜索根本发不出去。
        final FakeLogPrinter printer = FakeLogPrinter();
        final FakeHttpClient http = FakeHttpClient()
          ..serve('https://example-novel.test/search.php', '<div>ok</div>');
        final PageFetchService pages = PageFetchService(
          engine: RuleEngine(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
            jsBridge: FakeJsBridge(),
            variables: JsVariableStore(),
          ),
          http: http,
          logger: AppLogger(level: LogLevel.debug, printer: printer),
        );

        final ParseResult<FetchedPage> fetched = await pages.fetchRule(
          'https://example-novel.test/search.php,{"method":"POST",'
          '"body":"searchkey={{key}}&page={{page}}","charset":"gbk",'
          '"headers":{"Referer":"https://example-novel.test/"}}',
          rulePath: 'searchUrl',
          params: <String, String>{'key': '剑来', 'page': '2'},
          context: _context(),
          headers: const <String, String>{'User-Agent': 'source-agent'},
          sourceId: 'https://example-novel.test',
        );

        expect(fetched, isA<ParseSuccess<FetchedPage>>());
        expect(http.requestedMethods, <String>['POST']);
        // GBK 的「剑来」是 %BD%A3%C0%B4：声明了 charset 就要按它编码关键词。
        expect(http.requestedBodies.single, 'searchkey=%BD%A3%C0%B4&page=2');
        expect(http.requestedCharsets.single, 'gbk');
        expect(http.requestedHeaders.single, <String, String>{
          'User-Agent': 'source-agent',
          'Referer': 'https://example-novel.test/',
        });
      },
    );

    test(
      'fetchRule_givenARenderedMalformedOption_stripsItAndFetchesTheUrl',
      () async {
        // `@js:` 规则返回「URL + 坏掉的选项」：上游丢选项继续（AnalyzeUrl），不能把
        // `,{a:}}` 当路径发出去。
        final FakeLogPrinter printer = FakeLogPrinter();
        final FakeJsBridge bridge = FakeJsBridge()
          ..result = 'https://example-novel.test/rendered,{a:}}';
        final FakeHttpClient http = FakeHttpClient()
          ..serve('https://example-novel.test/rendered', '<div>ok</div>');
        final PageFetchService pages = PageFetchService(
          engine: RuleEngine(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
            jsBridge: bridge,
            variables: JsVariableStore(),
          ),
          http: http,
          logger: AppLogger(level: LogLevel.debug, printer: printer),
        );

        final ParseResult<FetchedPage> fetched = await pages.fetchRule(
          '{{url}}',
          rulePath: 'searchUrl',
          params: const <String, String>{},
          context: _context(),
        );

        expect(fetched, isA<ParseSuccess<FetchedPage>>());
        expect(http.requestedUrls, <String>[
          'https://example-novel.test/rendered',
        ]);
      },
    );

    test('fetchRule_givenWebView_usesTheRenderedHtml', () async {
      // ADR-0061：`,{webView:true}` 走 headless WebView，HTTP 不再发请求。
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient();
      final _FakeWebPages web = _FakeWebPages();
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
        webPages: web,
      );

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/page,{"webView":true}',
        rulePath: 'ruleContent',
        params: const <String, String>{},
        context: _context(),
      );

      expect(fetched, isA<ParseSuccess<FetchedPage>>());
      expect(web.urls, <String>['https://example-novel.test/page']);
      expect(http.requestedUrls, isEmpty);
      final RuleScope scope = (fetched as ParseSuccess<FetchedPage>).data.scope;
      expect(scope, isA<DomScope>());
      expect((scope as DomScope).body, contains('from-webview'));
    });

    test('fetchRule_givenAFailingWebView_fallsBackToHttp', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve('https://example-novel.test/page', '<div>plain</div>');
      final _FakeWebPages web = _FakeWebPages()..fail = true;
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
        webPages: web,
      );

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/page,{"webView":true}',
        rulePath: 'ruleContent',
        params: const <String, String>{},
        context: _context(),
      );

      expect(fetched, isA<ParseSuccess<FetchedPage>>());
      expect(http.requestedUrls, <String>['https://example-novel.test/page']);
    });

    test(
      'fetchRule_givenWebViewOnAnUnsupportedPlatform_fallsBackToHttp',
      () async {
        final FakeLogPrinter printer = FakeLogPrinter();
        final FakeHttpClient http = FakeHttpClient()
          ..serve('https://example-novel.test/page', '<div>plain</div>');
        final PageFetchService pages = PageFetchService(
          engine: RuleEngine(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
            jsBridge: FakeJsBridge(),
            variables: JsVariableStore(),
          ),
          http: http,
          logger: AppLogger(level: LogLevel.debug, printer: printer),
        );

        final ParseResult<FetchedPage> fetched = await pages.fetchRule(
          'https://example-novel.test/page,{"webView":true}',
          rulePath: 'ruleContent',
          params: const <String, String>{},
          context: _context(),
        );

        expect(fetched, isA<ParseSuccess<FetchedPage>>());
        expect(http.requestedUrls, <String>['https://example-novel.test/page']);
      },
    );

    test(
      'fetchRule_givenWebViewPost_sendsTheFormBodyThroughTheWebView',
      () async {
        // ADR-0062 §决策 1：表单型 `webView` 源（POST + body + webView）以前会回落普通 GET，
        // 得到的永远是未提交的空结果页。
        final FakeLogPrinter printer = FakeLogPrinter();
        final FakeHttpClient http = FakeHttpClient();
        final _FakeWebPages web = _FakeWebPages();
        final PageFetchService pages = PageFetchService(
          engine: RuleEngine(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
            jsBridge: FakeJsBridge(),
            variables: JsVariableStore(),
          ),
          http: http,
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          webPages: web,
        );

        final ParseResult<FetchedPage> fetched = await pages.fetchRule(
          'https://example-novel.test/s,{"method":"POST",'
          '"body":"k={{key}}","webView":true}',
          rulePath: 'searchUrl',
          params: <String, String>{'key': '剑来'},
          context: _context(),
        );

        expect(fetched, isA<ParseSuccess<FetchedPage>>());
        expect(web.methods, <WebPageRequestMethod>[WebPageRequestMethod.post]);
        expect(web.bodies, <String?>['k=%E5%89%91%E6%9D%A5']);
        expect(
          web.headers?['Content-Type'],
          'application/x-www-form-urlencoded',
        );
        expect(http.requestedUrls, isEmpty);
      },
    );

    test('fetchRule_givenWebViewPostWithAJsonBody_keepsItVerbatim', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient();
      final _FakeWebPages web = _FakeWebPages();
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
        webPages: web,
      );

      await pages.fetchRule(
        'https://example-novel.test/v1/search,{"method":"POST",'
        '"body":"{\\"keyword\\":\\"{{key}}\\"}","webView":true}',
        rulePath: 'searchUrl',
        params: <String, String>{'key': '剑来'},
        context: _context(),
      );

      expect(web.bodies.single, '{"keyword":"剑来"}');
      expect(web.headers?['Content-Type'], 'application/json');
    });

    test('fetchRule_givenWebViewPostWithADeclaredType_keepsIt', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient();
      final _FakeWebPages web = _FakeWebPages();
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
        webPages: web,
      );

      await pages.fetchRule(
        'https://example-novel.test/s,{"method":"POST","body":"k={{key}}",'
        '"headers":{"Content-Type":"text/plain;charset=gbk"},"webView":true}',
        rulePath: 'searchUrl',
        params: <String, String>{'key': '剑来'},
        context: _context(),
      );

      expect(web.headers?['Content-Type'], 'text/plain;charset=gbk');
    });

    test('fetchRule_givenWebViewGet_declaresNoContentType', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient();
      final _FakeWebPages web = _FakeWebPages();
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
        webPages: web,
      );

      await pages.fetchRule(
        'https://example-novel.test/page,{"webView":true}',
        rulePath: 'ruleContent',
        params: const <String, String>{},
        context: _context(),
      );

      expect(web.headers?.containsKey('Content-Type'), isFalse);
      expect(web.bodies, <String?>[null]);
    });

    test('fetchRule_givenAJsonBody_keepsTheKeywordVerbatim', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve('https://example-novel.test/v1/search', '<div>ok</div>');
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      await pages.fetchRule(
        'https://example-novel.test/v1/search,{"method":"POST",'
        '"body":"{\\"keyword\\":\\"{{key}}\\"}"}',
        rulePath: 'searchUrl',
        params: <String, String>{'key': '剑来'},
        context: _context(),
      );

      // JSON 载荷里关键词不能百分号编码（上游同样跳过表单编码）。
      expect(http.requestedBodies.single, '{"keyword":"剑来"}');
    });

    test('fetchRule_givenAnUnreadableSuffix_failsByName', () async {
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(FakeJsBridge());

      final ParseResult<FetchedPage> result = await service.pages.fetchRule(
        'https://example-novel.test/s?k={{key}},{oops}',
        rulePath: 'searchUrl',
        params: <String, String>{'key': '剑来'},
        context: _context(),
      );

      expect(result, isA<ParseFailure<FetchedPage>>());
      expect(
        (result as ParseFailure<FetchedPage>).rulePath,
        'unsupported:url-options',
      );
    });

    test('fetchRule_givenABodyWhoseTemplateFails_failsTheRequest', () async {
      // body 里也有 `{{…}}`：它的求值失败必须让整条规则失败，而不是发一个半截载荷。
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = const ParseFailure<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'js:error',
        );
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(bridge);
      final FakeHttpClient http = FakeHttpClient();
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: service.printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: service.printer),
      );

      final ParseResult<FetchedPage> result = await pages.fetchRule(
        'https://example-novel.test/s,{"method":"POST","body":"a={{boom()}}"}',
        rulePath: 'searchUrl',
        params: const <String, String>{},
        context: _context(),
      );

      expect(result, isA<ParseFailure<FetchedPage>>());
      expect(http.requestedUrls, isEmpty);
    });

    test('fetchRule_givenUnsupportedOptions_warnsByOptionName', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/s?k=%E5%89%91%E6%9D%A5',
          '<div>ok</div>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      await pages.fetchRule(
        'https://example-novel.test/s?k={{key}},{"origin":"https://a.test"}',
        rulePath: 'searchUrl',
        params: <String, String>{'key': '剑来'},
        context: _context(),
      );

      expect(http.requestedMethods, <String>['GET']);
      expect(
        printer.events
            .map((LogEvent event) => event.message.toString())
            .any((String message) => message.contains('option=origin')),
        isTrue,
      );
    });
  });

  group('PageFetchService headersOf', () {
    test('headersOf_givenAStaticObject_answersItUnchanged', () async {
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(FakeJsBridge());
      final BookSource source = _source(
        headers: const <String, String>{'User-Agent': 'x'},
      );

      expect(await service.pages.headersOf(source), <String, String>{
        'User-Agent': 'x',
      });
    });

    test('headersOf_givenAHeaderRule_evaluatesItBeforeTheRequest', () async {
      // M12-A2：`header: "<js>…</js>"` 是**规则**，要在取页之前求值，得到的 JSON 才是实际
      // header。真实语料的书香之家 / 必看悦读 / 阅友小说都这么写。
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = '{"User-Agent": "rule-agent", "Referer": "https://a.test/"}';
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(bridge);
      final BookSource source = _source(
        headers: const <String, String>{'Accept': 'x'},
        headerRule: "<js>JSON.stringify({'User-Agent': 'rule-agent'})</js>",
      );

      final Map<String, String>? headers = await service.pages.headersOf(
        source,
      );

      expect(headers, <String, String>{
        'Accept': 'x',
        'User-Agent': 'rule-agent',
        'Referer': 'https://a.test/',
      });
      // 规则本体（不含 `<js>` 包装）才是脚本。
      expect(
        bridge.jobs.single.script,
        contains("JSON.stringify({'User-Agent': 'rule-agent'})"),
      );
      expect(bridge.jobs.single.rulePath, 'header');
    });

    test('headersOf_givenAFailingHeaderRule_keepsTheStaticHeaders', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = const ParseFailure<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'js:error',
        );
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(bridge);
      final BookSource source = _source(
        headers: const <String, String>{'Accept': 'x'},
        headerRule: '@js:boom()',
      );

      expect(await service.pages.headersOf(source), <String, String>{
        'Accept': 'x',
      });
      expect(
        service.printer.events
            .map((LogEvent event) => event.message)
            .any(
              (Object? message) => '$message'.contains('Header rule failed'),
            ),
        isTrue,
      );
    });

    test('headersOf_givenAHeaderRuleThatAnswersANonJsonValue_warns', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 42;
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(bridge);

      expect(
        await service.pages.headersOf(_source(headerRule: '@js:42')),
        isNull,
      );
    });

    test('headersOf_givenAStoredLoginHeader_mergesItOverTheDeclared', () async {
      // M25/S3b：上游 `getHeaderMap(userAgent, hasLoginHeader = true)` 把登录头压在源自己的
      // header 之上——登录换来的 token 要能盖掉源里写死的那个。
      final SourceLoginHeaderStore loginHeaders = SourceLoginHeaderStore(
        repository: InMemorySourceLoginHeaderRepository(),
      );
      await loginHeaders.ensureLoaded('https://example-novel.test');
      loginHeaders.put(
        'https://example-novel.test',
        '{"Token":"t","Referer":"https://login.test/"}',
      );
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(FakeJsBridge(), loginHeaders: loginHeaders);
      final BookSource source = _source(
        headers: const <String, String>{
          'Referer': 'https://declared.test/',
          'Accept': 'x',
        },
      );

      expect(await service.pages.headersOf(source), <String, String>{
        'Accept': 'x',
        'Referer': 'https://login.test/',
        'Token': 't',
      });
    });

    test('headersOf_givenNoLoginHeader_answersTheDeclaredMap', () async {
      final SourceLoginHeaderStore loginHeaders = SourceLoginHeaderStore(
        repository: InMemorySourceLoginHeaderRepository(),
      );
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(FakeJsBridge(), loginHeaders: loginHeaders);
      final BookSource source = _source(
        headers: const <String, String>{'Accept': 'x'},
      );

      expect(await service.pages.headersOf(source), <String, String>{
        'Accept': 'x',
      });
    });

    test('headersOf_givenALoginHeaderThatIsNotJson_warnsAndSkips', () async {
      // 规则可以往登录头里写任何东西：坏值只该丢这次的合并，不该让请求失败。
      final SourceLoginHeaderStore loginHeaders = SourceLoginHeaderStore(
        repository: InMemorySourceLoginHeaderRepository(),
      );
      await loginHeaders.ensureLoaded('https://example-novel.test');
      loginHeaders.put('https://example-novel.test', 'not json');
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(FakeJsBridge(), loginHeaders: loginHeaders);

      expect(
        await service.pages.headersOf(
          _source(headers: const <String, String>{'Accept': 'x'}),
        ),
        <String, String>{'Accept': 'x'},
      );
      expect(
        service.printer.events
            .map((LogEvent event) => event.message)
            .any(
              (Object? message) =>
                  '$message'.contains('Login header is not a JSON object'),
            ),
        isTrue,
      );
    });

    test('headersOf_givenAHeaderRuleThatIsNotAnObject_warns', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'not json';
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(bridge);

      expect(
        await service.pages.headersOf(_source(headerRule: '@js:"x"')),
        isNull,
      );
      expect(
        service.printer.events
            .map((LogEvent event) => event.message)
            .any(
              (Object? message) =>
                  '$message'.contains('did not produce a JSON object'),
            ),
        isTrue,
      );
    });
  });

  group('PageFetchService renderUrl', () {
    test('renderUrl_givenAKnownVariable_rendersItAsATemplate', () async {
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(FakeJsBridge());

      final ParseResult<String> rendered = await service.pages.renderUrl(
        'https://example-novel.test/search?q={{key}}',
        <String, String>{'key': '中文 书'},
        rulePath: 'searchUrl',
        context: _context(),
      );

      expect(
        (rendered as ParseSuccess<String>).data,
        'https://example-novel.test/search?q=%E4%B8%AD%E6%96%87+%E4%B9%A6',
      );
    });

    test('fetchRule_givenRetryAndReadTimeout_passesThemToTheClient', () async {
      // ADR-0068 §决策 8：`retry` 与 `readTimeout` 是**这一条请求**的覆盖，上限在解析侧钳住。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/s?k=%E5%89%91%E6%9D%A5',
          '<div>ok</div>',
        );
      final FakeLogPrinter printer = FakeLogPrinter();
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      await pages.fetchRule(
        'https://example-novel.test/s?k={{key}},'
        '{"retry":2,"readTimeout":5000}',
        rulePath: 'searchUrl',
        params: <String, String>{'key': '剑来'},
        context: _context(),
      );

      expect(http.requestedMaxRetries, <int?>[2]);
      expect(http.requestedReceiveTimeouts, <Duration?>[
        const Duration(seconds: 5),
      ]);
    });
  });

  group('PageFetchService fetchRendered', () {
    test('fetchRendered_givenARenderer_answersItsBody', () async {
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(FakeJsBridge());
      final _FakeWebPages web = _FakeWebPages();

      final ParseResult<String> body =
          await PageFetchService(
            engine: RuleEngine(
              logger: AppLogger(
                level: LogLevel.debug,
                printer: service.printer,
              ),
              jsBridge: FakeJsBridge(),
              variables: JsVariableStore(),
            ),
            http: FakeHttpClient(),
            logger: AppLogger(level: LogLevel.debug, printer: service.printer),
            webPages: web,
          ).fetchRendered(
            'https://example-novel.test/page',
            rulePath: 'contentRule.webJs',
            script: 'document.title',
          );

      expect(_data(body), contains('webview'));
      expect(web.javaScripts.single, 'document.title');
    });

    test('fetchRendered_givenAFailingRenderer_mapsTheFailure', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: FakeHttpClient(),
        logger: AppLogger(level: LogLevel.debug, printer: printer),
        webPages: _FakeWebPages()..fail = true,
      );

      final ParseResult<String> body = await pages.fetchRendered(
        'https://example-novel.test/page',
        rulePath: 'contentRule.webJs',
        script: 'document.title',
      );

      expect(_failure(body).kind, ParseFailureKind.unsupportedRule);
    });
  });

  group('PageFetchService loginCheckJs', () {
    // `loginCheckJs` 是**响应拦截器**，不是布尔检查（ADR-0068 增补）：宿主把响应交给脚本，
    // 脚本的返回值替换本次响应。
    test('loginCheckJs_givenNoScript_runsNoJob', () async {
      final FakeJsBridge bridge = FakeJsBridge();
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(bridge);
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/s?q=x',
          '<div class="result">ok</div>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: service.printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: service.printer),
      );

      // 运行时构造：`const` 会在编译期折叠，覆盖率统计不到这个构造（testing.md §2）。
      // ignore: prefer_const_constructors
      final SourceLoginGuard noLogin = SourceLoginGuard.none();

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/s?q={{key}}',
        rulePath: 'searchUrl',
        params: const <String, String>{'key': 'x'},
        context: _context(),
        login: noLogin,
      );

      expect(fetched, isA<ParseSuccess<FetchedPage>>());
      expect(
        bridge.jobs.where((JsJob job) => job.rulePath == 'loginCheckJs'),
        isEmpty,
      );
    });

    test('loginCheckJs_givenAScript_handsItTheResponseObject', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = null;
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/s?q=x',
          '<div class="result">ok</div>',
          headers: const <String, List<String>>{
            'content-type': <String>['text/html', 'charset=utf-8'],
            'set-cookie': <String>['a=1'],
          },
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/s?q={{key}}',
        rulePath: 'searchUrl',
        params: const <String, String>{'key': 'x'},
        context: _context(),
        login: const SourceLoginGuard(checkScript: 'result'),
      );

      final JsJob job = bridge.jobs.singleWhere(
        (JsJob job) => job.rulePath == 'loginCheckJs',
      );
      expect(job.response?.url, 'https://example-novel.test/s?q=x');
      expect(job.response?.body, contains('result'));
      expect(job.response?.code, 200);
      // 多值头按 `, ` 拼起来，脚本里的 `result.headers()` 才有东西可读。
      expect(job.response?.headers['content-type'], 'text/html, charset=utf-8');
      expect(job.response?.headers['set-cookie'], 'a=1');
      expect(job.script, 'result');
      // 脚本没改响应（`null`）：页面原样留下。
      expect(_data(fetched).url, 'https://example-novel.test/s?q=x');
    });

    test('loginCheckJs_givenAReplacement_rebuildsThePageScope', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = <String, Object?>{
          'body': '<div class="result">after-login</div>',
          '__url': 'https://example-novel.test/s?q=after',
        };
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/s?q=x',
          '<div class="result">need-login</div>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final FetchedPage page = _data(
        await pages.fetchRule(
          'https://example-novel.test/s?q={{key}}',
          rulePath: 'searchUrl',
          params: const <String, String>{'key': 'x'},
          context: _context(),
          login: const SourceLoginGuard(checkScript: 'result'),
        ),
      );

      expect(page.url, 'https://example-novel.test/s?q=after');
      expect(
        (page.scope as DomScope).body,
        '<div class="result">after-login</div>',
      );
      final ParseResult<String?> name = await pages.field(
        'class.result@text',
        page.scope,
        'searchRule.name',
        sourceId: 'https://example-novel.test',
      );
      expect(_data(name), 'after-login');
    });

    test('loginCheckJs_givenTheSameBody_keepsTheOriginalScope', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = <String, Object?>{'body': '<div class="result">ok</div>'};
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/s?q=x',
          '<div class="result">ok</div>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final FetchedPage page = _data(
        await pages.fetchRule(
          'https://example-novel.test/s?q={{key}}',
          rulePath: 'searchUrl',
          params: const <String, String>{'key': 'x'},
          context: _context(),
          login: const SourceLoginGuard(checkScript: 'result'),
        ),
      );

      expect((page.scope as DomScope).body, '<div class="result">ok</div>');
      // 返回 `result` 是最常见的写法：内容没变就不要重建成第二份 DOM。
      expect(page.scope, isA<DomScope>());
    });

    test('loginCheckJs_givenJunkAndNoLoginField_failsTheStage', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = true;
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/s?q=x',
          '<div class="result">ok</div>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/s?q={{key}}',
        rulePath: 'searchUrl',
        params: const <String, String>{'key': 'x'},
        context: _context(),
        login: const SourceLoginGuard(checkScript: 'result'),
      );

      expect(_failure(fetched).kind, ParseFailureKind.parseFailed);
      expect(_failure(fetched).rulePath, 'loginCheckJs');
      expect(
        printer.events.last.message.toString(),
        contains('loginCheckJs did not return a response'),
      );
    });

    test('loginCheckJs_givenJunkAndALoginPage_saysLoginRequired', () async {
      // 源声明了 loginUrl，所以“脚本没能修好会话”的唯一可行动答案就是「去登录」。
      final FakeJsBridge bridge = FakeJsBridge()..result = 42;
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/s?q=x',
          '<div class="result">ok</div>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/s?q={{key}}',
        rulePath: 'searchUrl',
        params: const <String, String>{'key': 'x'},
        context: _context(),
        login: const SourceLoginGuard(
          checkScript: 'result',
          loginUrl: 'https://example-novel.test/login',
        ),
      );

      expect(_failure(fetched).kind, ParseFailureKind.loginRequired);
    });

    test('loginCheckJs_givenAFailingJob_carriesTheFailureThrough', () async {
      // 用户在验证页上取消：拦截器等的是人，脚本吞不掉这个答案（ADR-0068 §决策 10）。
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.cancelled,
          rulePath: 'java.startBrowserAwait',
        );
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/s?q=x',
          '<div class="result">ok</div>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/s?q={{key}}',
        rulePath: 'searchUrl',
        params: const <String, String>{'key': 'x'},
        context: _context(),
        login: const SourceLoginGuard(checkScript: 'result'),
      );

      expect(_failure(fetched).kind, ParseFailureKind.cancelled);
    });

    test('walk_givenAPagedRead_interceptsEveryPage', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = null;
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/book/1/ch1.html',
          '<div class="body">第一页</div><a id="next" href="ch1_2.html">下一章</a>',
        )
        ..serve(
          'https://example-novel.test/book/1/ch1_2.html',
          '<div class="body">第二页</div>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final PageWalk walk = _data(
        await pages.walk(
          rule: 'https://example-novel.test/book/1/ch1.html',
          rulePath: 'ruleContent',
          nextRule: '@css:a#next @href',
          nextRulePath: 'contentRule.nextContentUrl',
          context: _context(),
          sourceId: 'https://example-novel.test',
          login: const SourceLoginGuard(checkScript: 'result'),
        ),
      );

      expect(walk.pages, hasLength(2));
      expect(
        bridge.jobs.where((JsJob job) => job.rulePath == 'loginCheckJs'),
        hasLength(2),
      );
    });
  });

  group('PageFetchService post-processing', () {
    // ADR-0068 §决策 7：`sourceRegex` 先截取再建 scope，`bodyJs` 对响应体跑脚本。
    test('sourceRegex_givenAMatch_buildsTheScopeFromTheFragment', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/book/1/ch1.html',
          '<html><body><script>var shell = 1;</script>'
              '<div class="payload">{"data":{"body":"正文片段"}}</div>'
              '</body></html>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final FetchedPage page = _data(
        await pages.fetchRule(
          'https://example-novel.test/book/1/ch1.html',
          rulePath: 'ruleContent',
          params: const <String, String>{},
          context: _context(),
          sourceRegex: r'<div class="payload">([\s\S]*?)</div>',
        ),
      );

      // 片段就是页面：DOM 与 `$` 规则都从它读，壳里的其它东西不再存在。
      expect((page.scope as DomScope).body, '{"data":{"body":"正文片段"}}');
      final ParseResult<String?> text = await pages.field(
        r'$.data.body',
        page.scope,
        'contentRule.content',
        sourceId: 'https://example-novel.test',
      );
      expect(_data(text), '正文片段');
    });

    test('sourceRegex_givenNoMatch_failsTheStage', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/book/1/ch1.html',
          '<div>登录后可见</div>',
        );
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/book/1/ch1.html',
        rulePath: 'ruleContent',
        params: const <String, String>{},
        context: _context(),
        sourceRegex: r'<div class="body">([\s\S]*?)</div>',
      );

      expect(_failure(fetched).kind, ParseFailureKind.parseFailed);
      expect(_failure(fetched).rulePath, 'contentRule.sourceRegex');
    });

    test('bodyJs_givenAScript_replacesTheBody', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = '<div class="body">脚本拼的</div>';
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve('https://example-novel.test/book/1/ch1.html', 'raw-payload');
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final FetchedPage page = _data(
        await pages.fetchRule(
          'https://example-novel.test/book/1/ch1.html,{"bodyJs":"decode(result)"}',
          rulePath: 'ruleContent',
          params: const <String, String>{},
          context: _context(),
        ),
      );

      expect(bridge.jobs.single.rulePath, 'bodyJs');
      expect(bridge.jobs.single.result, 'raw-payload');
      expect((page.scope as DomScope).body, '<div class="body">脚本拼的</div>');
    });

    test('bodyJs_givenANonStringAnswer_failsTheStage', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 42;
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve('https://example-novel.test/book/1/ch1.html', 'raw-payload');
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/book/1/ch1.html,{"bodyJs":"1"}',
        rulePath: 'ruleContent',
        params: const <String, String>{},
        context: _context(),
      );

      expect(_failure(fetched).kind, ParseFailureKind.parseFailed);
      expect(_failure(fetched).rulePath, 'bodyJs');
    });

    test('bodyJs_givenAFailingScript_carriesTheFailure', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'bodyJs:js:error',
        );
      final FakeLogPrinter printer = FakeLogPrinter();
      final FakeHttpClient http = FakeHttpClient()
        ..serve('https://example-novel.test/book/1/ch1.html', 'raw-payload');
      final PageFetchService pages = PageFetchService(
        engine: RuleEngine(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<FetchedPage> fetched = await pages.fetchRule(
        'https://example-novel.test/book/1/ch1.html,{"bodyJs":"boom()"}',
        rulePath: 'ruleContent',
        params: const <String, String>{},
        context: _context(),
      );

      expect(_failure(fetched).rulePath, 'bodyJs:js:error');
    });
  });
}
