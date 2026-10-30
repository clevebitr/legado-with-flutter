import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/change_source_search.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// One source: a search page, a detail page and a chapter list on the same host.
BookSource _source(String name) => BookSource(
  name: name,
  url: 'https://$name.test',
  searchUrl: 'https://$name.test/s?q={{key}}',
  searchRule: const SearchRule(
    bookList: 'class.result',
    name: 'class.title@text',
    author: 'class.author@text',
    bookUrl: 'tag.a.0@href',
  ),
  bookInfoRule: const BookInfoRule(
    name: 'class.title@text',
    author: 'class.author@text',
    coverUrl: 'class.cover@src',
    lastChapter: 'class.latest@text',
  ),
  tocRule: const TocRule(
    chapterList: 'class.chapter',
    chapterName: 'tag.a.0@text',
    chapterUrl: 'tag.a.0@href',
  ),
  contentRule: const ContentRule(content: 'class.body'),
);

/// A search page holding one hit per entry; `title` may be empty (a broken `name` rule).
String _searchPage(List<({String title, String author, String url})> hits) =>
    hits
        .map(
          (({String title, String author, String url}) hit) =>
              '<div class="result"><a href="${hit.url}">'
              '<span class="title">${hit.title}</span></a>'
              '<span class="author">${hit.author}</span></div>',
        )
        .join();

/// A detail page with the fields `loadInfo` reads.
String _detailPage(String title, String author, String lastChapter) =>
    '<h1 class="title">$title</h1>'
    '<span class="author">$author</span>'
    '<img class="cover" src="https://cover.test/$title.jpg">'
    '<span class="latest">$lastChapter</span>'
    '<ul>${List<String>.generate(3, (int index) => '<li class="chapter"><a href="/c/$index">第${index + 1}章</a></li>').join()}</ul>';

/// The use case under test built on [http].
ChangeSourceSearch _useCase(FakeHttpClient http) {
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

  return ChangeSourceSearch(
    search: SearchBooks(pages: pages),
    bookInfo: FetchBookInfo(pages: pages),
    toc: FetchToc(pages: pages),
    logger: logger,
  );
}

/// The search URL one source asks for [keyword] (URL templates percent-encode `{{key}}`).
String _searchUrl(String name, String keyword) =>
    'https://$name.test/s?q=${Uri.encodeComponent(keyword)}';

/// Returns the data of [result], failing the test when it failed.
List<ChangeSourceCandidate> _data(
  ParseResult<List<ChangeSourceCandidate>> result,
) => switch (result) {
  ParseSuccess<List<ChangeSourceCandidate>>(
    :final List<ChangeSourceCandidate> data,
  ) =>
    data,
  ParseFailure<List<ChangeSourceCandidate>>(:final ParseFailureKind kind) =>
    fail('Expected a success but got $kind.'),
};

