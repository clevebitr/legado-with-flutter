import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/switch_book_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// One source: a search page, and a book page that also carries the chapter list.
BookSource _source(String name) => BookSource.fromLegadoJson(<String, Object?>{
  'bookSourceName': name,
  'bookSourceUrl': 'https://$name.test',
  'searchUrl': 'https://$name.test/s?q={{key}}',
  'ruleSearch': <String, Object?>{
    'bookList': 'class.result',
    'name': 'class.title@text',
    'bookUrl': 'tag.a.0@href',
  },
  'ruleBookInfo': <String, Object?>{'name': 'class.title@text'},
  'ruleToc': <String, Object?>{
    'chapterList': 'class.chapter',
    'chapterName': 'tag.a.0@text',
    'chapterUrl': 'tag.a.0@href',
  },
  'ruleContent': <String, Object?>{'content': 'class.body'},
});

/// The same source, but its detail page links a separate table of contents.
BookSource _sourceWithToc(String name) {
  final BookSource source = _source(name);

  return source.copyWith(
    bookInfoRule: source.bookInfoRule?.copyWith(tocUrl: 'class.toc@href'),
  );
}

/// The search page of a source listing [titles] at `/book/<index>`.
String _searchPage(List<String> titles) => titles
    .asMap()
    .entries
    .map(
      (MapEntry<int, String> entry) =>
          '<div class="result"><a href="/book/${entry.key}">'
          '<span class="title">${entry.value}</span></a></div>',
    )
    .join();

/// One book page: its title and its chapter list (the `tocUrl` rule is absent, so the book page is
/// the table of contents too — which is what a real single-page source looks like).
String _bookPage(String title, List<String> chapters) =>
    '<h1 class="title">$title</h1>'
    '${chapters.asMap().entries.map((MapEntry<int, String> entry) => '<li class="chapter"><a href="/c/${entry.key}">'
        '${entry.value}</a></li>').join()}';

/// Builds the use case over [http].
SwitchBookSource _useCase(FakeHttpClient http) {
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

  return SwitchBookSource(
    search: SearchBooks(pages: pages),
    bookInfo: FetchBookInfo(pages: pages),
    toc: FetchToc(pages: pages),
  );
}

/// One chapter value for the alignment helpers.
Chapter _chapter(String name, int index) =>
    Chapter(name: name, url: 'https://b.test/c/$index');

