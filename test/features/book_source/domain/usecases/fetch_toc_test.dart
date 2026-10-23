import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// The real default-rule source of the offline corpus.
const String _sourceFixture =
    'test/fixtures/book_sources/legado_default_rules_source.json';

/// The book URL that carries the chapter list in the corpus.
const String _tocUrl = 'https://example-novel.test/book/1/';

/// The second and third table-of-contents pages used by the paging tests.
const String _toc2Url = 'https://example-novel.test/book/1/toc2.html';
const String _toc3Url = 'https://example-novel.test/book/1/toc3.html';

/// The next-link rule the paging tests install, pointing at `<a id="next">`.
const String _nextRule = '@css:a#next @href';

/// Loads the corpus book source.
BookSource _source() => BookSource.fromLegadoJson(
  jsonDecode(File(_sourceFixture).readAsStringSync()) as Map<String, Object?>,
);

/// Reads one page of the offline corpus.
String _page(String name) =>
    File('test/fixtures/html/$name').readAsStringSync();

/// The corpus source with [rule] installed as its `nextTocUrl` (PLAN 3.5).
BookSource _pagingSource(String rule) {
  final BookSource source = _source();

  return source.copyWith(tocRule: source.tocRule.copyWith(nextTocUrl: rule));
}

/// A table-of-contents page with one `<dd>` per entry of [names].
///
/// Each link's URL is `[prefix]<n>.html`, so a test can tell which page a chapter was
/// read from and can watch a relative URL resolve against **that** page (C-SRC-5).
String _tocHtml(List<String> names, {String? nextHref, String prefix = 'c'}) {
  final String links = <String>[
    for (var index = 0; index < names.length; index++)
      '<dd><a href="$prefix${index + 1}.html">${names[index]}</a></dd>',
  ].join();
  final String next = nextHref == null
      ? ''
      : '<a id="next" href="$nextHref">下一页</a>';

  return '<div id="list"><dl>$links</dl></div>$next';
}

