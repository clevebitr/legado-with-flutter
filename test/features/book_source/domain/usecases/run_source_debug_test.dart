import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_debug.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/explore_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/run_source_debug.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_content_cache.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// The website the debug console is pointed at.
const String _baseUrl = 'https://debug.test';

/// The keyword the search target runs with.
const String _keyword = 'kw';

/// The rendered search URL, i.e. what the console reports as a source.
const String _searchUrl = '$_baseUrl/search?q=$_keyword&page=1';

/// The book page, resolved against [_searchUrl].
const String _bookUrl = '$_baseUrl/book/1/';

/// The table-of-contents page.
const String _tocUrl = '$_baseUrl/book/1/toc/';

/// The first chapter.
const String _chapterUrl = '$_baseUrl/book/1/1.html';

/// The body text the content target must not leak into the event stream.
const String _bodyText = '这是正文，绝不进日志';

/// Clock a test can pin (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime(2026, 10, 21);
}

/// Builds the source the console debugs.
BookSource _source() => BookSource.fromLegadoJson(<String, Object?>{
  'bookSourceName': '调试用例源',
  'bookSourceUrl': _baseUrl,
  'searchUrl': '$_baseUrl/search?q={{key}}&page={{page}}',
  'ruleSearch': <String, Object?>{
    'bookList': 'class.result',
    'name': 'class.title@text',
    'bookUrl': 'tag.a.0@href',
  },
  'ruleBookInfo': <String, Object?>{
    'name': 'class.name@text',
    'tocUrl': 'tag.a.0@href',
  },
  'ruleToc': <String, Object?>{
    'chapterList': 'class.chapter',
    'chapterName': 'tag.a@text',
    'chapterUrl': 'tag.a.0@href',
  },
  'ruleContent': <String, Object?>{'content': 'id.content@text'},
});

/// One search result page with [count] hits.
String _searchPage(int count) => <String>[
  for (var index = 1; index <= count; index++)
    '<div class="result"><span class="title">书$index</span>'
        '<a href="/book/$index/">详情</a></div>',
].join();

/// The book detail page.
const String _bookPage =
    '<h1 class="name">书甲</h1><a href="/book/1/toc/">目录</a>';

/// The table-of-contents page with three chapters.
const String _tocPage =
    '<dl><dd class="chapter"><a href="/book/1/1.html">第1章</a></dd>'
    '<dd class="chapter"><a href="/book/1/2.html">第2章</a></dd>'
    '<dd class="chapter"><a href="/book/1/3.html">第3章</a></dd></dl>';

/// The chapter body page.
const String _contentPage = '<div id="content">$_bodyText</div>';

/// The console under test plus the client it uses.
typedef _Fixture = ({RunSourceDebug debug, FakeHttpClient http});

/// Builds the console under test around [http].
_Fixture _fixture(FakeHttpClient http) {
  final AppLogger logger = AppLogger(
    level: LogLevel.debug,
    printer: FakeLogPrinter(),
  );
  final PageFetchService pages = PageFetchService(
    engine: RuleEngine(
      logger: logger,
      jsBridge: FakeJsBridge(),
      variables: JsVariableStore(),
    ),
    http: http,
    logger: logger,
  );

  return (
    debug: RunSourceDebug(
      pages: pages,
      searchBooks: SearchBooks(pages: pages),
      exploreBooks: ExploreBooks(pages: pages),
      bookInfo: FetchBookInfo(pages: pages),
      toc: FetchToc(pages: pages),
      content: FetchContent(pages: pages, cache: FakeContentCache()),
      clock: _FixedClock(),
    ),
    http: http,
  );
}

/// A client serving every page of the healthy chain.
FakeHttpClient _healthy({int results = 1}) => FakeHttpClient()
  ..serve(_searchUrl, _searchPage(results))
  ..serve(_bookUrl, _bookPage)
  ..serve(_tocUrl, _tocPage)
  ..serve(_chapterUrl, _contentPage);

/// Runs one target and collects every event.
Future<({SourceDebugStatus status, List<SourceDebugEvent> events})> _run(
  RunSourceDebug debug, {
  required SourceDebugTarget target,
  required String query,
  TaskCancellation? cancellation,
}) async {
  final List<SourceDebugEvent> events = <SourceDebugEvent>[];
  final ParseResult<SourceDebugStatus> result = await debug.execute(
    _source(),
    target: target,
    query: query,
    onEvent: events.add,
    cancellation: cancellation,
  );

  return (
    status: switch (result) {
      ParseSuccess<SourceDebugStatus>(:final SourceDebugStatus data) => data,
      ParseFailure<SourceDebugStatus>(:final ParseFailureKind kind) => fail(
        'Expected a status but got $kind.',
      ),
    },
    events: events,
  );
}

