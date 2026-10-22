import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/search_book.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/search_match_mode.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/aggregate_search_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// One source whose search URL carries a `{{page}}` template when [paged].
BookSource _source(
  String name, {
  bool paged = true,
  String listRule = 'class.result',
  String nameRule = 'class.title@text',
}) => BookSource.fromLegadoJson(<String, Object?>{
  'bookSourceName': name,
  'bookSourceUrl': 'https://$name.test',
  'searchUrl': paged
      ? 'https://$name.test/s?q={{key}}&p={{page}}'
      : 'https://$name.test/s?q={{key}}',
  'ruleSearch': <String, Object?>{
    'bookList': listRule,
    'name': nameRule,
    'bookUrl': 'tag.a.0@href',
  },
  'ruleToc': <String, Object?>{'chapterList': 'class.c'},
  'ruleContent': <String, Object?>{'content': 'class.body'},
});

/// The URL [name] renders for [keyword] on [page].
String _searchUrl(
  String name,
  String keyword, {
  int page = 1,
  bool paged = true,
}) => Uri.parse(
  paged
      ? 'https://$name.test/s?q=${Uri.encodeQueryComponent(keyword)}&p=$page'
      : 'https://$name.test/s?q=${Uri.encodeQueryComponent(keyword)}',
).toString();

/// One result page carrying a single hit titled [title].
String _page(String name, String title, {String href = '/book/1'}) =>
    '<div class="result"><span class="title">$title</span>'
    '<a href="$href">详情</a></div>';

/// The use case under test plus the client it uses.
typedef _Fixture = ({
  AggregateSearchBooks search,
  FakeHttpClient http,
  FakeLogPrinter printer,
  SearchBooks searchBooks,
});

/// Builds the use case around [http].
_Fixture _fixture(FakeHttpClient http, {Duration? timeout}) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);
  final PageFetchService pages = PageFetchService(
    engine: RuleEngine(
      logger: logger,
      jsBridge: FakeJsBridge(),
      variables: JsVariableStore(),
    ),
    http: http,
    logger: logger,
  );
  final SearchBooks searchBooks = SearchBooks(pages: pages);

  return (
    search: AggregateSearchBooks(
      search: searchBooks,
      logger: logger,
      timeout: timeout ?? sourceSearchTimeout,
    ),
    http: http,
    printer: printer,
    searchBooks: searchBooks,
  );
}

/// The names of [books], in order.
List<String> _names(List<SearchBook> books) =>
    books.map((SearchBook book) => book.name).toList();