/// Builds the page service under test around [http].
///
/// [jsBridge] / [variables] are injectable so a test can share one variable store between
/// the engine and the bridge, which is how matrix #17's `java.put` reaches `@get:`
/// (ADR-0034 §决策 1).
({PageFetchService pages, FakeLogPrinter printer}) _service(
  FakeHttpClient http, {
  FakeJsBridge? jsBridge,
  JsVariableStore? variables,
}) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);

  return (
    pages: PageFetchService(
      engine: RuleEngine(
        logger: logger,
        jsBridge: jsBridge ?? FakeJsBridge(),
        variables: variables ?? JsVariableStore(),
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
  group('FetchToc', () {
    test('execute_givenAChapterUrlRule_exposesTheBookBinding', () async {
      // ADR-0055 P2：`book.tocUrl` / `book.name` 在目录阶段可读（书源用它拼章节地址）。
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = 'https://example-novel.test/c9.html';
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_tocUrl, _page('book_page.html'));
      final BookSource source = _source().copyWith(
        tocRule: _source().tocRule.copyWith(chapterUrl: '@js:book.tocUrl'),
      );

      await FetchToc(pages: _service(http, jsBridge: bridge).pages).execute(
        source,
        _tocUrl,
        bookName: '剑来',
        bookUrl: 'https://example-novel.test/book/1/',
      );

      expect(bridge.jobs.first.book?.name, '剑来');
      expect(bridge.jobs.first.book?.tocUrl, _tocUrl);
      expect(
        bridge.jobs.first.book?.bookUrl,
        'https://example-novel.test/book/1/',
      );
    });

    test('execute_givenAChapterUrlWithOptions_keepsThemVerbatim', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _tocUrl,
          '<div id="list"><dl><dd>'
          '<a href="/1.html,{webView:“true”}">第1章</a>'
          '</dd></dl></div>',
        );

      final List<Chapter> chapters = _data(
        await FetchToc(pages: _service(http).pages).execute(_source(), _tocUrl),
      );

      // 选项留在 URL 原文里，由取页时切掉；现在绝对化会把 `{` 编码成 `%7B`。
      expect(
        chapters.single.url,
        'https://example-novel.test/1.html,{webView:“true”}',
      );
    });

    test('execute_givenTocPage_returnsEveryChapterWithAbsoluteUrls', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_tocUrl, _page('book_page.html'));

      final List<Chapter> chapters = _data(
        await FetchToc(pages: _service(http).pages).execute(_source(), _tocUrl),
      );

      expect(http.requestedUrls, <String>[_tocUrl]);
      expect(http.requestedRulePaths, <String>['ruleToc']);
      expect(chapters, hasLength(3));
      expect(chapters.first.name, '第1章 开端');
      expect(chapters.first.url, 'https://example-novel.test/book/1/1.html');
      expect(chapters.last.url, 'https://example-novel.test/book/1/3.html');
    });

    test('execute_givenHttpFailure_returnsTheSameFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_tocUrl, ParseFailureKind.networkFailed);

      final ParseFailure<Never> failure = _failure(
        await FetchToc(pages: _service(http).pages).execute(_source(), _tocUrl),
      );

      expect(failure.kind, ParseFailureKind.networkFailed);
      expect(failure.rulePath, 'ruleToc');
    });

    test('execute_givenPageWithoutChapterList_returnsParseFailed', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_tocUrl, '<html><body><div id="other"></div></body></html>');

      final ParseFailure<Never> failure = _failure(
        await FetchToc(pages: _service(http).pages).execute(_source(), _tocUrl),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'tocRule.chapterList');
    });

    test('execute_givenChapterWithoutUrl_skipsItAndWarns', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _tocUrl,
          '<div id="list"><dl>'
          '<dd><a href="/book/1/1.html">第1章</a></dd>'
          '<dd><a>没有链接</a></dd>'
          '</dl></div>',
        );
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http);

      final List<Chapter> chapters = _data(
        await FetchToc(pages: service.pages).execute(_source(), _tocUrl),
      );

      expect(chapters, hasLength(1));
      expect(chapters.single.name, '第1章');
      expect(service.printer.events, hasLength(1));
    });

    test(
      'execute_givenUnsupportedFieldRule_degradesToEmptyWithAWarning',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_tocUrl, _page('book_page.html'));
        final BookSource source = _source();
        final BookSource withJs = source.copyWith(
          tocRule: source.tocRule.copyWith(chapterName: '@xpath://div'),
        );
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);

        final ParseResult<List<Chapter>> result = await FetchToc(
          pages: service.pages,
        ).execute(withJs, _tocUrl);

        // ADR-0026 §决策 2：非顶层字段被拒 → 章节名回落为空串，目录照常返回。
        expect(result.dataOrNull, isNotEmpty);
        expect(result.dataOrNull?.first.name, isEmpty);
        expect(
          service.printer.events.last.message.toString(),
          allOf(contains('tocRule.chapterName'), contains(source.url)),
        );
      },
    );

    test('execute_givenIsVipRule_marksOnlyTheTrueishChapters', () async {
      // 判定逐字对齐上游 `String?.isTrue()`（BookChapterList.kt:261-264 调用，
      // StringExtensions.kt:75-80 谓词）：`null` / 全空白 / 字面量 `null` → 非 VIP；
      // 其余值除非匹配 `(?i)^(?:false|no|not|0|0.0)$`，否则算 VIP。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _tocUrl,
          '<div id="list"><dl>'
          '<dd><a href="1.html">第1章</a><em>true</em></dd>'
          '<dd><a href="2.html">第2章</a><em>1</em></dd>'
          '<dd><a href="3.html">第3章</a><em>是</em></dd>'
          '<dd><a href="4.html">第4章</a><em>yes</em></dd>'
          '<dd><a href="5.html">第5章</a><em>false</em></dd>'
          '<dd><a href="6.html">第6章</a><em>FALSE</em></dd>'
          '<dd><a href="7.html">第7章</a><em>no</em></dd>'
          '<dd><a href="8.html">第8章</a><em>not</em></dd>'
          '<dd><a href="9.html">第9章</a><em>0</em></dd>'
          '<dd><a href="10.html">第10章</a><em>0.0</em></dd>'
          '<dd><a href="11.html">第11章</a><em>null</em></dd>'
          '<dd><a href="12.html">第12章</a><em></em></dd>'
          '</dl></div>',
        );
      final BookSource source = _source();
      final BookSource withVip = source.copyWith(
        tocRule: source.tocRule.copyWith(isVip: '@css:em @text'),
      );

      final List<Chapter> chapters = _data(
        await FetchToc(pages: _service(http).pages).execute(withVip, _tocUrl),
      );

      expect(chapters, hasLength(12));
      expect(chapters.map((Chapter chapter) => chapter.isVip), <bool>[
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
      ]);
    });

    test('execute_givenNextTocUrl_pagesThroughEveryTocPage', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_tocUrl, _tocHtml(<String>['第1章'], nextHref: 'toc2.html'))
        ..serve(
          _toc2Url,
          _tocHtml(<String>['第2章'], nextHref: 'toc3.html', prefix: 'p2-'),
        )
        ..serve(_toc3Url, _tocHtml(<String>['第3章'], prefix: 'p3-'));

      final List<Chapter> chapters = _data(
        await FetchToc(pages: _service(http).pages)
            .execute(_pagingSource(_nextRule), _tocUrl),
      );

      expect(http.requestedUrls, <String>[_tocUrl, _toc2Url, _toc3Url]);
      expect(chapters.map((Chapter chapter) => chapter.name), <String>[
        '第1章',
        '第2章',
        '第3章',
      ]);
      // 相对地址仍按**读到它的那一页**解析（C-SRC-5）。
      expect(chapters.map((Chapter chapter) => chapter.url), <String>[
        'https://example-novel.test/book/1/c1.html',
        'https://example-novel.test/book/1/p2-1.html',
        'https://example-novel.test/book/1/p3-1.html',
      ]);
    });

    test('execute_givenSeveralNextTocUrls_readsEachOfThem', () async {
      // `book-source.md` §4.1：`nextTocUrl` 可以是单个 URL，也可以是 URL 数组。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _tocUrl,
          '${_tocHtml(<String>['第1章'])}'
          '<a class="page" href="toc2.html">2</a>'
          '<a class="page" href="toc3.html">3</a>',
        )
        ..serve(_toc2Url, _tocHtml(<String>['第2章']))
        ..serve(_toc3Url, _tocHtml(<String>['第3章']));

      final List<Chapter> chapters = _data(
        await FetchToc(pages: _service(http).pages)
            .execute(_pagingSource('@css:a.page @href'), _tocUrl),
      );

      expect(http.requestedUrls, <String>[_tocUrl, _toc2Url, _toc3Url]);
      expect(chapters.map((Chapter chapter) => chapter.name), <String>[
        '第1章',
        '第2章',
        '第3章',
      ]);
    });

    test(
      'execute_givenNextTocUrlPointingBack_stopsInsteadOfRereading',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_tocUrl, _tocHtml(<String>['第1章'], nextHref: 'toc2.html'))
          ..serve(_toc2Url, _tocHtml(<String>['第2章'], nextHref: '../1/'))
          ..serve(_toc3Url, _tocHtml(<String>['第3章']));

        final List<Chapter> chapters = _data(
          await FetchToc(pages: _service(http).pages)
              .execute(_pagingSource(_nextRule), _tocUrl),
        );

        // 第二页的「下一页」指回首章目录页：已读过的页不再重读，也不会无限翻页。
        expect(http.requestedUrls, <String>[_tocUrl, _toc2Url]);
        expect(chapters, hasLength(2));
      },
    );

    test(
      'execute_givenMorePagesThanTheBound_stopsAtTheBoundWithAWarning',
      () async {
        const String base = 'https://example-novel.test/book/9/';
        final FakeHttpClient http = FakeHttpClient();
        for (var page = 1; page <= 51; page++) {
          http.serve(
            '$base$page.html',
            _tocHtml(<String>[
              '第$page章',
            ], nextHref: page < 51 ? '${page + 1}.html' : null),
          );
        }
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);

        final List<Chapter> chapters = _data(
          await FetchToc(pages: service.pages)
              .execute(_pagingSource(_nextRule), '${base}1.html'),
        );

        // §9：翻页最多 50 页，到顶后停止并记录 warning。
        expect(http.requestedUrls, hasLength(50));
        expect(chapters, hasLength(50));
        expect(service.printer.events, hasLength(1));
        expect(
          service.printer.events.single.message.toString(),
          contains('50 pages'),
        );
      },
    );

    test(
      'execute_givenALaterTocPageFails_returnsTheChaptersReadSoFar',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_tocUrl, _tocHtml(<String>['第1章'], nextHref: 'toc2.html'))
          ..failWith(_toc2Url, ParseFailureKind.networkFailed);
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);

        final List<Chapter> chapters = _data(
          await FetchToc(pages: service.pages)
              .execute(_pagingSource(_nextRule), _tocUrl),
        );

        // §9 目录缺页：已读到的章节照常返回，只记录 warning（整次失败只留给首页）。
        expect(chapters, hasLength(1));
        expect(chapters.single.name, '第1章');
        expect(
          service.printer.events.single.message.toString(),
          contains('stopped before every page was read'),
        );
      },
    );

    test(
      'execute_givenALaterTocPageWithoutChapters_returnsTheChaptersReadSoFar',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_tocUrl, _tocHtml(<String>['第1章'], nextHref: 'toc2.html'))
          ..serve(_toc2Url, '<html><body><p>没有目录</p></body></html>');
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);

        final List<Chapter> chapters = _data(
          await FetchToc(pages: service.pages)
              .execute(_pagingSource(_nextRule), _tocUrl),
        );

        expect(chapters, hasLength(1));
        expect(
          service.printer.events.single.message.toString(),
          contains('page skipped'),
        );
      },
    );

    test(
      'execute_givenUnsupportedNextTocUrlRule_stopsPagingWithAWarning',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_tocUrl, _tocHtml(<String>['第1章'], nextHref: 'toc2.html'));
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);

        final List<Chapter> chapters = _data(
          await FetchToc(pages: service.pages)
              .execute(_pagingSource('@xpath://div'), _tocUrl),
        );

        // ADR-0026 §决策 2：非顶层字段被拒 → 降级为「没有下一页」+ warning。
        expect(http.requestedUrls, <String>[_tocUrl]);
        expect(chapters, hasLength(1));
        expect(
          service.printer.events.last.message.toString(),
          allOf(contains('tocRule.nextTocUrl'), contains('no next page')),
        );
      },
    );

    test('execute_givenAPageNumberTemplate_pagesThroughIt', () async {
      // §4 的 `{{page}}` 是 M0：模板规则本身没有选择器，整条规则就是下一页地址。
      const String base = 'https://example-novel.test/book/8/';
      final FakeHttpClient http = FakeHttpClient()
        ..serve(base, _tocHtml(<String>['第1章']))
        ..serve('${base}toc_2.html', _tocHtml(<String>['第2章']))
        ..serve('${base}toc_3.html', _tocHtml(<String>['第3章']));

      final List<Chapter> chapters = _data(
        await FetchToc(pages: _service(http).pages)
            .execute(_pagingSource('toc_{{page}}.html'), base),
      );

      // `{{page}}` 自己接链；第 4 页没被 serve（§9 缺页降级，保留已读到的三章）。
      expect(http.requestedUrls, <String>[
        base,
        '${base}toc_2.html',
        '${base}toc_3.html',
        '${base}toc_4.html',
      ]);
      expect(
        http.requestedUrls.any((String url) => url.contains('{{')),
        isFalse,
      );
      expect(chapters.map((Chapter chapter) => chapter.name), <String>[
        '第1章',
        '第2章',
        '第3章',
      ]);
    });

    test('execute_givenAnInnerRuleInTheNextUrl_runsItInTheSandbox', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_tocUrl, _tocHtml(<String>['第1章']))
        ..serve(_toc2Url, _tocHtml(<String>['第2章']));
      final FakeJsBridge jsBridge = FakeJsBridge()..result = 'toc2.html';
      final ({PageFetchService pages, FakeLogPrinter printer}) service =
          _service(http, jsBridge: jsBridge);

      final List<Chapter> chapters = _data(
        await FetchToc(pages: service.pages)
            .execute(_pagingSource('{{result}}'), _tocUrl),
      );

      // 矩阵 #18：`{{…}}` 不再当成未定义变量，而是交给沙箱；结果按读到它的那一页
      // 解析成绝对地址（§4.1）。每读一页都会再跑一次翻页规则，所以 job 不止一个。
      expect(jsBridge.jobs.first.script, 'result');
      expect(http.requestedUrls, <String>[_tocUrl, _toc2Url]);
      expect(chapters.map((Chapter chapter) => chapter.name), <String>[
        '第1章',
        '第2章',
      ]);
    });

    test(
      'execute_givenARuleHeadInTheNextUrlTemplate_evaluatesItAsARule',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_tocUrl, _tocHtml(<String>['第1章']));
        final ({PageFetchService pages, FakeLogPrinter printer}) service =
            _service(http);

        final List<Chapter> chapters = _data(
          await FetchToc(pages: service.pages)
              .execute(_pagingSource('{{@@class.a@text}}'), _tocUrl),
        );

        // 翻页**规则**里的 `{{…}}` 走规则字段那一套（矩阵 #18）：`@@` 让内层按默认规则
        // 求值，匹配不到就是「成功但无值」→ 没有下一页。“URL 模板里的规则头只允许 JS”
        // 那条边界只在 renderUrl 里（搜索 / 发现 URL），由 search_books_test 钉住。
        expect(http.requestedUrls, <String>[_tocUrl]);
        expect(chapters, hasLength(1));
      },
    );
    test('execute_givenAnUpdateTimeRule_carriesItOnTheChapter', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _tocUrl,
          '<div id="list"><dl><dd><a href="c1.html">第1章</a>'
          '<span class="time">2026/10/13 09:05</span></dd></dl></div>',
        );
      final BookSource source = _source();
      final BookSource withUpdateTime = source.copyWith(
        tocRule: source.tocRule.copyWith(updateTime: 'class.time@text'),
      );

      final List<Chapter> chapters = _data(
        await FetchToc(pages: _service(http).pages)
            .execute(withUpdateTime, _tocUrl),
      );

      // 章节侧常见的写法是 `@js:java.timeFormat(...)`（§6），但引擎只把结果当字符串。
      expect(chapters.single.updateTime, '2026/10/13 09:05');
    });

    test(
      'execute_givenASourceWithConcurrentRate_handsItToTheRequestLayer',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_tocUrl, _tocHtml(<String>['第1章']));
        final BookSource source = _source().copyWith(concurrentRate: '3/500');

        await FetchToc(pages: _service(http).pages).execute(source, _tocUrl);

        // 翻页 walk 的每一个请求都吃同一份预算，而声明在第一个请求之前就交了下去。
        expect(http.sourceRates, <String, String?>{source.url: '3/500'});
      },
    );
  });
}