void main() {
  group('RunSourceDebug', () {
    test(
      'execute_givenTheSearchTarget_reportsMessageSourceAndResult',
      () async {
        final _Fixture fixture = _fixture(_healthy());

        final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
            await _run(
              fixture.debug,
              target: SourceDebugTarget.search,
              query: _keyword,
            );

        expect(run.status, SourceDebugStatus.succeeded);
        expect(
          run.events.map((SourceDebugEvent event) => event.kind),
          <SourceDebugEventKind>[
            SourceDebugEventKind.message,
            SourceDebugEventKind.source,
            SourceDebugEventKind.source,
            SourceDebugEventKind.message,
          ],
        );
        // 「来源」事件报的是真正发出去的地址（渲染后的 searchUrl 与命中书的地址）。
        expect(run.events[1].url, _searchUrl);
        expect(run.events[2].url, _bookUrl);
        expect(run.events.last.text, 'search: books=1');
        expect(
          run.events.every(
            (SourceDebugEvent event) =>
                event.target == SourceDebugTarget.search,
          ),
          isTrue,
        );
        expect(fixture.http.requestedUrls, <String>[_searchUrl]);
      },
    );

    test('execute_givenManyHits_reportsAtMostThreeUrls', () async {
      // 一个 300 命中的搜索不该把控制台刷成一屏 URL。
      final _Fixture fixture = _fixture(_healthy(results: 5));

      final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
          await _run(
            fixture.debug,
            target: SourceDebugTarget.search,
            query: _keyword,
          );

      expect(run.events.last.text, 'search: books=5');
      expect(
        run.events
            .where(
              (SourceDebugEvent event) =>
                  event.kind == SourceDebugEventKind.source,
            )
            .length,
        4,
        reason: '1 个搜索地址 + 3 个命中地址',
      );
    });

    test('execute_givenABlankQuery_returnsInvalidBookSource', () async {
      final _Fixture fixture = _fixture(_healthy());

      final ParseResult<SourceDebugStatus> result = await fixture.debug.execute(
        _source(),
        target: SourceDebugTarget.search,
        query: '   ',
        onEvent: (SourceDebugEvent event) => fail('不应有事件'),
      );

      expect(switch (result) {
        ParseFailure<SourceDebugStatus>(:final ParseFailureKind kind) => kind,
        ParseSuccess<SourceDebugStatus>() => null,
      }, ParseFailureKind.invalidBookSource);
      expect(fixture.http.requestedUrls, isEmpty);
    });

    test('execute_givenASourceWithoutSearchUrl_reportsAnError', () async {
      final _Fixture fixture = _fixture(FakeHttpClient());
      final BookSource source = _source().copyWith(searchUrl: null);

      final List<SourceDebugEvent> events = <SourceDebugEvent>[];
      final ParseResult<SourceDebugStatus> result = await fixture.debug.execute(
        source,
        target: SourceDebugTarget.search,
        query: _keyword,
        onEvent: events.add,
      );

      expect(switch (result) {
        ParseSuccess<SourceDebugStatus>(:final SourceDebugStatus data) => data,
        ParseFailure<SourceDebugStatus>() => null,
      }, SourceDebugStatus.failed);
      expect(events.single.kind, SourceDebugEventKind.error);
      expect(events.single.failureKind, ParseFailureKind.invalidBookSource);
    });

    test('execute_givenAFailingSearch_reportsAnErrorEvent', () async {
      final _Fixture fixture = _fixture(
        FakeHttpClient()..failWith(_searchUrl, ParseFailureKind.networkTimeout),
      );

      final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
          await _run(
            fixture.debug,
            target: SourceDebugTarget.search,
            query: _keyword,
          );

      expect(run.status, SourceDebugStatus.failed);
      final SourceDebugEvent error = run.events.last;
      expect(error.kind, SourceDebugEventKind.error);
      expect(error.failureKind, ParseFailureKind.networkTimeout);
      expect(error.rulePath, 'searchUrl');
    });

    test('execute_givenAnUnreachableUrlTarget_reportsAFailure', () async {
      // 四个 URL 目标都要把失败落成一条 error 事件，而不是抛出或静默结束。
      for (final SourceDebugTarget target in <SourceDebugTarget>[
        SourceDebugTarget.explore,
        SourceDebugTarget.info,
        SourceDebugTarget.toc,
        SourceDebugTarget.content,
      ]) {
        final _Fixture fixture = _fixture(FakeHttpClient());

        final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
            await _run(fixture.debug, target: target, query: _bookUrl);

        expect(run.status, SourceDebugStatus.failed, reason: '$target');
        expect(
          run.events.last.kind,
          SourceDebugEventKind.error,
          reason: '$target',
        );
        expect(
          run.events.last.failureKind,
          ParseFailureKind.notFound,
          reason: '$target',
        );
      }
    });

    test(
      'execute_givenTheExploreTarget_reportsTheCategoryAndTheBooks',
      () async {
        final _Fixture fixture = _fixture(
          FakeHttpClient()..serve(_bookUrl, _searchPage(1)),
        );

        final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
            await _run(
              fixture.debug,
              target: SourceDebugTarget.explore,
              query: _bookUrl,
            );

        expect(run.status, SourceDebugStatus.succeeded);
        expect(run.events.first.kind, SourceDebugEventKind.source);
        expect(run.events.first.url, _bookUrl);
        expect(run.events.last.text, 'explore: books=1');
      },
    );

    test('execute_givenTheInfoTarget_reportsTheTocUrl', () async {
      final _Fixture fixture = _fixture(_healthy());

      final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
          await _run(
            fixture.debug,
            target: SourceDebugTarget.info,
            query: _bookUrl,
          );

      expect(run.status, SourceDebugStatus.succeeded);
      expect(run.events.first.url, _bookUrl);
      expect(run.events[1].url, _tocUrl);
      expect(run.events.last.text, 'info: name=书甲');
    });

    test('execute_givenTheTocTarget_reportsTheChapterCount', () async {
      final _Fixture fixture = _fixture(_healthy());

      final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
          await _run(
            fixture.debug,
            target: SourceDebugTarget.toc,
            query: _tocUrl,
          );

      expect(run.status, SourceDebugStatus.succeeded);
      expect(run.events.last.text, 'toc: chapters=3');
      expect(run.events[1].url, '$_baseUrl/book/1/1.html');
    });

    test('execute_givenTheContentTarget_reportsTheLengthOnly', () async {
      final _Fixture fixture = _fixture(_healthy());

      final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
          await _run(
            fixture.debug,
            target: SourceDebugTarget.content,
            query: _chapterUrl,
          );

      expect(run.status, SourceDebugStatus.succeeded);
      expect(run.events.last.text, 'content: chars=${_bodyText.length}');
      // C-SEC-4：正文本身绝不进事件流。
      expect(
        run.events.every(
          (SourceDebugEvent event) => !event.text.contains(_bodyText),
        ),
        isTrue,
      );
    });

    test('execute_whenCancelledBeforeTheStart_reportsCancelled', () async {
      final _Fixture fixture = _fixture(_healthy());
      final TaskCancellation cancellation = TaskCancellation()..cancel();

      final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
          await _run(
            fixture.debug,
            target: SourceDebugTarget.content,
            query: _chapterUrl,
            cancellation: cancellation,
          );

      expect(run.status, SourceDebugStatus.cancelled);
      expect(run.events.single.kind, SourceDebugEventKind.message);
      expect(run.events.single.text, 'cancelled');
      expect(fixture.http.requestedUrls, isEmpty);
    });

    test('execute_givenACancelledRunDuringARequest_stopsAfterIt', () async {
      // 取消是协作式的：请求发出后就算了，回来的那一页不再往下走（ADR-0043 §后果）。
      final FakeHttpClient http = _healthy();
      final TaskCancellation cancellation = TaskCancellation()..cancel();

      final ({SourceDebugStatus status, List<SourceDebugEvent> events}) run =
          await _run(
            _fixture(http).debug,
            target: SourceDebugTarget.toc,
            query: _tocUrl,
            cancellation: cancellation,
          );

      expect(run.status, SourceDebugStatus.cancelled);
      expect(run.events.single.text, 'cancelled');
      expect(http.requestedUrls, isEmpty);
    });
  });
}