void main() {
  group('AggregateSearchBooks', () {
    test('execute_givenTwoSources_mergesTheirHits', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来'), _page('a', '剑来'))
        ..serve(_searchUrl('b', '剑来'), _page('b', '剑来'));
      final _Fixture fixture = _fixture(http);

      final ParseResult<AggregateSearchResult> result = await fixture.search
          .execute(
            AggregateSearchRequest(
              keyword: '剑来',
              sources: <BookSource>[_source('a'), _source('b')],
              matchMode: SearchMatchMode.defaultMode,
              concurrency: 2,
            ),
          );

      final AggregateSearchResult data =
          (result as ParseSuccess<AggregateSearchResult>).data;
      expect(data.books, hasLength(1));
      // 同一本书两个源命中：合并成一条，origins 两条。
      expect(data.books.single.origins, hasLength(2));
      expect(data.processedSources, 2);
      expect(data.failedSources, 0);
    });

    test('execute_givenOneSourceFails_keepsTheOthers', () async {
      // 单源失败不拖垮整批（ADR-0046 §决策 5）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来'), _page('a', '剑来'))
        ..failWith(_searchUrl('b', '剑来'), ParseFailureKind.networkFailed);
      final _Fixture fixture = _fixture(http);

      final AggregateSearchResult data = ((await fixture.search.execute(
        AggregateSearchRequest(
          keyword: '剑来',
          sources: <BookSource>[_source('a'), _source('b')],
          matchMode: SearchMatchMode.defaultMode,
        ),
      )) as ParseSuccess<AggregateSearchResult>).data;

      expect(_names(data.books), <String>['剑来']);
      expect(data.failedSources, 1);
      expect(
        fixture.printer.events.any(
          (event) => event.message.toString().contains('failed on one source'),
        ),
        isTrue,
      );
    });

    test('execute_givenEverySourceFails_answersAFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_searchUrl('a', '剑来'), ParseFailureKind.networkFailed)
        ..failWith(_searchUrl('b', '剑来'), ParseFailureKind.networkFailed);
      final _Fixture fixture = _fixture(http);

      final ParseResult<AggregateSearchResult> result = await fixture.search
          .execute(
            AggregateSearchRequest(
              keyword: '剑来',
              sources: <BookSource>[_source('a'), _source('b')],
              matchMode: SearchMatchMode.defaultMode,
            ),
          );

      final ParseFailure<AggregateSearchResult> failure =
          result as ParseFailure<AggregateSearchResult>;
      expect(failure.kind, ParseFailureKind.networkFailed);
      expect(failure.rulePath, 'search.aggregate');
    });

    test(
      'execute_givenASourceThatNeverAnswers_timesOutOnThatSourceOnly',
      () async {
        // 单源超时可注入：测试用 10 ms 而不是真等 60 s（ADR-0046 §决策 5）。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_searchUrl('a', '剑来'), _page('a', '剑来'))
          ..serve(_searchUrl('b', '剑来'), _page('b', '剑来'));
        final _Fixture fixture = _fixture(
          http,
          timeout: const Duration(milliseconds: 10),
        );
        // 只有第一个请求挂住。
        final Completer<void> gate = Completer<void>();
        var requests = 0;
        http.onRequest = () {
          requests++;
          if (requests == 1) {
            return gate.future;
          }

          return Future<void>.value();
        };

        final AggregateSearchResult data = ((await fixture.search.execute(
          AggregateSearchRequest(
            keyword: '剑来',
            sources: <BookSource>[_source('a'), _source('b')],
            matchMode: SearchMatchMode.defaultMode,
          ),
        )) as ParseSuccess<AggregateSearchResult>).data;

        gate.complete();
        expect(data.failedSources, 1);
        expect(
          fixture.printer.events.any(
            (event) => event.message.toString().contains('timed out'),
          ),
          isTrue,
        );
      },
    );

    test('execute_givenASourceThrows_keepsTheBatchAndTheOtherHits', () async {
      // 请求层破坏契约抛异常（真实案例：打日志时的 FormatException）时，它只能算
      // 这一个源失败。否则异常会冲出 `execute`，把已经发布的命中全冲掉。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来'), _page('a', '剑来'))
        ..throwOn(_searchUrl('b', '剑来'), const FormatException('boom'));
      final _Fixture fixture = _fixture(http);

      final ParseResult<AggregateSearchResult> result = await fixture.search
          .execute(
            AggregateSearchRequest(
              keyword: '剑来',
              sources: <BookSource>[_source('a'), _source('b')],
              matchMode: SearchMatchMode.defaultMode,
              concurrency: 2,
            ),
          );

      final AggregateSearchResult data =
          (result as ParseSuccess<AggregateSearchResult>).data;
      expect(_names(data.books), <String>['剑来']);
      expect(data.failedSources, 1);
      expect(data.processedSources, 2);
    });

    test('execute_givenEverySourceReturnsNothing_isASuccess', () async {
      // 全部源都「没搜到」不是失败：只有全部**出错**才算（ADR-0046 §决策 5）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来'), '<div id="none"></div>');
      final _Fixture fixture = _fixture(http);

      final ParseResult<AggregateSearchResult> result = await fixture.search
          .execute(
            AggregateSearchRequest(
              keyword: '剑来',
              sources: <BookSource>[_source('a')],
              matchMode: SearchMatchMode.defaultMode,
            ),
          );

      expect(result, isA<ParseSuccess<AggregateSearchResult>>());
    });

    test('execute_givenABlankKeyword_answersInvalidBookSource', () async {
      final _Fixture fixture = _fixture(FakeHttpClient());

      final ParseResult<AggregateSearchResult> result = await fixture.search
          .execute(
            AggregateSearchRequest(
              keyword: '   ',
              sources: <BookSource>[_source('a')],
              matchMode: SearchMatchMode.defaultMode,
            ),
          );

      expect(
        (result as ParseFailure<AggregateSearchResult>).rulePath,
        'search.keyword',
      );
    });

    test('execute_givenNoSource_answersInvalidBookSource', () async {
      final _Fixture fixture = _fixture(FakeHttpClient());

      final ParseResult<AggregateSearchResult> result = await fixture.search
          .execute(
            AggregateSearchRequest(
              keyword: '剑来',
              sources: const <BookSource>[],
              matchMode: SearchMatchMode.defaultMode,
            ),
          );

      expect(
        (result as ParseFailure<AggregateSearchResult>).rulePath,
        'search.scope',
      );
    });

    test('execute_givenASecondPage_skipsSourcesWithoutPageSupport', () async {
      // 不支持翻页的源在第 2 页起直接跳过，不记成失败（ADR-0046 §决策 7）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来', page: 2), _page('a', '剑来二'));
      final _Fixture fixture = _fixture(http);

      final AggregateSearchResult data = ((await fixture.search.execute(
        AggregateSearchRequest(
          keyword: '剑来',
          sources: <BookSource>[_source('a'), _source('b', paged: false)],
          matchMode: SearchMatchMode.defaultMode,
          page: 2,
        ),
      )) as ParseSuccess<AggregateSearchResult>).data;

      expect(_names(data.books), <String>['剑来二']);
      expect(data.failedSources, 0);
      expect(http.requestedUrls, isNot(contains(contains('b.test'))));
    });

    test('execute_givenASinglePageSource_hasNoMore', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来', paged: false), _page('a', '剑来'));
      final _Fixture fixture = _fixture(http);

      final AggregateSearchResult data = ((await fixture.search.execute(
        AggregateSearchRequest(
          keyword: '剑来',
          sources: <BookSource>[_source('a', paged: false)],
          matchMode: SearchMatchMode.defaultMode,
        ),
      )) as ParseSuccess<AggregateSearchResult>).data;

      expect(data.hasMore, isFalse);
    });

    test('execute_givenAPagedSource_hasMore', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来'), _page('a', '剑来'));
      final _Fixture fixture = _fixture(http);

      final AggregateSearchResult data = ((await fixture.search.execute(
        AggregateSearchRequest(
          keyword: '剑来',
          sources: <BookSource>[_source('a')],
          matchMode: SearchMatchMode.defaultMode,
        ),
      )) as ParseSuccess<AggregateSearchResult>).data;

      expect(data.hasMore, isTrue);
    });

    test('execute_whenCancelledBeforeTheStart_keepsWhatWasFound', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来'), _page('a', '剑来'));
      final _Fixture fixture = _fixture(http);
      final TaskCancellation cancellation = TaskCancellation()..cancel();

      final AggregateSearchResult data = ((await fixture.search.execute(
        AggregateSearchRequest(
          keyword: '剑来',
          sources: <BookSource>[_source('a')],
          matchMode: SearchMatchMode.defaultMode,
        ),
        cancellation: cancellation,
      )) as ParseSuccess<AggregateSearchResult>).data;

      expect(data.books, isEmpty);
      // 取消后不再有「还有更多」。
      expect(data.hasMore, isFalse);
      expect(http.requestedUrls, isEmpty);
    });

    test(
      'execute_whenCancelledMidRun_stopsBetweenSourcesAndKeepsResults',
      () async {
        // 取消在源与源之间生效：第一个源已经完成，第二个源不再开始。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_searchUrl('a', '剑来'), _page('a', '剑来'))
          ..serve(_searchUrl('b', '剑来'), _page('b', '剑来'));
        final _Fixture fixture = _fixture(http);
        final TaskCancellation cancellation = TaskCancellation();
        http.onRequest = () async => cancellation.cancel();

        final AggregateSearchResult data = ((await fixture.search.execute(
          AggregateSearchRequest(
            keyword: '剑来',
            sources: <BookSource>[_source('a'), _source('b')],
            matchMode: SearchMatchMode.defaultMode,
          ),
          cancellation: cancellation,
        )) as ParseSuccess<AggregateSearchResult>).data;

        expect(http.requestedUrls, hasLength(1));
        expect(data.books, hasLength(1));
        // 被取消的批不再声称「还有更多」。
        expect(data.hasMore, isFalse);
      },
    );

    test('execute_givenAPausedBatch_doesNotStartTheNextSource', () async {
      // 暂停在源与源之间生效：第一个源跑完后，第二个源要等 resume。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来'), _page('a', '剑来'))
        ..serve(_searchUrl('b', '剑来'), _page('b', '剑来'));
      final _Fixture fixture = _fixture(http);
      final SearchPause pause = SearchPause();
      var started = 0;
      http.onRequest = () async {
        started++;
        if (started == 1) {
          pause.pause();
        }
      };

      final Future<ParseResult<AggregateSearchResult>> running = fixture.search
          .execute(
            AggregateSearchRequest(
              keyword: '剑来',
              sources: <BookSource>[_source('a'), _source('b')],
              matchMode: SearchMatchMode.defaultMode,
            ),
            pause: pause,
          );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(http.requestedUrls, hasLength(1));
      pause.resume();
      final AggregateSearchResult data =
          ((await running) as ParseSuccess<AggregateSearchResult>).data;

      expect(data.books, hasLength(1));
      expect(http.requestedUrls, hasLength(2));
    });

    test('execute_givenProgress_reportsAfterEverySource', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_searchUrl('a', '剑来'), _page('a', '剑来'))
        ..serve(_searchUrl('b', '剑来'), _page('b', '其他'));
      final _Fixture fixture = _fixture(http);
      final List<AggregateSearchResult> progress = <AggregateSearchResult>[];

      await fixture.search.execute(
        AggregateSearchRequest(
          keyword: '剑来',
          sources: <BookSource>[_source('a'), _source('b')],
          matchMode: SearchMatchMode.defaultMode,
        ),
        onProgress: progress.add,
      );

      expect(progress, hasLength(2));
      expect(progress.first.processedSources, 1);
      expect(progress.last.processedSources, 2);
      expect(progress.last.totalSources, 2);
    });

    test('AggregateSearchRequest_givenZeroConcurrency_throws', () {
      // 并发 0 会让整批永久停住：构造处就挡住（与 5.6 的 budgetOrDefault 同一条坑）。
      expect(
        () => AggregateSearchRequest(
          keyword: '剑来',
          sources: const <BookSource>[],
          matchMode: SearchMatchMode.defaultMode,
          concurrency: 0,
        ),
        throwsArgumentError,
      );
    });

    test('SearchPause_whenPausedAndResumed_gatesTheWaiters', () async {
      final SearchPause pause = SearchPause();

      expect(pause.isPaused, isFalse);
      await pause.waitWhilePaused();
      pause.pause();
      expect(pause.isPaused, isTrue);
      final Future<void> waiter = pause.waitWhilePaused();
      pause.resume();
      await waiter;
      expect(pause.isPaused, isFalse);
      // 已经恢复之后再等待应立即通过。
      await pause.waitWhilePaused();
    });
  });

  group('BookSearchScope in the aggregate path', () {
    test('scope_givenGroups_resolvesToTheirSources', () {
      // 这一条把范围与聚合用例的关系钉住：范围只决定候选源。
      expect(
        const BookSearchScope.groups(<String>{'精选'}).groupsOrEmpty,
        <String>{'精选'},
      );
    });
  });
}
