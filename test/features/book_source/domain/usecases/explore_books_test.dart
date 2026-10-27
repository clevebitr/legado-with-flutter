import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/explore_books.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// The discover page a category URL opens.
const String _categoryUrl = 'https://example-novel.test/list/1.html';

/// A discover page whose items match [listClass].
String _page(String listClass) =>
    '<ul class="$listClass"><li class="item">'
    '<a class="title" href="/book/1/">书名一</a></li></ul>';

/// Builds the service under test around [http].
({PageFetchService pages, FakeLogPrinter printer}) _service(
  FakeHttpClient http,
) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);

  return (
    pages: PageFetchService(
      engine: RuleEngine(
        logger: logger,
        jsBridge: FakeJsBridge(),
        variables: JsVariableStore(),
      ),
      http: http,
      logger: logger,
    ),
    printer: printer,
  );
}

/// A source whose search rule reads `class.search-list` items.
BookSource _source({ExploreRule? exploreRule}) => BookSource(
  name: '示例源',
  url: 'https://example-novel.test',
  searchRule: const SearchRule(
    bookList: 'class.search-list@tag.li',
    name: 'class.title@text',
    bookUrl: 'class.title@href',
  ),
  exploreRule: exploreRule,
  tocRule: const TocRule(chapterList: 'dd'),
  contentRule: const ContentRule(content: 'div'),
);

