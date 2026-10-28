import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_settings.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/check_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/explore_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_explore_categories.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_content_cache.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// The website every case in this file pretends to check.
const String _baseUrl = 'https://check.test';

/// The keyword the cases search with, so the rendered URLs stay readable.
const String _keyword = 'kw';

/// The search page the source is expected to request.
const String _searchUrl = '$_baseUrl/search?q=$_keyword&page=1';

/// The book page, resolved against [_searchUrl] from the search hit's relative href.
const String _bookUrl = '$_baseUrl/book/1/';

/// The table-of-contents page, resolved against [_bookUrl].
const String _tocUrl = '$_baseUrl/book/1/toc/';

/// The first chapter, resolved against [_tocUrl].
const String _chapterUrl = '$_baseUrl/book/1/1.html';

/// The discover-page category the explore cases open.
const String _categoryUrl = '$_baseUrl/explore/xh';

/// Clock a test can pin (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

/// Builds the source under check; every knob changes one rule so a case fails on purpose.
BookSource _source({
  String? searchUrl = '$_baseUrl/search?q={{key}}&page={{page}}',
  String? exploreUrl,
  String searchList = 'class.result',
  String tocList = 'class.chapter',
  String contentRule = 'id.content@text',
  String? checkKeyWord,
  String? nextContentUrl,
}) => BookSource.fromLegadoJson(<String, Object?>{
  'bookSourceName': '校验用例源',
  'bookSourceUrl': _baseUrl,
  'searchUrl': ?searchUrl,
  'exploreUrl': ?exploreUrl,
  'ruleSearch': <String, Object?>{
    'bookList': searchList,
    'name': 'class.title@text',
    'bookUrl': 'tag.a.0@href',
    'checkKeyWord': ?checkKeyWord,
  },
  'ruleBookInfo': <String, Object?>{
    'name': 'class.name@text',
    'tocUrl': 'tag.a.0@href',
  },
  'ruleToc': <String, Object?>{
    'chapterList': tocList,
    'chapterName': 'tag.a@text',
    'chapterUrl': 'tag.a.0@href',
  },
  'ruleContent': <String, Object?>{
    'content': contentRule,
    'nextContentUrl': ?nextContentUrl,
  },
});

/// One search result page.
const String _searchPage =
    '<div class="result"><span class="title">书甲</span>'
    '<a href="/book/1/">详情</a></div>';

/// One book detail page.
const String _bookPage =
    '<h1 class="name">书甲</h1><a href="/book/1/toc/">目录</a>';

/// One table-of-contents page with two chapters.
const String _tocPage =
    '<dl><dd class="chapter"><a href="/book/1/1.html">第1章</a></dd>'
    '<dd class="chapter"><a href="/book/1/2.html">第2章</a></dd></dl>';

/// One chapter body.
const String _contentPage = '<div id="content">正文内容</div>';

/// The results one check produced, plus the client it used.
typedef _Fixture = ({
  CheckBookSource check,
  FakeHttpClient http,
  FakeLogPrinter printer,
});

/// Builds the use case under test around [http].
_Fixture _fixture(FakeHttpClient http, {FakeJsBridge? jsBridge}) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);
  final PageFetchService pages = PageFetchService(
    engine: RuleEngine(
      logger: logger,
      jsBridge: jsBridge ?? FakeJsBridge(),
      variables: JsVariableStore(),
    ),
    http: http,
    logger: logger,
  );

  return (
    check: CheckBookSource(
      searchBooks: SearchBooks(pages: pages),
      exploreCategories: FetchExploreCategories(
        engine: RuleEngine(
          logger: logger,
          jsBridge: jsBridge ?? FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        pages: pages,
      ),
      exploreBooks: ExploreBooks(pages: pages),
      bookInfo: FetchBookInfo(pages: pages),
      toc: FetchToc(pages: pages),
      content: FetchContent(pages: pages, cache: FakeContentCache()),
      clock: _FixedClock(DateTime(2026, 10, 21)),
      logger: logger,
    ),
    http: http,
    printer: printer,
  );
}

