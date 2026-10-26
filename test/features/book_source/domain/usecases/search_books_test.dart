import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../../support/fake_content_cache.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// The real default-rule source of the offline corpus.
const String _sourceFixture =
    'test/fixtures/book_sources/legado_default_rules_source.json';

/// The rendered search URL for the keyword `剑来`, i.e. what the chain requests.
const String _searchUrl =
    'https://example-novel.test/search.php?q=%E5%89%91%E6%9D%A5';

/// The book URL the search page points at, already resolved to absolute.
const String _bookUrl = 'https://example-novel.test/book/1/';

/// The first chapter URL, already resolved to absolute.
const String _chapterUrl = 'https://example-novel.test/book/1/1.html';

/// The real JSON-API source of the offline corpus (matrix #13).
const String _jsonSourceFixture =
    'test/fixtures/book_sources/legado_json_source.json';

/// The rendered search URL of the JSON source for the keyword `剑来`.
///
/// Written out on purpose: it is the source's real query string, so asserting against
/// the literal is what pins template rendering, keyword encoding and
/// "encode once, never twice" (`book-source.md` §4) on a real rule.
const String _jsonSearchUrl =
    'https://example-novel.test/api/bookapp/searchdzh.m?word=%E5%89%91%E6%9D%A5'
    '&type=0&page_id=1&count=20&sort_type=0&subclass=0&datasource=0&showj=1&wc=0'
    '&catalog=0&bookStatus=0&cid=eef_easou_book&version=002&os=android'
    '&udid=1FD1EC34C1A1DD11DD61A603B9369449&appverion=1064&ch=blf1298_11982_011'
    '&session_id=-nEua-HnRcZlOf2ovVVOOzJ&lastClock=0&dzh=1&scp=0&appid=10001'
    '&utype=0&rtype=1&pushid=1a0018970afa6c9bc74&ptype=4&birt=1548574906221'
    '&instime=1548574868198';

/// The book URL the JSON search response carries (already absolute).
const String _jsonBookUrl = 'https://example-novel.test/book/1/';

/// The first chapter URL the JSON toc response carries (already absolute).
const String _jsonChapterUrl = 'https://example-novel.test/book/1/1.html';

/// Loads the corpus book source.
BookSource _source() => BookSource.fromLegadoJson(
  jsonDecode(File(_sourceFixture).readAsStringSync()) as Map<String, Object?>,
);

/// Reads one page of the offline corpus.
String _page(String name) =>
    File('test/fixtures/html/$name').readAsStringSync();

/// Loads the JSON corpus book source.
BookSource _jsonSource() => BookSource.fromLegadoJson(
  jsonDecode(File(_jsonSourceFixture).readAsStringSync())
      as Map<String, Object?>,
);

/// The corpus source of the `@js:` value-rule evidence (`docs/dev/roadmap.md` 3.7).
const String _jsSourceFixture =
    'test/fixtures/book_sources/legado_js_rules_source.json';

/// The rendered search URL of the `@js:` corpus source for `剑来`.
const String _jsSearchUrl =
    'https://example-novel.test/dramaapi/search?s=%E5%89%91%E6%9D%A5&p=1';

/// The book URL the `@js:` corpus rule builds for the first corpus item
/// (`$.id@js:'https://example-novel.test/dramaapi/getdrama?drama_id='+result`).
const String _jsBookUrl =
    'https://example-novel.test/dramaapi/getdrama?drama_id=59005';

/// The chapter URL the `@js:` corpus rule builds for the first corpus chapter
/// (`$.sound_id@js:'https://example-novel.test/sound/getsound?soundid='+result`).
const String _jsChapterUrl =
    'https://example-novel.test/sound/getsound?soundid=6810959';

/// Loads the `@js:` corpus book source.
BookSource _jsSource() => BookSource.fromLegadoJson(
  jsonDecode(File(_jsSourceFixture).readAsStringSync()) as Map<String, Object?>,
);

