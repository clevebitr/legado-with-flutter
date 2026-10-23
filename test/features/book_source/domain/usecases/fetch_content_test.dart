import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_content_cache.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// The real default-rule source of the offline corpus.
const String _sourceFixture =
    'test/fixtures/book_sources/legado_default_rules_source.json';

/// A chapter URL of the corpus.
const String _chapterUrl = 'https://example-novel.test/book/1/1.html';

/// Loads the corpus book source.
BookSource _source() => BookSource.fromLegadoJson(
  jsonDecode(File(_sourceFixture).readAsStringSync()) as Map<String, Object?>,
);

/// Reads one page of the offline corpus.
String _page(String name) =>
    File('test/fixtures/html/$name').readAsStringSync();

/// The corpus source with [rule] installed as its `nextContentUrl` (PLAN 3.5).
BookSource _pagingSource(String rule) {
  final BookSource source = _source();

  return source.copyWith(
    contentRule: source.contentRule.copyWith(nextContentUrl: rule),
  );
}

/// The corpus source with a JS extraction, so a job is really created (ADR-0049 test).
BookSource _jsContentSource() {
  final BookSource source = _source();

  return source.copyWith(
    contentRule: source.contentRule.copyWith(
      content: 'class.content@text@js:result',
    ),
  );
}

/// The corpus source with [rule] installed as its `replaceRegex` (PLAN 3.5).
BookSource _purifyingSource(String rule) {
  final BookSource source = _source();

  return source.copyWith(
    contentRule: source.contentRule.copyWith(replaceRegex: rule),
  );
}

/// Builds the page service under test around [http] and [bridge].
PageFetchService _service(FakeHttpClient http, [FakeJsBridge? bridge]) =>
    _serviceAndPrinter(http, bridge).pages;

/// Builds the page service under test plus the printer its logger writes to.
({PageFetchService pages, FakeLogPrinter printer}) _serviceAndPrinter(
  FakeHttpClient http, [
  FakeJsBridge? bridge,
]) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);

  return (
    pages: PageFetchService(
      engine: RuleEngine(
        logger: logger,
        jsBridge: bridge ?? FakeJsBridge(),
        variables: JsVariableStore(),
      ),
      http: http,
      logger: logger,
    ),
    printer: printer,
  );
}

/// Returns the failure of [result], failing the test when it succeeded.
ParseFailure<Never> _failure<T>(ParseResult<T> result) => switch (result) {
  ParseFailure<T>(:final ParseFailureKind kind, :final String rulePath) =>
    ParseFailure<Never>(kind: kind, rulePath: rulePath),
  ParseSuccess<T>() => fail('Expected a failure.'),
};

