import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
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

/// Reads one JSON page of the offline corpus.
String _jsonPage(String name) =>
    File('test/fixtures/json/$name').readAsStringSync();

/// Builds the page service under test around [http].
({PageFetchService pages, FakeLogPrinter printer}) _service(
  FakeHttpClient http,
) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);

  return (
    pages: PageFetchService(
      engine: RuleEngine(logger: logger),
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

    test('execute_givenPageWithoutResultItems_returnsParseFailed', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl, '<html><body><p>没有结果</p></body></html>');
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);

      final ParseFailure<Never> failure = _failure(
        await SearchBooks(pages: service.pages).execute(_source(), '剑来'),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
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
          searchRule: source.searchRule.copyWith(name: '@js:result'),
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
        final BookSource withJs = source.copyWith(
          searchRule: source.searchRule.copyWith(bookList: '@js:result'),
        );

        final ParseFailure<Never> failure = _failure(
          await SearchBooks(pages: service.pages).execute(withJs, '剑来'),
        );

        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@js:');
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
        await FetchContent(pages: service.pages)
            .execute(source, chapters.first.url),
      );
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
        await FetchContent(pages: service.pages)
            .execute(source, chapters.first.url),
      );
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
  });
}