/// Returns the data of [result], failing the test when it failed.
List<Book> _data(ParseResult<List<Book>> result) => switch (result) {
  ParseSuccess<List<Book>>(:final List<Book> data) => data,
  ParseFailure<List<Book>>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

/// Returns the failure of [result], failing the test when it succeeded.
ParseFailure<Never> _failure(ParseResult<List<Book>> result) =>
    switch (result) {
      ParseFailure<List<Book>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        ParseFailure<Never>(kind: kind, rulePath: rulePath),
      ParseSuccess<List<Book>>() => fail('Expected a failure.'),
    };

void main() {
  group('ExploreBooks', () {
    test('execute_givenAnExploreRule_readsThePageWithItsOwnFields', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_categoryUrl, _page('explore-list'));
      final BookSource source = _source(
        exploreRule: const ExploreRule(
          bookList: 'class.explore-list@tag.li',
          name: 'class.title@text',
          bookUrl: 'class.title@href',
        ),
      );

      final List<Book> books = _data(
        await ExploreBooks(pages: _service(http).pages).execute(
          source,
          const ExploreCategory(title: '玄幻', url: _categoryUrl),
        ),
      );

      expect(http.requestedUrls, <String>[_categoryUrl]);
      expect(books.single.name, '书名一');
      expect(books.single.url, 'https://example-novel.test/book/1/');
    });

    test('execute_givenNoExploreRule_fallsBackToTheWholeSearchRule', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_categoryUrl, _page('search-list'));

      // `ruleExplore` 缺失 → 整条回落 searchRule（ADR-0035 §决策 2）。
      final List<Book> books = _data(
        await ExploreBooks(pages: _service(http).pages).execute(
          _source(),
          const ExploreCategory(title: '玄幻', url: _categoryUrl),
        ),
      );

      expect(books.single.name, '书名一');
    });

    test('execute_givenABlankExploreBookList_fallsBackToo', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_categoryUrl, _page('search-list'));

      final List<Book> books = _data(
        await ExploreBooks(pages: _service(http).pages).execute(
          _source(exploreRule: const ExploreRule(bookList: '   ')),
          const ExploreCategory(title: '玄幻', url: _categoryUrl),
        ),
      );

      expect(books.single.name, '书名一');
    });

    test('execute_givenBothRuleSets_usesOnlyTheExploreOne', () async {
      // 同一页同时能被两套规则读到：胜出的一方整条生效，不逐字段混用。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _categoryUrl,
          '<ul class="search-list"><li class="item">'
          '<a class="title" href="/book/1/">搜索项</a></li></ul>'
          '<ul class="explore-list"><li class="item">'
          '<a class="title" href="/book/2/">发现项</a></li></ul>',
        );
      final BookSource source = _source(
        exploreRule: const ExploreRule(
          bookList: 'class.explore-list@tag.li',
          name: 'class.title@text',
          bookUrl: 'class.title@href',
        ),
      );

      final List<Book> books = _data(
        await ExploreBooks(pages: _service(http).pages).execute(
          source,
          const ExploreCategory(title: '玄幻', url: _categoryUrl),
        ),
      );

      expect(books.single.name, '发现项');
    });

    test('execute_givenAPageTemplateInTheCategoryUrl_rendersThePage', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://example-novel.test/list/2.html',
          _page('explore-list'),
        );
      final BookSource source = _source(
        exploreRule: const ExploreRule(
          bookList: 'class.explore-list@tag.li',
          name: 'class.title@text',
          bookUrl: 'class.title@href',
        ),
      );

      await ExploreBooks(pages: _service(http).pages).execute(
        source,
        const ExploreCategory(title: '玄幻', url: '/list/{{page}}.html'),
        page: 2,
      );

      // 条目 URL 与 searchUrl 共用 renderUrl（C-SRC-5）：`{{page}}` 是模板变量。
      expect(http.requestedUrls, <String>[
        'https://example-novel.test/list/2.html',
      ]);
    });

    test(
      'execute_givenARuleHeadInTheCategoryUrl_returnsUnsupportedRule',
      () async {
        final FakeHttpClient http = FakeHttpClient();
        final BookSource source = _source();

        final ParseFailure<Never> failure = _failure(
          await ExploreBooks(pages: _service(http).pages).execute(
            source,
            const ExploreCategory(
              title: '玄幻',
              url: 'https://example-novel.test/{{@@class.a@text}}',
            ),
          ),
        );

        // §4 的 URL 边界：搜索 / 发现 URL 里的 `{{…}}` 只允许 JS。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@@');
        expect(http.requestedUrls, isEmpty);
      },
    );

    test('execute_givenAnItemWithoutAUrl_skipsItAndWarns', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _categoryUrl,
          '<ul class="explore-list"><li class="item">'
          '<a class="title">没有链接</a></li></ul>',
        );
      final BookSource source = _source(
        exploreRule: const ExploreRule(
          bookList: 'class.explore-list@tag.li',
          name: 'class.title@text',
          bookUrl: 'class.title@href',
        ),
      );
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);

      final List<Book> books = _data(
        await ExploreBooks(pages: service.pages).execute(
          source,
          const ExploreCategory(title: '玄幻', url: _categoryUrl),
        ),
      );

      expect(books, isEmpty);
      expect(
        service.printer.events.map(
          (LogEvent event) => event.message.toString(),
        ),
        contains(contains('Explore item without URL skipped')),
      );
    });

    test(
      'execute_givenARejectedExploreListRule_propagatesTheFailure',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_categoryUrl, _page('explore-list'));
        final BookSource source = _source(
          exploreRule: const ExploreRule(bookList: '@webJs:'),
        );

        final ParseFailure<Never> failure = _failure(
          await ExploreBooks(pages: _service(http).pages).execute(
            source,
            const ExploreCategory(title: '玄幻', url: _categoryUrl),
          ),
        );

        // 顶层列表规则被拒仍整次失败（C-SRC-4 / §7）。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@webJs');
      },
    );

    test('execute_givenAFailingCategoryPage_returnsTheFetchFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_categoryUrl, ParseFailureKind.notFound);

      final ParseFailure<Never> failure = _failure(
        await ExploreBooks(pages: _service(http).pages).execute(
          _source(),
          const ExploreCategory(title: '玄幻', url: _categoryUrl),
        ),
      );

      // 单页失败只影响该分类（§9）：失败带字段路径回去，由调用方（分类 UI）展示。
      expect(failure.kind, ParseFailureKind.notFound);
      expect(failure.rulePath, 'exploreUrl');
    });
    test('execute_givenASectionHeader_touchesNoNetwork', () async {
      // 分组标题没有地址（`url == null`）：既不是请求也不是失败，页面拿空列表（ADR-0069）。
      final FakeHttpClient http = FakeHttpClient();
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);

      final List<Book> books = _data(
        await ExploreBooks(pages: service.pages)
            .execute(_source(), const ExploreCategory(title: '══ 推荐 ══')),
      );

      expect(books, isEmpty);
      expect(http.requestedUrls, isEmpty);
    });
  });
}
