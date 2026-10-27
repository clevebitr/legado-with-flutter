import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';
import 'package:flutter_reader/features/book_source/domain/content_purifier.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_content.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/purge_rules_port.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

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

/// Serves one rendered page for `ruleContent.webJs` (`docs/dev/roadmap.md` M21a).
final class _FakeWebPages implements WebPageFetcher {
  /// The HTML every render answers with.
  String body = '<div id="content">渲染后的正文</div>';

  /// The scripts the use case asked for, in order.
  final List<String?> scripts = <String?>[];

  /// When true the render fails instead of answering a page.
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
    scripts.add(javaScript);
    if (fail) {
      return const ParseFailure<FetchedWebPage>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'contentRule.webJs',
      );
    }

    return ParseSuccess<FetchedWebPage>(
      FetchedWebPage(url: url, body: this.body),
    );
  }
}

/// Builds the page service under test around [http] and [bridge].
PageFetchService _service(
  FakeHttpClient http, [
  FakeJsBridge? bridge,
  WebPageFetcher? webPages,
]) => _serviceAndPrinter(http, bridge, webPages).pages;

/// Builds the page service under test plus the printer its logger writes to.
({PageFetchService pages, FakeLogPrinter printer}) _serviceAndPrinter(
  FakeHttpClient http, [
  FakeJsBridge? bridge,
  WebPageFetcher? webPages,
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
      webPages: webPages,
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

/// The finished body of a successful read (ADR-0078 S2: the stage answers a [ChapterContent]).
String _body(ParseResult<ChapterContent> result) => _data(result).body;

/// The whole result of a successful read.
ChapterContent _content(ParseResult<ChapterContent> result) => _data(result);

void main() {
  group('FetchContent', () {
    test('execute_givenAChapterUrlWithOptions_requestsTheCleanUrl', () async {
      // 章节地址带 `,{webView:…}` 时，取页必须先切选项：整串请求会 404（M17 真源普查）。
      const String withOptions =
          'https://example-novel.test/book/1/1.html,{webView:“true”}';
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));

      final String content = _body(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(_source(), const ChapterRequest(url: withOptions)),
      );

      expect(http.requestedUrls, <String>[_chapterUrl]);
      expect(content, isNotEmpty);
    });

    test('execute_givenChapterPage_returnsThePlainTextBody', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));

      final String content = _body(
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

      final String content = _body(
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

      final String content = _body(
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

      final String first = _body(
        await useCase.execute(source, const ChapterRequest(url: _chapterUrl)),
      );
      final String second = _body(
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

      final String content = _body(
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

    test(
      'execute_givenAChapterWithNeighbours_feedsTheChapterBindings',
      () async {
        // M25/S3b：正文阶段的 `chapter` / `nextChapterUrl` 是目录给出的，规则靠它们拼下一页。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_chapterUrl, '<div id="content">正文。</div>');
        final FakeJsBridge bridge = FakeJsBridge()..result = '正文';

        _data(
          await FetchContent(
            pages: _service(http, bridge),
            cache: FakeContentCache(),
          ).execute(
            _jsContentSource(),
            const ChapterRequest(
              url: _chapterUrl,
              title: '第一章',
              bookName: '示例书',
              nextChapterUrl: 'https://example-novel.test/book/1/2.html',
              isVip: true,
              isPay: true,
              updateTime: '2026-10-26',
            ),
          ),
        );

        final JsJob job = bridge.jobs.single;
        expect(job.chapter?.title, '第一章');
        expect(job.chapter?.url, _chapterUrl);
        expect(job.chapter?.isVip, isTrue);
        expect(job.chapter?.isPay, isTrue);
        expect(job.chapter?.updateTime, '2026-10-26');
        expect(job.nextChapterUrl, 'https://example-novel.test/book/1/2.html');
        // 正文页的正文就是 `src`（上游 `AnalyzeRule.evalJS` 的 `content`）。
        expect(job.src, '<div id="content">正文。</div>');
      },
    );

    test('execute_givenReplaceRegex_purifiesTheJoinedBody', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, '<div id="content">正文。本章未完，点击下一页继续阅读。后续。</div>');

      final String content = _body(
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

      final String content = _body(
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

    test('execute_givenPurgeRules_appliesThemAfterReplaceRegex', () async {
      // M20 的接线位置（ADR-0070 §决策 3）：源自己的 `replaceRegex` 先跑，净化规则后跑。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));
      final FakeContentCache cache = FakeContentCache();

      final String content = _body(
        await FetchContent(
          pages: _service(http),
          cache: cache,
          purifier: const ContentPurifier(
            rules: _FixedPurgeRules(<PurgeRule>[
              PurgeRule(pattern: '正文第一段。', replacement: 'P1', isRegex: false),
            ]),
          ),
        ).execute(
          _purifyingSource('##正文第二段。##'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(content, 'P1\n\n正文第三段。');
      // 缓存的是净化之后的成品：命中时不能再跑一遍引擎，也就不可能补上净化。
      expect(cache.entries.values.single, content);
    });

    test('execute_givenABrokenPurgeRule_stillReturnsTheChapter', () async {
      // ADR-0026 §决策 2：一条自己写的坏正则不该让整章读不出来。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _serviceAndPrinter(http);

      final String content = _body(
        await FetchContent(
          pages: service.pages,
          cache: FakeContentCache(),
          purifier: ContentPurifier(
            rules: const _FixedPurgeRules(<PurgeRule>[
              PurgeRule(pattern: '(', replacement: '-', isRegex: true),
            ]),
            logger: AppLogger(printer: service.printer),
          ),
        ).execute(_source(), const ChapterRequest(url: _chapterUrl)),
      );

      expect(content, '正文第一段。\n正文第二段。\n正文第三段。');
      expect(service.printer.events, isNotEmpty);
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

        final String content = _body(
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

    test('execute_givenWebJs_readsTheRenderedPageAndPurifiesIt', () async {
      // ADR-0068 §决策 7：正文页由 WebView 渲染后，脚本的结果才是规则的输入。
      final FakeHttpClient http = FakeHttpClient();
      final _FakeWebPages web = _FakeWebPages();
      final PageFetchService pages = _service(http, null, web);
      final BookSource source = _source().copyWith(
        contentRule: _source().contentRule.copyWith(
          webJs: 'document.body.innerText',
        ),
      );
      final FakeContentCache cache = FakeContentCache();

      final ParseResult<ChapterContent> result = await FetchContent(
        pages: pages,
        cache: cache,
      ).execute(source, const ChapterRequest(url: _chapterUrl));

      expect(_content(result).body, '渲染后的正文');
      expect(_content(result).title, isNull);
      expect(web.scripts.single, 'document.body.innerText');
      // 渲染路径不发明请求：普通 HTTP 一次都没发。
      expect(http.requestedUrls, isEmpty);
      // 成品同样进缓存（与普通读取一条语义）。
      expect(cache.writes, hasLength(1));
    });

    test('execute_givenWebJsAndAFailingRenderer_mapsTheFailure', () async {
      final _FakeWebPages web = _FakeWebPages()..fail = true;
      final PageFetchService pages = _service(FakeHttpClient(), null, web);
      final BookSource source = _source().copyWith(
        contentRule: _source().contentRule.copyWith(webJs: 'document.title'),
      );

      final ParseResult<ChapterContent> result = await FetchContent(
        pages: pages,
        cache: FakeContentCache(),
      ).execute(source, const ChapterRequest(url: _chapterUrl));

      expect(_failure(result).kind, ParseFailureKind.unsupportedRule);
    });

    test(
      'execute_givenWebJsAndAContentRuleThatMisses_failsWithItsPath',
      () async {
        // 渲染成功但正文规则没命中：失败必须指向 `contentRule.content`，不是 webJs。
        final _FakeWebPages web = _FakeWebPages()
          ..body = '<div>没有任何可提取的节点</div>';
        final PageFetchService pages = _service(FakeHttpClient(), null, web);
        final BookSource source = _source().copyWith(
          contentRule: _source().contentRule.copyWith(webJs: 'document.title'),
        );

        final ParseResult<ChapterContent> result = await FetchContent(
          pages: pages,
          cache: FakeContentCache(),
        ).execute(source, const ChapterRequest(url: _chapterUrl));

        expect(_failure(result).rulePath, 'contentRule.content');
      },
    );

    test('execute_givenWebJsWithoutAWebView_failsAsUnsupportedRule', () async {
      final PageFetchService pages = _service(
        FakeHttpClient(),
        null,
        const UnsupportedWebPageFetcher(),
      );
      final BookSource source = _source().copyWith(
        contentRule: _source().contentRule.copyWith(webJs: 'document.title'),
      );

      final ParseResult<ChapterContent> result = await FetchContent(
        pages: pages,
        cache: FakeContentCache(),
      ).execute(source, const ChapterRequest(url: _chapterUrl));

      expect(_failure(result).kind, ParseFailureKind.unsupportedRule);
      expect(_failure(result).rulePath, 'contentRule.webJs');
    });
  });

  // ── M25/S2：副文与正文页标题（ADR-0078） ────────────────────────────────────
  group('FetchContent S2 fields', () {
    /// A chapter page that also carries a sub-content block, a title block and a lyric page link.
    const String richPage =
        '<html><body data-lyric="https://example-novel.test/lyric/1.html">'
        '<div id="content">正文第一段。<br>正文第二段。</div>'
        '<div id="sub">副文：作者的话。</div>'
        '<div id="lyric">[00:01] 歌词一行</div>'
        '<div id="title">第1章 开端'
        '<img src="https://example-novel.test/review.jpg"/></div>'
        '</body></html>';

    BookSource contentSource({
      String? subContent,
      String? title,
      String? replaceRegex,
      BookSourceType type = BookSourceType.text,
    }) {
      final BookSource source = _source();

      return source.copyWith(
        sourceType: type,
        contentRule: source.contentRule.copyWith(
          subContent: subContent,
          title: title,
          replaceRegex: replaceRegex,
        ),
      );
    }

    test('execute_givenASubContentRule_appendsItToTheBody', () async {
      // B1（文本源）：上游 `appendContent(subContent)`，与分页拼接同一形状。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, richPage);

      final ChapterContent content = _content(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(
          contentSource(subContent: 'id.sub@text'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(content.body, '正文第一段。\n正文第二段。\n副文：作者的话。');
      expect(content.lyric, isNull);
    });

    test('execute_givenAnAudioSource_keepsTheSubContentAsLyrics', () async {
      // E1（音频源）：`subContent` 是歌词，**不**并进正文（上游写成章节变量 `lyric`）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, richPage);

      final ChapterContent content = _content(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(
          contentSource(
            subContent: 'id.lyric@text',
            type: BookSourceType.audio,
          ),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(content.body, '正文第一段。\n正文第二段。');
      expect(content.lyric, '[00:01] 歌词一行');
    });

    test('execute_givenASubContentThatIsAnUrl_readsThatPageInstead', () async {
      // 上游把 http(s) 开头的值交给 `AnalyzeUrl(...).body`（BookContent.kt:146-156）。
      const String lyricUrl = 'https://example-novel.test/lyric/1.html';
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, richPage)
        ..serve(lyricUrl, '<html><body><p>另一页的歌词</p></body></html>');

      final ChapterContent content = _content(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(
          contentSource(
            subContent: '@css:body@data-lyric',
            type: BookSourceType.audio,
          ),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(http.requestedUrls, contains(lyricUrl));
      expect(content.body, '正文第一段。\n正文第二段。');
      // 与上游一致：取到的是那一页的**正文原文**（`res.body`），不是抽出来的文本。
      expect(content.lyric, '<html><body><p>另一页的歌词</p></body></html>');
    });

    test('execute_givenASubContentUrlThatCannotBeRead_keepsTheBody', () async {
      // 副文页取不到只是「没有歌词」，正文仍然可用（不把整章判失败）。
      const String lyricUrl = 'https://example-novel.test/lyric/1.html';
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, richPage)
        ..failWith(lyricUrl, ParseFailureKind.networkTimeout);
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _serviceAndPrinter(http);

      final ChapterContent content = _content(
        await FetchContent(
          pages: service.pages,
          cache: FakeContentCache(),
        ).execute(
          contentSource(
            subContent: '@css:body@data-lyric',
            type: BookSourceType.audio,
          ),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(content.body, isNotEmpty);
      expect(content.lyric, isNull);
      expect(
        service.printer.events.map(
          (LogEvent event) => event.message.toString(),
        ),
        anyElement(contains('Sub-content page could not be read')),
      );
    });

    test('execute_givenATitleRule_renamesTheChapterAndKeepsTheImage', () async {
      // B2：正文页的标题（`title`）可能带一张 reviewImg（上游 `AppPattern.imgRegex`）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, richPage);

      final ChapterContent content = _content(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(
          // `@html` 取元素本身（含 `<img>`）：上游靠 `AppPattern.imgRegex` 从**值里**捞 reviewImg。
          contentSource(title: 'id.title@html'),
          const ChapterRequest(url: _chapterUrl, title: '第1章'),
        ),
      );

      expect(content.title, '第1章 开端');
      expect(content.reviewImg, 'https://example-novel.test/review.jpg');
    });

    test('execute_givenATitleThatIsOnlyAnImage_keepsTheTocName', () async {
      // 只剩一张图时标题回落成目录里的名字（上游 `if (group1 != "") ... else bookChapter.title`）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '<html><body><div id="content">正文</div>'
          '<div id="title"><img src="https://example-novel.test/x.jpg"/></div>'
          '</body></html>',
        );

      final ChapterContent content = _content(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(
          contentSource(title: 'id.title@html'),
          const ChapterRequest(url: _chapterUrl, title: '目录里的名字'),
        ),
      );

      expect(content.title, '目录里的名字');
      expect(content.reviewImg, 'https://example-novel.test/x.jpg');
    });

    test('execute_givenReplaceRegex_itSeesTheSubContentToo', () async {
      // 顺序照抄上游：`content` → `subContent` → `title` → `replaceRegex`
      // （BookContent.kt:144-196），所以替换规则必须看得到副文。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, richPage);

      final ChapterContent content = _content(
        await FetchContent(
          pages: _service(http),
          cache: FakeContentCache(),
        ).execute(
          contentSource(subContent: 'id.sub@text', replaceRegex: '##副文：##旁白：'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(content.body, contains('旁白：作者的话。'));
    });

    test('execute_givenASecondRead_answersTheSameTitleAndLyrics', () async {
      // 缓存存的是整个结果：命中的那一章也要有正文页标题与歌词，否则第二次进同一章会「变回」目录名。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, richPage);
      final FakeContentCache cache = FakeContentCache();
      final BookSource source = contentSource(
        subContent: 'id.lyric@text',
        title: 'id.title@text',
        type: BookSourceType.audio,
      );
      final FetchContent useCase = FetchContent(
        pages: _service(http),
        cache: cache,
      );

      final ChapterContent first = _content(
        await useCase.execute(source, const ChapterRequest(url: _chapterUrl)),
      );
      final ChapterContent second = _content(
        await useCase.execute(source, const ChapterRequest(url: _chapterUrl)),
      );

      expect(http.requestedUrls, <String>[_chapterUrl]);
      expect(second.title, first.title);
      expect(second.lyric, first.lyric);
      expect(second.body, first.body);
    });
  });
}

/// A [PurgeRuleSource] answering a fixed list (the rules feature owns the real one).
final class _FixedPurgeRules implements PurgeRuleSource {
  const _FixedPurgeRules(this._rules);

  final List<PurgeRule> _rules;

  @override
  Future<List<PurgeRule>> purgeRules() async => _rules;
}