void main() {
  group('SwitchBookSource candidates', () {
    test(
      'candidates_givenTwoSourcesWithTheBook_answersTheOtherSource',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(
            'https://a.test/s?q=%E5%89%91%E6%9D%A5',
            _searchPage(<String>['剑来']),
          )
          ..serve(
            'https://b.test/s?q=%E5%89%91%E6%9D%A5',
            _searchPage(<String>['剑来']),
          );

        final ParseResult<List<SourceCandidate>> found = await _useCase(http)
            .candidates(
              bookName: '剑来',
              sources: <BookSource>[_source('a'), _source('b')],
              currentSourceUrl: 'https://a.test',
            );

        final List<SourceCandidate> candidates =
            (found as ParseSuccess<List<SourceCandidate>>).data;
        // 当前源被排除（§决策 3）。
        expect(candidates.single.sourceUrl, 'https://b.test');
        expect(candidates.single.bookUrl, 'https://b.test/book/0');
      },
    );

    test('candidates_givenNoSourceButTheCurrent_answersEmpty', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://a.test/s?q=%E5%89%91%E6%9D%A5',
          _searchPage(<String>['剑来']),
        );

      final List<SourceCandidate> candidates =
          ((await _useCase(http).candidates(
            bookName: '剑来',
            sources: <BookSource>[_source('a')],
            currentSourceUrl: 'https://a.test',
          )) as ParseSuccess<List<SourceCandidate>>).data;

      // 没有候选不是失败：换源面板的空态就是它。
      expect(candidates, isEmpty);
    });

    test('candidates_givenAFailingSource_keepsTheOthers', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://a.test/s?q=%E5%89%91%E6%9D%A5',
          _searchPage(<String>['剑来']),
        )
        ..failWith(
          'https://b.test/s?q=%E5%89%91%E6%9D%A5',
          ParseFailureKind.networkFailed,
        );

      final List<SourceCandidate> candidates =
          ((await _useCase(http).candidates(
            bookName: '剑来',
            sources: <BookSource>[_source('a'), _source('b')],
            currentSourceUrl: 'https://nowhere.test',
          )) as ParseSuccess<List<SourceCandidate>>).data;

      expect(candidates.single.sourceUrl, 'https://a.test');
    });
  });

  group('SwitchBookSource matching', () {
    test('candidates_givenAContainedTitle_answersItAsAPartialMatch', () async {
      // 源把书名包了一层（「剑来（精校版）」）：仍然算候选，但排在完全相等之后
      // （ADR-0051 §决策 3 的排序口径）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://b.test/s?q=%E5%89%91%E6%9D%A5',
          _searchPage(<String>['剑来（精校版）']),
        );

      final List<SourceCandidate> candidates =
          ((await _useCase(http).candidates(
            bookName: '剑来',
            sources: <BookSource>[_source('b')],
            currentSourceUrl: 'https://a.test',
          )) as ParseSuccess<List<SourceCandidate>>).data;

      expect(candidates.single.bookUrl, 'https://b.test/book/0');
    });
  });

  group('SwitchBookSource alignment', () {
    test('alignChapterIndex_givenTheSameName_findsThatChapter', () {
      expect(
        _useCase(FakeHttpClient()).alignChapterIndex(
          <Chapter>[_chapter('第一章', 0), _chapter('第二章', 1)],
          '第二章',
          fallbackIndex: 0,
        ),
        1,
      );
    });

    test('alignChapterIndex_givenAContainedName_findsIt', () {
      expect(
        _useCase(FakeHttpClient()).alignChapterIndex(
          <Chapter>[_chapter('第一章 开端', 0), _chapter('第二章 继续', 1)],
          '第二章',
          fallbackIndex: 0,
        ),
        1,
      );
    });

    test('alignChapterIndex_givenNoMatch_fallsBackToTheSameIndex', () {
      final SwitchBookSource useCase = _useCase(FakeHttpClient());

      // 源把章节名全改成了数字：退回“同一个位置”，而不是回到第一章。
      expect(
        useCase.alignChapterIndex(
          <Chapter>[_chapter('1', 0), _chapter('2', 1), _chapter('3', 2)],
          '第二章',
          fallbackIndex: 2,
        ),
        2,
      );
      // 越界的 fallback 被钳到最后一章。
      expect(
        useCase.alignChapterIndex(
          <Chapter>[_chapter('1', 0)],
          '第二章',
          fallbackIndex: 9,
        ),
        0,
      );
    });
  });

  group('SwitchBookSource switchTo', () {
    test('switchTo_givenAReadableTarget_alignsTheChapter', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://b.test/book/0',
          _bookPage('剑来', <String>['第一章 开端', '第二章 继续']),
        );

      final ParseResult<SourceSwitchResult> switched = await _useCase(http)
          .switchTo(
            target: _source('b'),
            candidate: const SourceCandidate(
              sourceUrl: 'https://b.test',
              sourceName: 'b',
              bookUrl: 'https://b.test/book/0',
            ),
            currentChapterName: '第二章',
            currentChapterIndex: 0,
          );

      final SourceSwitchResult result =
          (switched as ParseSuccess<SourceSwitchResult>).data;
      expect(result.sourceUrl, 'https://b.test');
      expect(result.chapterName, '第二章 继续');
      expect(result.chapterUrl, 'https://b.test/c/1');
      expect(result.chapterIndex, 1);
    });

    test('switchTo_givenATargetWhoseTocListIsEmpty_answersAFailure', () async {
      // 目录**列表规则一条都没命中** → FetchToc 答成功且为空：换源必须显式失败，而不是
      // 切过去然后没有章节可读。（「命中了但没有链接」不再算空：那一章回落到目录页地址，
      // ADR-0069 G8。）
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://b.test/book/0',
          '<h1 class="title">剑来</h1>'
              '<li><span>没有链接的一章</span></li>',
        );

      expect(
        await _useCase(http).switchTo(
          target: _source('b'),
          candidate: const SourceCandidate(
            sourceUrl: 'https://b.test',
            sourceName: 'b',
            bookUrl: 'https://b.test/book/0',
          ),
          currentChapterName: '第二章',
          currentChapterIndex: 0,
        ),
        isA<ParseFailure<SourceSwitchResult>>(),
      );
    });

    test('switchTo_givenAnUnreadableToc_answersTheFailure', () async {
      // 详情页读得出来、目录页读不出来：失败必须停在这一步，不切过去。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          'https://b.test/book/0',
          '<h1 class="title">剑来</h1>'
              '<a class="toc" href="/toc">目录</a>',
        )
        ..failWith('https://b.test/toc', ParseFailureKind.notFound);

      expect(
        await _useCase(http).switchTo(
          target: _sourceWithToc('b'),
          candidate: const SourceCandidate(
            sourceUrl: 'https://b.test',
            sourceName: 'b',
            bookUrl: 'https://b.test/book/0',
          ),
          currentChapterName: '第二章',
          currentChapterIndex: 0,
        ),
        isA<ParseFailure<SourceSwitchResult>>(),
      );
    });

    test('switchTo_givenAnUnreadableTarget_answersTheFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith('https://b.test/book/0', ParseFailureKind.notFound);

      expect(
        await _useCase(http).switchTo(
          target: _source('b'),
          candidate: const SourceCandidate(
            sourceUrl: 'https://b.test',
            sourceName: 'b',
            bookUrl: 'https://b.test/book/0',
          ),
          currentChapterName: '第二章',
          currentChapterIndex: 0,
        ),
        isA<ParseFailure<SourceSwitchResult>>(),
      );
    });
  });
}