void main() {
  group('ChangeSourceSearch progress', () {
    test('execute_givenThreeSources_publishesAfterEachOfThem', () async {
      final FakeHttpClient http = FakeHttpClient();
      for (final String name in <String>['a', 'b', 'c']) {
        http.serve(
          _searchUrl(name, '剑来'),
          _searchPage(<({String title, String author, String url})>[
            (title: '剑来', author: '烽火戏诸侯', url: '/book/1'),
          ]),
        );
      }
      final List<ChangeSourceProgress> progress = <ChangeSourceProgress>[];

      final List<ChangeSourceCandidate> candidates = _data(
        await _useCase(http).execute(
          ChangeSourceRequest(
            keyword: '剑来',
            sources: <BookSource>[_source('a'), _source('b'), _source('c')],
          ),
          onProgress: progress.add,
        ),
      );

      // 每处理完一个源就发一次快照，processed 单调递增到最后等于 total（进度条靠它）。
      expect(
        progress.map((ChangeSourceProgress p) => p.processedSources),
        <int>[1, 2, 3],
      );
      expect(progress.map((ChangeSourceProgress p) => p.totalSources), <int>[
        3,
        3,
        3,
      ]);
      expect(
        progress.map((ChangeSourceProgress p) => p.candidates.length),
        <int>[1, 2, 3],
      );
      expect(candidates, hasLength(3));
    });
  });

  group('ChangeSourceSearch matching', () {
    test('execute_givenNoTitle_searchesWithTheAuthor', () async {
      // 书名读不出来（空串）是本仓的常见故障：这时关键词退化成作者，仍然要能换源。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _searchUrl('a', '鲁迅'),
          _searchPage(<({String title, String author, String url})>[
            (title: '', author: '鲁迅', url: '/book/9'),
          ]),
        );

      final List<ChangeSourceCandidate> candidates = _data(
        await _useCase(http).execute(
          ChangeSourceRequest(
            keyword: '',
            author: '鲁迅',
            sources: <BookSource>[_source('a')],
          ),
        ),
      );

      expect(candidates.single.match, ChangeSourceMatch.authorOnly);
      expect(candidates.single.book.url, 'https://a.test/book/9');
    });

    test(
      'execute_givenABlankTitleFromAnotherAuthor_doesNotClaimTheBook',
      () async {
        // 空书名不能是「万能匹配」：作者也对不上时，这条命中不是这本书。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(
            _searchUrl('a', '剑来'),
            _searchPage(<({String title, String author, String url})>[
              (title: '', author: '另一个人', url: '/book/1'),
            ]),
          );

        expect(
          _data(
            await _useCase(http).execute(
              ChangeSourceRequest(
                keyword: '剑来',
                author: '烽火戏诸侯',
                sources: <BookSource>[_source('a')],
              ),
            ),
          ),
          isEmpty,
        );
      },
    );

    test('execute_givenCheckAuthor_rejectsTheOtherAuthor', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _searchUrl('a', '剑来'),
          _searchPage(<({String title, String author, String url})>[
            (title: '剑来', author: '另一个人', url: '/book/1'),
          ]),
        )
        ..serve(
          _searchUrl('b', '剑来'),
          _searchPage(<({String title, String author, String url})>[
            (title: '剑来', author: '烽火戏诸侯', url: '/book/2'),
          ]),
        );

      final List<ChangeSourceCandidate> candidates = _data(
        await _useCase(http).execute(
          ChangeSourceRequest(
            keyword: '剑来',
            author: '烽火戏诸侯',
            checkAuthor: true,
            sources: <BookSource>[_source('a'), _source('b')],
          ),
        ),
      );

      expect(candidates.single.sourceName, 'b');
    });

    test(
      'execute_givenAnExactMatchAfterAPartial_ordersTheExactFirst',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(
            _searchUrl('a', '剑来'),
            _searchPage(<({String title, String author, String url})>[
              (title: '剑来（精校版）', author: '烽火戏诸侯', url: '/book/1'),
            ]),
          )
          ..serve(
            _searchUrl('b', '剑来'),
            _searchPage(<({String title, String author, String url})>[
              (title: '剑来', author: '烽火戏诸侯', url: '/book/2'),
            ]),
          );

        final List<ChangeSourceCandidate> candidates = _data(
          await _useCase(http).execute(
            ChangeSourceRequest(
              keyword: '剑来',
              sources: <BookSource>[_source('a'), _source('b')],
            ),
          ),
        );

        expect(
          candidates.map((ChangeSourceCandidate c) => c.match),
          <ChangeSourceMatch>[
            ChangeSourceMatch.exact,
            ChangeSourceMatch.partial,
          ],
        );
        expect(candidates.first.sourceName, 'b');
      },
    );
  });

  group('ChangeSourceSearch optional loads', () {
    test('execute_givenLoadInfoAndToc_fillsTheCandidate', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _searchUrl('a', '剑来'),
          _searchPage(<({String title, String author, String url})>[
            (title: '剑来', author: '烽火戏诸侯', url: '/book/1'),
          ]),
        )
        ..serve('https://a.test/book/1', _detailPage('剑来', '烽火戏诸侯', '第3章 收官'));

      final List<ChangeSourceCandidate> candidates = _data(
        await _useCase(http).execute(
          ChangeSourceRequest(
            keyword: '剑来',
            loadInfo: true,
            loadToc: true,
            sources: <BookSource>[_source('a')],
          ),
        ),
      );

      final ChangeSourceCandidate candidate = candidates.single;
      expect(
        candidate.book.coverUrl,
        'https://cover.test/${Uri.encodeComponent('剑来')}.jpg',
      );
      expect(candidate.book.lastChapter, '第3章 收官');
      expect(candidate.tocUrl, 'https://a.test/book/1');
      expect(candidate.chapterCount, 3);
    });

    test('execute_givenAnUnreadableDetailPage_keepsTheCandidate', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _searchUrl('a', '剑来'),
          _searchPage(<({String title, String author, String url})>[
            (title: '剑来', author: '烽火戏诸侯', url: '/book/1'),
          ]),
        );
      // 详情页没被 serve：请求失败，但候选不能因为「加载详情」而消失。

      final List<ChangeSourceCandidate> candidates = _data(
        await _useCase(http).execute(
          ChangeSourceRequest(
            keyword: '剑来',
            loadInfo: true,
            sources: <BookSource>[_source('a')],
          ),
        ),
      );

      expect(candidates.single.book.name, '剑来');
      expect(candidates.single.chapterCount, isNull);
    });
  });

  group('ChangeSourceSearch stopping', () {
    test('execute_givenACancellation_keepsWhatWasFound', () async {
      final FakeHttpClient http = FakeHttpClient();
      for (final String name in <String>['a', 'b', 'c']) {
        http.serve(
          _searchUrl(name, '剑来'),
          _searchPage(<({String title, String author, String url})>[
            (title: '剑来', author: '烽火戏诸侯', url: '/book/1'),
          ]),
        );
      }
      final TaskCancellation cancellation = TaskCancellation();

      final List<ChangeSourceCandidate> candidates = _data(
        await _useCase(http).execute(
          ChangeSourceRequest(
            keyword: '剑来',
            sources: <BookSource>[_source('a'), _source('b'), _source('c')],
          ),
          cancellation: cancellation,
          // 第一个源回来就停：停止不是失败，已找到的候选要留下。
          onProgress: (ChangeSourceProgress _) => cancellation.cancel(),
        ),
      );

      expect(cancellation.isCancelled, isTrue);
      expect(candidates, hasLength(1));
    });

    test('execute_givenEverySourceFailing_answersAFailure', () async {
      final ParseResult<List<ChangeSourceCandidate>> result =
          await _useCase(FakeHttpClient()).execute(
            ChangeSourceRequest(
              keyword: '剑来',
              sources: <BookSource>[_source('a'), _source('b')],
            ),
          );

      expect(result, isA<ParseFailure<List<ChangeSourceCandidate>>>());
    });

    test(
      'execute_givenNoKeywordAndNoAuthor_answersEmptyWithoutRequests',
      () async {
        final FakeHttpClient http = FakeHttpClient();

        final List<ChangeSourceCandidate> candidates = _data(
          await _useCase(http).execute(
            ChangeSourceRequest(
              keyword: '  ',
              sources: <BookSource>[_source('a')],
            ),
          ),
        );

        expect(candidates, isEmpty);
        expect(http.requestedUrls, isEmpty);
      },
    );
  });
}
