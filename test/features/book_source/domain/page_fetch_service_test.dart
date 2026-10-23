import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
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

  /// The verbs handed to the WebView, in order (ADR-0057 §决策 1).
  final List<WebPageRequestMethod> methods = <WebPageRequestMethod>[];

  /// The bodies handed to the WebView, in order.
  final List<String?> bodies = <String?>[];

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
  }) async {
    urls.add(url);
    methods.add(method);
    bodies.add(body);
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

/// Builds the service under test around [jsBridge].
({PageFetchService pages, FakeLogPrinter printer}) _service(
  FakeJsBridge jsBridge,
) {
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
      // ADR-0056：`,{webView:true}` 走 headless WebView，HTTP 不再发请求。
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
        // ADR-0057 §决策 1：表单型 `webView` 源（POST + body + webView）以前会回落普通 GET，
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
        'https://example-novel.test/s?k={{key}},{"webView":true}',
        rulePath: 'searchUrl',
        params: <String, String>{'key': '剑来'},
        context: _context(),
      );

      expect(http.requestedMethods, <String>['GET']);
      expect(
        printer.events
            .map((LogEvent event) => event.message.toString())
            .any((String message) => message.contains('option=webView')),
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
  });
}