/// Reads one JSON page of the offline corpus.
String _jsonPage(String name) =>
    File('test/fixtures/json/$name').readAsStringSync();

/// Builds the page service under test around [http].
({PageFetchService pages, FakeLogPrinter printer}) _service(
  FakeHttpClient http, {
  JsBridge? jsBridge,
}) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);

  return (
    pages: PageFetchService(
      engine: RuleEngine(
        logger: logger,
        jsBridge: jsBridge ?? FakeJsBridge(),
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
  group('SearchBooks', () {
    test(
      'execute_givenSourceWithoutSearchUrl_returnsInvalidBookSource',
      () async {
        final FakeHttpClient http = FakeHttpClient();
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);
        final BookSource source = _source();
        // `copyWith` 造出「只有发现页、没有搜索」的书源形态。
        final BookSource withoutSearch = source.copyWith(searchUrl: null);

        final ParseFailure<Never> failure = _failure(
          await SearchBooks(pages: service.pages).execute(withoutSearch, '剑来'),
        );

        expect(failure.kind, ParseFailureKind.invalidBookSource);
        expect(failure.rulePath, 'searchUrl');
        expect(http.requestedUrls, isEmpty);
        expect(service.printer.events, hasLength(1));
      },
    );

    test(
      'execute_givenARuleHeadInTheSearchUrl_returnsUnsupportedRule',
      () async {
        final FakeHttpClient http = FakeHttpClient();
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);
        final BookSource source = _source().copyWith(
          searchUrl: 'https://example-novel.test/search?q={{@@class.a@text}}',
        );

        final ParseFailure<Never> failure = _failure(
          await SearchBooks(pages: service.pages).execute(source, '剑来'),
        );

        // §4：搜索 / 发现 URL 里的 `{{…}}` 只允许 JS，规则头按名拒绝（C-SRC-4）——
        // 不得把一个选择器当字面量发到网络。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@@');
        expect(http.requestedUrls, isEmpty);
      },
    );

    test(
      'execute_givenATemplateInTheSearchUrl_rendersTheSandboxValue',
      () async {
        const String jsUrl = 'https://example-novel.test/search-js';
        final FakeHttpClient http = FakeHttpClient()
          ..serve(jsUrl, _page('search_result.html'));
        final FakeJsBridge jsBridge = FakeJsBridge()..result = jsUrl;
        final BookSource source = _source().copyWith(
          searchUrl: '{{java.search()}}',
        );

        final List<Book> books = _data(
          await SearchBooks(pages: _service(http, jsBridge: jsBridge).pages)
              .execute(source, '剑来'),
        );

        // 矩阵 #18：URL 里的 `{{…}}` 是 JS（§4），且关键词以 `key` 绑定交给脚本。
        expect(http.requestedUrls, <String>[jsUrl]);
        expect(jsBridge.jobs.single.script, 'java.search()');
        expect(jsBridge.jobs.single.key, '剑来');
        expect(books, hasLength(2));
      },
    );

    test('execute_givenSearchPage_rendersTheUrlAndReturnsEveryBook', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl, _page('search_result.html'));
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);

      final List<Book> books = _data(
        await SearchBooks(pages: service.pages).execute(_source(), '剑来'),
      );

      // 生产链路真的渲染了模板并编码了关键词（`{{key}}` 只编码一次）。
      expect(http.requestedUrls, <String>[_searchUrl]);
      expect(http.requestedRulePaths, <String>['searchUrl']);
      expect(books, hasLength(2));
      expect(books.first.name, '书名一');
      expect(books.first.url, _bookUrl);
      expect(books.first.author, '作者甲');
      expect(books.first.kind, '玄幻');
      expect(books.first.coverUrl, 'https://example-novel.test/img/1.jpg');
      expect(books.first.lastChapter, '第3章 结尾');
      expect(books.last.name, '书名二');
    });

    test('execute_givenACoverWithUrlOptions_stripsThemWithAWarning', () async {
      // `img@src##$##,{"headers":…}`：地址里不能留 JSON（ADR-0069 G4）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl, _page('search_result.html'));
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);
      final BookSource source = _source();
      final SearchRule rules = source.searchRule.copyWith(
        coverUrl: r'img@src##$##,{"headers":{"Referer":"{{baseUrl}}"}}',
      );

      final List<Book> books = _data(
        await SearchBooks(pages: service.pages)
            .execute(source.copyWith(searchRule: rules), '剑来'),
      );

      expect(books.first.coverUrl, 'https://example-novel.test/img/1.jpg');
      expect(
        service.printer.events.map((LogEvent event) => event.message),
        contains(contains('Cover URL options dropped')),
      );
    });

    test('execute_givenHttpFailure_returnsTheSameFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_searchUrl, ParseFailureKind.networkTimeout);
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);

      final ParseFailure<Never> failure = _failure(
        await SearchBooks(pages: service.pages).execute(_source(), '剑来'),
      );

      expect(failure.kind, ParseFailureKind.networkTimeout);
      expect(failure.rulePath, 'searchUrl');
    });

    test('execute_givenPageWithoutResultItems_answersAnEmptyList', () async {
      // M25/S2 起对齐上游：`bookList` 一条都没命中时不再报 `parseFailed`，而是先按**详情页**再读
      // 一次（BookList.kt:100-110）；详情页也没有书名时结果就是「零条」，不是失败。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl, '<html><body><p>没有结果</p></body></html>');
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);

      final List<Book> books = _data(
        await SearchBooks(pages: service.pages).execute(_source(), '剑来'),
      );

      expect(books, isEmpty);
    });

    test('execute_givenItemWithoutBookUrl_skipsItAndWarns', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _searchUrl,
          '<div class="result-item">'
          '<div class="result-item-title"><a href="/book/1/">有链接</a></div>'
          '</div>'
          '<div class="result-item">'
          '<div class="result-item-title"><a>没有链接</a></div>'
          '</div>',
        );
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);

      final List<Book> books = _data(
        await SearchBooks(pages: service.pages).execute(_source(), '剑来'),
      );

      expect(books, hasLength(1));
      expect(books.single.name, '有链接');
      expect(
        service.printer.events.map((Object event) => event.toString()),
        isNotEmpty,
      );
    });

    test(
      'execute_givenUnsupportedFieldRule_degradesToEmptyWithAWarning',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(
            _searchUrl,
            '<div class="result-item">'
            '<div class="result-item-title"><a href="/book/1/">书名一</a></div>'
            '</div>',
          );
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);
        final BookSource source = _source();
        // ADR-0026 §决策 2：非顶层字段被拒 → 置空 + warning，搜索结果照常返回。
        final BookSource withJs = source.copyWith(
          searchRule: source.searchRule.copyWith(name: '@xpath://div'),
        );

        final ParseResult<List<Book>> result = await SearchBooks(
          pages: service.pages,
        ).execute(withJs, '剑来');

        expect(result.dataOrNull, isNotEmpty);
        expect(result.dataOrNull?.first.name, isEmpty);
        expect(
          service.printer.events.last.message.toString(),
          allOf(contains('searchRule.name'), contains(source.url)),
        );
      },
    );

    test(
      'execute_givenUnsupportedListRule_propagatesUnsupportedRule',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_searchUrl, _page('search_result.html'));
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);
        final BookSource source = _source();
        final BookSource withXpath = source.copyWith(
          searchRule: source.searchRule.copyWith(bookList: '@xpath://div'),
        );

        final ParseFailure<Never> failure = _failure(
          await SearchBooks(pages: service.pages).execute(withXpath, '剑来'),
        );

        expect(failure.kind, ParseFailureKind.unsupportedRule);
        // 顶层列表规则被拒必须整次失败（C-SRC-4），且报的是那条语法本身。
        expect(failure.rulePath, 'unsupported:@xpath:');
      },
    );

    test('chain_givenRealSourceAndCorpusPages_replaysEveryStage', () async {
      // G2：**生产链路**（UseCase → renderUrlTemplate → HttpClient → RuleEngine）
      // 在真实书源上跑通搜索 → 详情 → 目录 → 正文，而不是测试内自建链路。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl, _page('search_result.html'))
        ..serve(_bookUrl, _page('book_page.html'))
        ..serve(_chapterUrl, _page('chapter_page.html'));
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);
      final BookSource source = _source();

      final List<Book> books = _data(
        await SearchBooks(pages: service.pages).execute(source, '剑来'),
      );
      expect(books, isNotEmpty);

      final BookInfo info = _data(
        await FetchBookInfo(pages: service.pages)
            .execute(source, books.first.url),
      );
      expect(info.name, '书名一');
      expect(info.author, '作 者：作者甲');
      // `ruleBookInfo` 没有 `tocUrl` 规则 → 回落到书籍页本身（上游行为）。
      expect(info.tocUrl, _bookUrl);

      final List<Chapter> chapters = _data(
        await FetchToc(pages: service.pages).execute(source, info.tocUrl),
      );
      expect(chapters, hasLength(3));
      expect(chapters.first.name, '第1章 开端');
      expect(chapters.first.url, _chapterUrl);

      final String content = _data(
        await FetchContent(
          pages: service.pages,
          cache: FakeContentCache(),
        ).execute(source, ChapterRequest(url: chapters.first.url)),
      ).body;
      expect(content, '正文第一段。\n正文第二段。\n正文第三段。');

      // 四段请求的地址与规则路径，证明 URL 模板、编码与相对地址解析都走了生产代码。
      expect(http.requestedUrls, <String>[
        _searchUrl,
        _bookUrl,
        _bookUrl,
        _chapterUrl,
      ]);
      expect(http.requestedRulePaths, <String>[
        'searchUrl',
        'ruleBookInfo',
        'ruleToc',
        'ruleContent',
      ]);
    });

    test('chain_givenJsonSourceAndCorpusPages_replaysEveryStage', () async {
      // 矩阵 #13 的同一件事，只是响应体是 JSON：**生产链路**（UseCase →
      // renderUrlTemplate → HttpClient → RuleEngine → RuleScope）在真实 JSON 书源上
      // 跑通搜索 → 详情 → 目录 → 正文。语料的来源与那 2 条 M1 改写见
      // `test/fixtures/json/README.md`。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_jsonSearchUrl, _jsonPage('search.json'))
        ..serve(_jsonBookUrl, _jsonPage('book.json'))
        ..serve(_jsonChapterUrl, _jsonPage('content.json'));
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);
      final BookSource source = _jsonSource();

      final List<Book> books = _data(
        await SearchBooks(pages: service.pages).execute(source, '剑来'),
      );
      // `bookList` 是 `@json:$.all_book_items[*]||@json:$.guess_like_items[*]`：第一个候选
      // 就有值，所以 `guess_like_items` 根本不会被用到，结果只有 1 条。
      expect(books, hasLength(1));
      expect(books.first.name, '书名一');
      expect(books.first.author, '作者甲');
      expect(books.first.kind, '武侠');
      expect(books.first.lastChapter, '第1章 开端');
      expect(books.first.url, _jsonBookUrl);
      // JSON 里的相对封面地址仍按当前页解析成绝对地址（C-SRC-5）。
      expect(books.first.coverUrl, 'https://example-novel.test/cover/1.jpg');

      final BookInfo info = _data(
        await FetchBookInfo(pages: service.pages)
            .execute(source, books.first.url),
      );
      // 嵌套路径 `$.coverInfo.desc`。
      expect(info.intro, '简介一。');
      // `ruleBookInfo` 没有 `tocUrl` 规则 → 回落到书籍页本身（上游行为）。
      expect(info.tocUrl, _jsonBookUrl);

      final List<Chapter> chapters = _data(
        await FetchToc(pages: service.pages).execute(source, info.tocUrl),
      );
      expect(chapters, hasLength(2));
      expect(chapters.first.name, '第1章 开端');
      expect(chapters.first.url, _jsonChapterUrl);
      expect(chapters.last.name, '第2章 转折');

      final String content = _data(
        await FetchContent(
          pages: service.pages,
          cache: FakeContentCache(),
        ).execute(source, ChapterRequest(url: chapters.first.url)),
      ).body;
      // JSON 里的 `\n` 是转义序列，解出来是一个真正的换行。
      expect(content, '正文第一段。\n正文第二段。');

      // 四段请求的地址与规则路径，证明 URL 模板、关键词编码与相对地址解析都走了生产代码。
      expect(http.requestedUrls, <String>[
        _jsonSearchUrl,
        _jsonBookUrl,
        _jsonBookUrl,
        _jsonChapterUrl,
      ]);
      expect(http.requestedRulePaths, <String>[
        'searchUrl',
        'ruleBookInfo',
        'ruleToc',
        'ruleContent',
      ]);
    });

    test(
      'chain_givenJsRulesSourceAndCorpusPages_replaysTheListStages',
      () async {
        // 3.7 的 `@js:` 语料（真实导出：猫耳FM，已脱敏；来源与派生见
        // `test/fixtures/json/README.md`）。搜索与目录两段的两个列表规则就是两块
        // 矩阵 #13 的关键语料：`$.info.Datas` **命中一个列表**（不是 `[*]`）而
        // `&&` 的第一支为空——活站点当天给出的计数是 30 / 34（见 `tool/spot_check/README.md` §4）。
        //
        // `@js:` 段按 `testing.md` §4 用假桥接：这里断言的是「每条脚本拿到的 `result`
        // 是它那一项的 JSON 值」这件事（真引擎的执行已在设备级探针与活站点跑过）。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_jsSearchUrl, _jsonPage('maoer_search.json'))
          ..serve(_jsBookUrl, _jsonPage('maoer_toc.json'));
        final FakeJsBridge bridge = FakeJsBridge()..result = _jsBookUrl;
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http, jsBridge: bridge);
        final BookSource source = _jsSource();

        final List<Book> books = _data(
          await SearchBooks(pages: service.pages).execute(source, '剑来'),
        );

        expect(books, hasLength(30));
        expect(books.first.name, '示例作品1');
        expect(books.first.kind, '示例类型');
        expect(books.first.intro, '<p>示例简介1</p>');
        expect(books.first.lastChapter, '示例最新一集1');
        // 封面是 JSON 里的绝对地址（已脱敏域）。
        expect(
          books.first.coverUrl,
          'https://static.example-novel.test/cover/demo1.jpg',
        );
        // 书址来自 `bookUrl` 的 `@js:`（假桥接的答案）。
        expect(books.first.url, _jsBookUrl);

        // 逐项调用：30 本各一次，且脚本拿到的 `result` 就是那一项的 `id`。
        final List<JsJob> bookUrlJobs = bridge.jobs
            .where((JsJob job) => job.rulePath == 'searchRule.bookUrl')
            .toList();
        expect(bookUrlJobs, hasLength(30));
        expect(
          bookUrlJobs.first.script,
          "'https://example-novel.test/dramaapi/getdrama?drama_id='+result",
        );
        expect(bookUrlJobs.first.result, '59005');

        final BookInfo info = _data(
          await FetchBookInfo(pages: service.pages).execute(source, _jsBookUrl),
        );
        expect(info.name, '示例作品');
        // `author` 在该站点的接口里就是空串：空值不产生值（矩阵 #8 的口径），也不报失败。
        expect(info.author, isNull);
        expect(
          info.coverUrl,
          'https://static.example-novel.test/dramacovers/demo.jpg',
        );

        // `ruleBookInfo` 没有 `tocUrl` → 目录仍然读书籍页本身（上游行为）。
        expect(info.tocUrl, _jsBookUrl);

        bridge.result = _jsChapterUrl;
        final List<Chapter> chapters = _data(
          await FetchToc(pages: service.pages).execute(source, info.tocUrl),
        );

        // `chapterList` = `$.info.episodes.music&&$.info.episodes.episode`：第一支为空数组，
        // 第二支给 34 条——并集就是这 34 条（矩阵 #11 在 JSON 分支上的形态）。
        expect(chapters, hasLength(34));
        expect(chapters.first.name, '示例章节1');
        expect(chapters.first.url, _jsChapterUrl);

        final List<JsJob> chapterUrlJobs = bridge.jobs
            .where((JsJob job) => job.rulePath == 'tocRule.chapterUrl')
            .toList();
        expect(chapterUrlJobs, hasLength(34));
        expect(chapterUrlJobs.first.result, '6810959');

        // 两段的地址与字段路径：URL 模板、关键词编码与逐项 `@js:` 都走了生产代码。
        // 书籍页被取两次：详情与目录读的是同一页（`ruleBookInfo` 没有 `tocUrl`）。
        expect(http.requestedUrls, <String>[
          _jsSearchUrl,
          _jsBookUrl,
          _jsBookUrl,
        ]);
        expect(http.requestedRulePaths, <String>[
          'searchUrl',
          'ruleBookInfo',
          'ruleToc',
        ]);
      },
    );

    test(
      'execute_givenSourceWithHeaders_sendsThemAndTheSourceIdWithTheKeyword',
      () async {
        // 搜索请求同时携带 keyword（ADR-0006 §5 的日志口径），所以它必须单独钉一次：
        // `header`（`book-source.md` §2 的 M0 字段）与书源 ID（ADR-0031 §决策 2 的
        // warning 需要它，C-ERR-8）都要到位。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_searchUrl, _page('search_result.html'));
        final BookSource source = _source().copyWith(
          headers: <String, String>{
            'User-Agent': 'Mozilla/5.0 (browser-like)',
            'Referer': 'https://example-novel.test/',
          },
        );

        _data(
          await SearchBooks(pages: _service(http).pages).execute(source, '剑来'),
        );

        expect(http.requestedUrls, <String>[_searchUrl]);
        expect(http.requestedHeaders.single, <String, String>{
          'User-Agent': 'Mozilla/5.0 (browser-like)',
          'Referer': 'https://example-novel.test/',
        });
        expect(http.requestedSourceIds, <String>[source.url]);
      },
    );
    test('execute_givenAHeaderRule_sendsTheEvaluatedHeaders', () async {
      // M12-A2：`header` 写成规则时，实际发出去的 header 是**求值结果**，不是规则文本。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl, _page('search_result.html'));
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = '{"User-Agent": "from-rule"}';
      final BookSource source = _source().copyWith(
        headerRule: '@js:JSON.stringify({User-Agent:"from-rule"})',
      );

      _data(
        await SearchBooks(pages: _service(http, jsBridge: bridge).pages)
            .execute(source, '剑来'),
      );

      expect(http.requestedHeaders.single, <String, String>{
        'User-Agent': 'from-rule',
      });
      expect(bridge.jobs.first.rulePath, 'header');
    });

    test('execute_givenAnUpdateTimeRule_carriesItOnTheHit', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _searchUrl,
          '<div class="result-list"><div class="result-item">'
          '<div class="result-item-title"><a href="/book/1/">书名一</a></div>'
          '<span class="time">2026/10/13 09:05</span></div></div>',
        );
      final BookSource source = _source();
      final BookSource withUpdateTime = source.copyWith(
        searchRule: source.searchRule.copyWith(updateTime: 'class.time@text'),
      );

      final List<Book> books = _data(
        await SearchBooks(pages: _service(http).pages)
            .execute(withUpdateTime, '剑来'),
      );

      // 展示用字符串：规则结果原文，模型与实体都不做日期解析（book-source.md §2）。
      expect(books.single.updateTime, '2026/10/13 09:05');
    });

    test(
      'execute_givenASourceWithConcurrentRate_handsItToTheRequestLayer',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_searchUrl, _page('search_result.html'));
        final BookSource source = _source().copyWith(concurrentRate: '5/1000');

        await SearchBooks(pages: _service(http).pages).execute(source, '剑来');

        // 书源自己的限速必须进请求层的预算（book-source.md §8、ADR-0036 §决策 5）：
        // 键是书源 URL，所以脚本的 `http.*` 也自动共用同一份限速。
        expect(http.sourceRates, <String, String?>{source.url: '5/1000'});
      },
    );
  });

  // ── M25/S2：bookUrlPattern（ADR-0078 A4） ─────────────────────────────────────
  group('SearchBooks bookUrlPattern', () {
    /// A detail page: `ruleBookInfo` lives on the same document as a search result would.
    const String detailHtml =
        '<div class="book"><h1 class="name">剑来</h1>'
        '<span class="author">烽火戏诸侯</span>'
        '<a class="toc" href="/book/1/">目录</a></div>';

    test('execute_givenASearchUrlThatIsADetailPage_returnsOneBook', () async {
      // 上游 `baseUrl.matches(bookUrlPattern)` 命中就当详情页解析（BookList.kt:62-84）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl, detailHtml);
      final BookSource source = _source().copyWith(
        bookUrlPattern: r'https://example-novel\.test/search\.php.*',
        bookInfoRule: const BookInfoRule(
          name: 'class.name@text',
          author: 'class.author@text',
          tocUrl: 'class.toc@href',
        ),
      );

      final List<Book> books = _data(
        await SearchBooks(pages: _service(http).pages).execute(source, '剑来'),
      );

      expect(books, hasLength(1));
      expect(books.single.name, '剑来');
      expect(books.single.author, '烽火戏诸侯');
      expect(books.single.url, _searchUrl);
    });

    test(
      'execute_givenAnEmptyListAndNoPattern_fallsBackToTheDetailPage',
      () async {
        // 没有 bookUrlPattern 时，`bookList` 一条都没命中也会按详情页再读一次
        // （BookList.kt:100-110）——单书站因此不会显示「搜索失效」。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_searchUrl, detailHtml);
        final BookSource source = _source().copyWith(
          bookInfoRule: const BookInfoRule(
            name: 'class.name@text',
            author: 'class.author@text',
            tocUrl: 'class.toc@href',
          ),
        );

        final List<Book> books = _data(
          await SearchBooks(pages: _service(http).pages).execute(source, '剑来'),
        );

        expect(books.single.name, '剑来');
      },
    );

    test('execute_givenAPatternThatDoesNotMatch_keepsTheListPath', () async {
      // 地址不匹配就不能当详情页：否则「搜索页」会被读成一本错书。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl, _page('search_result.html'));
      final BookSource source = _source().copyWith(
        bookUrlPattern: r'^https://other\.test/.*$',
      );

      final List<Book> books = _data(
        await SearchBooks(pages: _service(http).pages).execute(source, '剑来'),
      );

      expect(books, hasLength(2));
    });

    test('execute_givenAnUnusablePattern_warnsAndKeepsTheListPath', () async {
      // 坏正则不能吃掉整次搜索：记 warning，按普通列表继续。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl, _page('search_result.html'));
      final BookSource source = _source().copyWith(bookUrlPattern: '(');
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);

      final List<Book> books = _data(
        await SearchBooks(pages: service.pages).execute(source, '剑来'),
      );

      expect(books, hasLength(2));
      expect(
        service.printer.events.map(
          (LogEvent event) => event.message.toString(),
        ),
        anyElement(contains('unusable bookUrlPattern')),
      );
    });
  });
}
