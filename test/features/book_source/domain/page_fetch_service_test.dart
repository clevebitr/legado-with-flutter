import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;

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