/// Returns the data of [result], failing the test when it failed.
T _data<T>(ParseResult<T> result) => switch (result) {
  ParseSuccess<T>(:final T data) => data,
  ParseFailure<T>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

void main() {
  group('FetchContent', () {
    test('execute_givenChapterPage_returnsThePlainTextBody', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));

      final String content = _data(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(_source(), const ChapterRequest(url: _chapterUrl)),
      );

      expect(http.requestedUrls, <String>[_chapterUrl]);
      expect(http.requestedRulePaths, <String>['ruleContent']);
      expect(content, '正文第一段。\n正文第二段。\n正文第三段。');
    });

    test('execute_givenACachedChapter_returnsItWithoutAnyRequest', () async {
      // docs/dev/roadmap.md 5.2 的验收：命中缓存时**一个请求都不发**（缓存存的是成品正文，
      // 所以命中可以直接跳过整个引擎，连源自己的限速都不必进预算）。
      final FakeHttpClient http = FakeHttpClient();
      final FakeContentCache cache = FakeContentCache();
      final BookSource source = _source();
      cache.entries['${source.url}|$_chapterUrl'] = '已缓存的正文';

      final String content = _data(
        await FetchContent(
          pages: _service(http),
          cache: cache,
        ).execute(source, const ChapterRequest(url: _chapterUrl)),
      );

      expect(content, '已缓存的正文');
      expect(http.requestedUrls, isEmpty);
    });

    test('execute_givenAFreshChapter_storesTheFinishedBody', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));
      final FakeContentCache cache = FakeContentCache();
      final BookSource source = _source();

      final String content = _data(
        await FetchContent(
          pages: _service(http),
          cache: cache,
        ).execute(source, const ChapterRequest(url: _chapterUrl)),
      );

      expect(cache.writes, <String>['${source.url}|$_chapterUrl']);
      expect(cache.entries.values.single, content);
    });

    test('execute_givenTheSameChapterTwice_requestsItOnlyOnce', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));
      final FakeContentCache cache = FakeContentCache();
      final BookSource source = _source();
      final FetchContent useCase = FetchContent(
        pages: _service(http),
        cache: cache,
      );

      final String first = _data(
        await useCase.execute(source, const ChapterRequest(url: _chapterUrl)),
      );
      final String second = _data(
        await useCase.execute(source, const ChapterRequest(url: _chapterUrl)),
      );

      // 第二次读的是缓存：只有第一个请求，正文逐字相同。
      expect(http.requestedUrls, <String>[_chapterUrl]);
      expect(second, first);
    });

    test('execute_givenAFailure_storesNothing', () async {
      // 失败不得被当成内容缓存下来（否则一章的失败会永久粘住）。
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_chapterUrl, ParseFailureKind.networkForbidden);
      final FakeContentCache cache = FakeContentCache();

      _failure(
        await FetchContent(
          pages: _service(http),
          cache: cache,
        ).execute(_source(), const ChapterRequest(url: _chapterUrl)),
      );

      expect(cache.writes, isEmpty);
    });

    test('execute_givenHttpFailure_returnsTheSameFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_chapterUrl, ParseFailureKind.networkForbidden);

      final ParseFailure<Never> failure = _failure(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(_source(), const ChapterRequest(url: _chapterUrl)),
      );

      expect(failure.kind, ParseFailureKind.networkForbidden);
      expect(failure.rulePath, 'ruleContent');
    });

    test('execute_givenPageWithoutContent_returnsParseFailed', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, '<html><body><p>空页</p></body></html>');

      final ParseFailure<Never> failure = _failure(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(_source(), const ChapterRequest(url: _chapterUrl)),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'contentRule.content');
    });

    test(
      'execute_givenUnsupportedContentRule_propagatesUnsupportedRule',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_chapterUrl, _page('chapter_page.html'));
        final BookSource source = _source();
        final BookSource withJs = source.copyWith(
          contentRule: source.contentRule.copyWith(content: '@xpath://div'),
        );

        final ParseFailure<Never> failure = _failure(
          await FetchContent(
            pages: _service(http),
            cache: FakeContentCache(),
          ).execute(withJs, const ChapterRequest(url: _chapterUrl)),
        );

        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@xpath:');
      },
    );

    test('execute_givenSourceWithHeaders_sendsThemToTheClient', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));
      final BookSource source = _source().copyWith(
        headers: <String, String>{'Referer': 'https://example-novel.test/'},
      );

      await FetchContent(
        pages: _service(http),
        cache: FakeContentCache(),
      ).execute(source, const ChapterRequest(url: _chapterUrl));

      // `book-source.md` §2 的 `header` 字段是 M0：声明了浏览器 UA / Referer 的书源
      // 必须真的把请求头带出去，否则站点会把它当成机器人（G2b spot-check 发现的缺陷）。
      expect(http.requestedHeaders, <Map<String, String>>[
        <String, String>{'Referer': 'https://example-novel.test/'},
      ]);
      // 书源 ID 同行：HTTP 层用它给 ADR-0031 §决策 2 的宽容解码 warning 定位书源（C-ERR-8）。
      expect(http.requestedSourceIds, <String>[source.url]);
    });

    test('execute_givenNextContentUrl_joinsEveryPageOfTheChapter', () async {
      const String secondPage = 'https://example-novel.test/book/1/2.html';
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '<div id="content">第一页。</div>'
          '<a id="next" href="2.html">下一页</a>',
        )
        ..serve(secondPage, '<div id="content">第二页。</div>');

      final String content = _data(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(
          _pagingSource('@css:a#next @href'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      // 正文分页按上游 appendContent 的方式用换行拼接（BookContent.kt:70-76）。
      expect(http.requestedUrls, <String>[_chapterUrl, secondPage]);
      expect(content, '第一页。\n第二页。');
    });

    test('execute_givenALaterContentPageFails_failsTheWholeChapter', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '<div id="content">第一页。</div>'
          '<a id="next" href="2.html">下一页</a>',
        );

      final ParseFailure<Never> failure = _failure(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(
          _pagingSource('@css:a#next @href'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      // 与目录不同：正文取不全就是「该章失败」，不能把截断的正文当成成功（§9）。
      expect(failure.kind, ParseFailureKind.notFound);
      expect(failure.rulePath, 'ruleContent');
    });

    test(
      'execute_givenAChapterRequest_feedsBookNameAndTitleToTheJob',
      () async {
        // M12-A5 / ADR-0049：正文规则里的 `java.get('bookName' / 'title')` 要真的读到书与章节。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_chapterUrl, '<div id="content">正文。</div>');
        final FakeJsBridge bridge = FakeJsBridge()..result = '正文';

        _data(
          await FetchContent(
            pages: _service(http, bridge),
            cache: FakeContentCache(),
          ).execute(
            // 正文规则写成 `@js:` 才会拉起一次沙箱调用。
            _jsContentSource(),
            const ChapterRequest(
              url: _chapterUrl,
              title: '第一章',
              bookName: '示例书',
            ),
          ),
        );

        expect(bridge.jobs.single.bookName, '示例书');
        expect(bridge.jobs.single.chapterTitle, '第一章');
      },
    );

    test('execute_givenReplaceRegex_purifiesTheJoinedBody', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, '<div id="content">正文。本章未完，点击下一页继续阅读。后续。</div>');

      final String content = _data(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(
          _purifyingSource('##本章未完，点击下一页继续阅读。'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(content, '正文。后续。');
    });

    test('execute_givenUnsupportedReplaceRegex_keepsTheBodyAndWarns', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _serviceAndPrinter(http);

      final String content = _data(
        await FetchContent(
          pages: service.pages,
          cache: FakeContentCache(),
        ).execute(
          _purifyingSource('@xpath://div'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      // ADR-0026 §决策 2：非顶层字段被拒 → 降级为「不替换」，正文照常返回。
      expect(content, '正文第一段。\n正文第二段。\n正文第三段。');
      expect(
        service.printer.events.last.message.toString(),
        allOf(contains('contentRule.replaceRegex'), contains('no replacement')),
      );
    });

    test(
      'execute_givenATemplateInTheExtractedUrl_rendersItBeforeRequesting',
      () async {
        const String secondPage =
            'https://example-novel.test/book/1/1.html?p=2';
        final FakeHttpClient http = FakeHttpClient()
          ..serve(
            _chapterUrl,
            '<div id="content">第一页。</div>'
            '<a id="next" href="{{baseUrl}}?p=2">下一页</a>',
          )
          ..serve(secondPage, '<div id="content">第二页。</div>');

        final String content = _data(
          await FetchContent(
            pages: _service(http),
            cache: FakeContentCache(),
          ).execute(
            _pagingSource('@css:a#next @href'),
            const ChapterRequest(url: _chapterUrl),
          ),
        );

        // `{{baseUrl}}` = 读到该规则的那一页（§4.1）；渲染后不得把 `{{}}` 交给 HTTP 层。
        expect(http.requestedUrls, <String>[_chapterUrl, secondPage]);
        expect(
          http.requestedUrls.any((String url) => url.contains('{{')),
          isFalse,
        );
        expect(content, '第一页。\n第二页。');
      },
    );
  });
}