/// Returns the report of a successful check, failing the test otherwise.
SourceCheckReport _report(ParseResult<SourceCheckReport> result) =>
    switch (result) {
      ParseSuccess<SourceCheckReport>(:final SourceCheckReport data) => data,
      ParseFailure<SourceCheckReport>(:final ParseFailureKind kind) => fail(
        'Expected a report but got $kind.',
      ),
    };

/// The single stage outcome of [stage] in [report].
SourceCheckStageOutcome _stage(
  SourceCheckReport report,
  SourceCheckStage stage,
) => report.stages.singleWhere(
  (SourceCheckStageOutcome outcome) => outcome.stage == stage,
);

/// Serves the healthy chain, so a case can break exactly one page.
FakeHttpClient _healthy() => FakeHttpClient()
  ..serve(_searchUrl, _searchPage)
  ..serve(_bookUrl, _bookPage)
  ..serve(_tocUrl, _tocPage)
  ..serve(_chapterUrl, _contentPage);

void main() {
  group('CheckBookSource', () {
    test('execute_givenTheNextContentUrlPointsAtTheNextChapter_stopsEarly', () async {
      // 上游 BookSourceCheckRepository.kt:222-230 把目录第 2 章作为 nextChapterUrl 传下去；
      // 正文翻页规则指到它时停止，而不是把整本读成 50 页（一轮日志里 14 个源撞上限）。
      final FakeHttpClient http = _healthy()
        ..serve(
          _chapterUrl,
          '<div id="content">第一页</div>'
          '<a id="next" href="2.html">下一章</a>',
        );
      final _Fixture fixture = _fixture(http);

      _report(
        await fixture.check.execute(
          _source(nextContentUrl: '@css:a#next @href'),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(http.requestedUrls, contains(_chapterUrl));
      expect(http.requestedUrls, isNot(contains('$_baseUrl/book/1/2.html')));
    });

    test('execute_givenAHealthySource_succeedsOnEveryStage', () async {
      final _Fixture fixture = _fixture(_healthy());

      final SourceCheckReport report = _report(
        await fixture.check.execute(
          _source(),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(report.status, SourceCheckStatus.succeeded);
      expect(report.invalidGroups, isEmpty);
      expect(report.errorComment, isNull);
      // 搜索源没有 `exploreUrl`，所以只有四个阶段（发现链不跑）。
      expect(report.stages, hasLength(4));
      for (final SourceCheckStage stage in <SourceCheckStage>[
        SourceCheckStage.search,
        SourceCheckStage.info,
        SourceCheckStage.toc,
        SourceCheckStage.content,
      ]) {
        expect(_stage(report, stage).status, SourceCheckStatus.succeeded);
      }
      // 链路真的按「搜索 → 详情 → 目录 → 正文」走过一遍。
      expect(fixture.http.requestedUrls, <String>[
        _searchUrl,
        _bookUrl,
        _tocUrl,
        _chapterUrl,
      ]);
      expect(fixture.http.requestedRulePaths, <String>[
        'searchUrl',
        'ruleBookInfo',
        'ruleToc',
        'ruleContent',
      ]);
    });

    test('execute_givenItemsWithoutUrls_marksTheSearchInvalid', () async {
      // 列表命中但每一条都读不出书址（逐条跳过）→ 搜索阶段「成功且为空」，仍判无效
      // （`emptyGroup` 分支）。
      final _Fixture fixture = _fixture(
        FakeHttpClient()..serve(
          _searchUrl,
          '<div class="result"><span class="title">书甲</span></div>',
        ),
      );

      final SourceCheckReport report = _report(
        await fixture.check.execute(
          _source(),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(report.invalidGroups, <String>[searchInvalidGroup]);
      expect(
        _stage(report, SourceCheckStage.search).status,
        SourceCheckStatus.failed,
      );
    });

    test('execute_givenAnEmptySearch_marksTheSearchInvalid', () async {
      final _Fixture fixture = _fixture(
        FakeHttpClient()..serve(_searchUrl, '<div id="none"></div>'),
      );

      final SourceCheckReport report = _report(
        await fixture.check.execute(
          _source(),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(report.status, SourceCheckStatus.failed);
      expect(report.invalidGroups, <String>[searchInvalidGroup]);
      expect(report.errorComment, searchInvalidGroup);
      // 没找到书就没有详情阶段可跑。
      expect(report.stages, hasLength(1));
      expect(
        _stage(report, SourceCheckStage.search).failureKind,
        ParseFailureKind.parseFailed,
      );
    });

    test(
      'execute_givenAnEmptyTableOfContents_marksTheSearchTocInvalid',
      () async {
        final FakeHttpClient http = _healthy()
          ..serve(_tocUrl, '<dl><dd class="other">无</dd></dl>');
        final _Fixture fixture = _fixture(http);

        final SourceCheckReport report = _report(
          await fixture.check.execute(
            _source(),
            const SourceCheckSettings(keyword: _keyword),
          ),
        );

        expect(report.invalidGroups, <String>[searchTocInvalidGroup]);
        expect(
          _stage(report, SourceCheckStage.toc).rulePath,
          'tocRule.chapterList',
        );
        // 目录坏了就不再读正文（上游的 runCatching 同样跳过）。
        expect(
          report.stages.map((SourceCheckStageOutcome outcome) => outcome.stage),
          <SourceCheckStage>[
            SourceCheckStage.search,
            SourceCheckStage.info,
            SourceCheckStage.toc,
          ],
        );
      },
    );

    test('execute_givenATocListThatMatchesNothing_invalidatesTheToc', () async {
      // 目录列表规则一条都没命中：`FetchToc` 直接失败，目录阶段判无效。
      // （「命中了但章节没有 URL」不再是无效：那一章会回落到目录页地址，ADR-0069 G8。）
      final FakeHttpClient http = _healthy()
        ..serve(_tocUrl, '<dl><dd><a>第1章</a></dd></dl>');

      final SourceCheckReport report = _report(
        await _fixture(http).check
            .execute(_source(), const SourceCheckSettings(keyword: _keyword)),
      );

      expect(report.invalidGroups, <String>[searchTocInvalidGroup]);
    });

    test('execute_givenAnEmptyBody_marksTheSearchContentInvalid', () async {
      final FakeHttpClient http = _healthy()
        ..serve(_chapterUrl, '<div id="content"></div>');

      final SourceCheckReport report = _report(
        await _fixture(http).check
            .execute(_source(), const SourceCheckSettings(keyword: _keyword)),
      );

      expect(report.invalidGroups, <String>[searchContentInvalidGroup]);
      expect(
        _stage(report, SourceCheckStage.content).failureKind,
        ParseFailureKind.parseFailed,
      );
    });

    test(
      'execute_givenAWhitespaceOnlyBody_marksTheSearchContentInvalid',
      () async {
        // 纯空白按「没读出来」算（与 `PageFetchService.content` 的顶层口径一致）。
        final FakeHttpClient http = _healthy()
          ..serve(_chapterUrl, '<div id="content">   </div>');

        final SourceCheckReport report = _report(
          await _fixture(http).check
              .execute(_source(), const SourceCheckSettings(keyword: _keyword)),
        );

        expect(report.invalidGroups, <String>[searchContentInvalidGroup]);
      },
    );

    test('execute_givenABrokenScript_marksTheSourceJsInvalid', () async {
      // 顶层正文规则不降级（ADR-0026 §决策 1），所以它的脚本失败会留在阶段失败里。
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = const ParseFailure<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'contentRule.content:js:error',
        );
      final _Fixture fixture = _fixture(_healthy(), jsBridge: bridge);

      final SourceCheckReport report = _report(
        await fixture.check.execute(
          _source(contentRule: 'id.content@js:result.trim()'),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(report.invalidGroups, <String>[jsInvalidGroup]);
      expect(
        _stage(report, SourceCheckStage.content).rulePath,
        'contentRule.content:js:error',
      );
    });

    test('execute_givenAReadFailure_marksTheSiteInvalid', () async {
      final FakeHttpClient http = _healthy()
        ..failWith(_bookUrl, ParseFailureKind.networkFailed);

      final SourceCheckReport report = _report(
        await _fixture(http).check
            .execute(_source(), const SourceCheckSettings(keyword: _keyword)),
      );

      expect(report.invalidGroups, <String>[siteInvalidGroup]);
      expect(
        _stage(report, SourceCheckStage.info).status,
        SourceCheckStatus.failed,
      );
      expect(report.stages, hasLength(2));
    });

    test('execute_givenNoBudgetLeft_timesOutBeforeRequesting', () async {
      // 超时是「不再等」：预算为 0 时连第一个请求都不发（ADR-0043 §后果）。
      final FakeHttpClient http = _healthy();

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(),
          const SourceCheckSettings(keyword: _keyword, timeout: Duration.zero),
        ),
      );

      expect(report.invalidGroups, <String>[checkTimeoutGroup]);
      expect(
        _stage(report, SourceCheckStage.search).failureKind,
        ParseFailureKind.networkTimeout,
      );
      expect(http.requestedUrls, isEmpty);
    });

    test('execute_givenARequestThatNeverAnswers_timesOut', () async {
      final FakeHttpClient http = _healthy();
      // 请求挂在半空：`.timeout` 到点就放弃等待，底层请求自己结束（ADR-0043 §后果）。
      http.onRequest = () => Completer<void>().future;

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(),
          const SourceCheckSettings(
            keyword: _keyword,
            timeout: Duration(milliseconds: 10),
          ),
        ),
      );

      expect(report.invalidGroups, <String>[checkTimeoutGroup]);
      expect(
        _stage(report, SourceCheckStage.search).status,
        SourceCheckStatus.failed,
      );
    });

    test('execute_whenCancelledBeforeTheStart_cancelsWithoutAStage', () async {
      final FakeHttpClient http = _healthy();
      final TaskCancellation cancellation = TaskCancellation()..cancel();

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(),
          const SourceCheckSettings(keyword: _keyword),
          cancellation: cancellation,
        ),
      );

      // 取消是 Cancelled 而不是 Failed（上游 Incomplete 口径的反面，ADR-0043 §后果）。
      expect(report.status, SourceCheckStatus.cancelled);
      expect(report.stages, isEmpty);
      expect(report.invalidGroups, isEmpty);
      expect(http.requestedUrls, isEmpty);
    });

    test('execute_givenABlankSearchUrl_marksTheMissingUrlGroup', () async {
      final FakeHttpClient http = _healthy();

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(searchUrl: '   '),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(report.invalidGroups, <String>[searchUrlMissingGroup]);
      expect(report.status, SourceCheckStatus.failed);
      expect(http.requestedUrls, isEmpty);
    });

    test('execute_givenNoStageSwitchedOn_returnsInvalidBookSource', () async {
      final FakeHttpClient http = _healthy();

      final ParseResult<SourceCheckReport> result = await _fixture(http).check
          .execute(
            _source(),
            const SourceCheckSettings(stages: <SourceCheckStage>{}),
          );

      expect(switch (result) {
        ParseFailure<SourceCheckReport>(:final ParseFailureKind kind) => kind,
        ParseSuccess<SourceCheckReport>() => null,
      }, ParseFailureKind.invalidBookSource);
      expect(http.requestedUrls, isEmpty);
    });

    test('execute_givenAnExploreSource_checksTheDiscoverChain', () async {
      final FakeHttpClient http = _healthy()..serve(_categoryUrl, _searchPage);
      final _Fixture fixture = _fixture(http);

      final SourceCheckReport report = _report(
        await fixture.check.execute(
          _source(exploreUrl: '玄幻::$_categoryUrl'),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(report.status, SourceCheckStatus.succeeded);
      // 搜索链与发现链各跑一遍：两个入口 + 各自三个链路阶段。
      expect(report.stages, hasLength(8));
      expect(fixture.http.requestedUrls, contains(_categoryUrl));
    });

    test('execute_givenAnEmptyExploreList_marksTheExploreInvalid', () async {
      final FakeHttpClient http = _healthy()
        ..serve(_categoryUrl, '<div id="none"></div>');

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(exploreUrl: '玄幻::$_categoryUrl'),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(report.invalidGroups, <String>[exploreInvalidGroup]);
    });

    test(
      'execute_givenTheSameBrokenTocOnBothChains_writesBothTokens',
      () async {
        final FakeHttpClient http = _healthy()
          ..serve(_categoryUrl, _searchPage)
          ..serve(
            _bookUrl,
            '<h1 class="name">书甲</h1><a href="/book/1/toc/">目录</a>',
          )
          ..serve(_tocUrl, '<dl><dd class="other">无</dd></dl>');

        final SourceCheckReport report = _report(
          await _fixture(http).check.execute(
            _source(exploreUrl: '玄幻::$_categoryUrl'),
            const SourceCheckSettings(keyword: _keyword),
          ),
        );

        // 同一条目录规则：走搜索链写「搜索目录失效」，走发现链写「发现目录失效」，两条都要在，
        // 否则用户不知道该去修哪一个入口。
        expect(report.invalidGroups, <String>[
          searchTocInvalidGroup,
          exploreTocInvalidGroup,
        ]);
      },
    );

    test('execute_givenNoExploreUrl_skipsTheDiscoverChain', () async {
      final _Fixture fixture = _fixture(_healthy());

      final SourceCheckReport report = _report(
        await fixture.check.execute(
          _source(),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(
        report.stages.map((SourceCheckStageOutcome outcome) => outcome.stage),
        isNot(contains(SourceCheckStage.explore)),
      );
    });

    test('execute_givenTheInfoStageOff_skipsTheBookChain', () async {
      final FakeHttpClient http = _healthy();

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(),
          const SourceCheckSettings(
            keyword: _keyword,
            stages: <SourceCheckStage>{SourceCheckStage.search},
          ),
        ),
      );

      expect(report.status, SourceCheckStatus.succeeded);
      expect(report.stages, hasLength(1));
      // 没有 ruleBookInfo 就拿不到 tocUrl，所以后面的阶段一个请求都不发。
      expect(http.requestedUrls, <String>[_searchUrl]);
    });

    test('execute_givenTheTocStageOff_stopsAfterTheDetailPage', () async {
      final FakeHttpClient http = _healthy();

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(),
          const SourceCheckSettings(
            keyword: _keyword,
            stages: <SourceCheckStage>{
              SourceCheckStage.search,
              SourceCheckStage.info,
            },
          ),
        ),
      );

      expect(report.stages, hasLength(2));
      expect(http.requestedUrls, <String>[_searchUrl, _bookUrl]);
    });

    test('execute_givenTheContentStageOff_stopsAfterTheToc', () async {
      final FakeHttpClient http = _healthy();

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(),
          const SourceCheckSettings(
            keyword: _keyword,
            stages: <SourceCheckStage>{
              SourceCheckStage.search,
              SourceCheckStage.info,
              SourceCheckStage.toc,
            },
          ),
        ),
      );

      expect(report.stages, hasLength(3));
      expect(http.requestedUrls, <String>[_searchUrl, _bookUrl, _tocUrl]);
    });

    test('execute_givenADeclaredCheckKeyWord_searchesWithIt', () async {
      final String declaredUrl =
          '$_baseUrl/search?q=${Uri.encodeQueryComponent('剑来')}&page=1';
      final FakeHttpClient http = FakeHttpClient()
        ..serve(declaredUrl, _searchPage)
        ..serve(_bookUrl, _bookPage)
        ..serve(_tocUrl, _tocPage)
        ..serve(_chapterUrl, _contentPage);

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(checkKeyWord: ' 剑来 '),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(report.status, SourceCheckStatus.succeeded);
      expect(http.requestedUrls, contains(declaredUrl));
    });

    test('execute_givenACheckKeyWordThatLooksLikeARule_fallsBack', () async {
      final FakeHttpClient http = _healthy();

      final SourceCheckReport report = _report(
        await _fixture(http).check.execute(
          _source(checkKeyWord: '@css:class.name@text'),
          const SourceCheckSettings(keyword: _keyword),
        ),
      );

      expect(report.status, SourceCheckStatus.succeeded);
      expect(http.requestedUrls, contains(_searchUrl));
    });

    test('execute_givenAFailedCheck_logsTheSourceAndItsGroups', () async {
      final _Fixture fixture = _fixture(
        FakeHttpClient()..serve(_searchUrl, '<div id="none"></div>'),
      );

      await fixture.check.execute(
        _source(),
        const SourceCheckSettings(keyword: _keyword),
      );

      expect(
        fixture.printer.events.last.message.toString(),
        allOf(contains('source=$_baseUrl'), contains(searchInvalidGroup)),
      );
    });
  });
}
