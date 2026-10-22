import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/entities/manga_pages.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_manga_pages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// One chapter URL on the test site.
const String _chapterUrl = 'https://example-novel.test/book/1/1.html';

/// A manga source whose body rule reads every `img` inside `.page`.
BookSource _source({String contentRule = 'class.page@tag.img@src'}) =>
    BookSource.fromLegadoJson(<String, Object?>{
      'bookSourceName': '漫画源',
      'bookSourceUrl': 'https://example-novel.test',
      'bookSourceType': 2,
      'header': jsonEncode(<String, String>{
        'Referer': 'https://example-novel.test/',
      }),
      'ruleSearch': <String, Object?>{'bookList': 'class.item'},
      'ruleToc': <String, Object?>{'chapterList': 'class.c'},
      'ruleContent': <String, Object?>{'content': contentRule},
    });

/// Builds the use case around [http] and a printer the test can read.
({FetchMangaPages useCase, FakeLogPrinter printer}) _useCase(
  FakeHttpClient http, [
  FakeJsBridge? bridge,
]) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);

  return (
    useCase: FetchMangaPages(
      pages: PageFetchService(
        engine: RuleEngine(
          logger: logger,
          jsBridge: bridge ?? FakeJsBridge(),
          variables: JsVariableStore(),
        ),
        http: http,
        logger: logger,
      ),
      logger: logger,
    ),
    printer: printer,
  );
}

/// One HTML page whose `.page` holds [images] as `img` `src` values.
String _html(List<String> images) =>
    '<div class="page">'
    '${images.map((String src) => '<img src="$src">').join()}'
    '</div>';

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
    'Expected a success but got ${kind.name}.',
  ),
};

void main() {
  group('FetchMangaPages', () {
    test('execute_givenImagePage_answersAbsoluteDeDuplicatedUrls', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          _html(<String>['/img/1.jpg', 'https://cdn.test/2.jpg', '/img/1.jpg']),
        );
      final ({FetchMangaPages useCase, FakeLogPrinter printer}) fixture =
          _useCase(http);

      final MangaPages pages = _data(
        await fixture.useCase.execute(
          _source(),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(pages.urls, <String>[
        'https://example-novel.test/img/1.jpg',
        'https://cdn.test/2.jpg',
      ]);
      // 图片请求带书源自己的 header：图片站常校验 Referer（ADR-0053 §决策 2）。
      expect(pages.headers?['Referer'], 'https://example-novel.test/');
    });

    test('execute_givenHtmlFromTheRule_extractsTheImageAddresses', () async {
      // 真源常见形态：规则产出 HTML（整块 div 或逐个 <img>），而不是图片地址。
      // 旧实现把整段 HTML 当「不可用地址」丢掉 → 整章 parseFailed；现在从标记里取图。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '<div class="page">'
          '<img class="lazy" data-original="/img/1.jpg">'
          '<img class="lazy" data-original="https://cdn.test/2.jpg">'
          '<img src="/img/placeholder.png">'
          '</div>',
        );
      final ({FetchMangaPages useCase, FakeLogPrinter printer}) fixture =
          _useCase(http);

      final MangaPages pages = _data(
        await fixture.useCase.execute(
          _source(contentRule: 'class.page@html'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      // data-original 优先于占位 src；相对地址按章节页解析。
      expect(pages.urls, <String>[
        'https://example-novel.test/img/1.jpg',
        'https://cdn.test/2.jpg',
        'https://example-novel.test/img/placeholder.png',
      ]);
    });

    test('execute_givenNoImage_answersParseFailedAtTheContentRule', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, '<div class="page"></div>');
      final ({FetchMangaPages useCase, FakeLogPrinter printer}) fixture =
          _useCase(http);

      final ParseFailure<Never> failure = _failure(
        await fixture.useCase.execute(
          _source(),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, mangaPagesRulePath);
    });

    test('execute_givenOnlyAnUnusableAddress_dropsItWithAWarning', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _html(<String>['data:image/png;base64,AAAA']));
      final ({FetchMangaPages useCase, FakeLogPrinter printer}) fixture =
          _useCase(http);

      final ParseFailure<Never> failure = _failure(
        await fixture.useCase.execute(
          _source(),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(
        fixture.printer.events
            .map((LogEvent event) => '${event.message}')
            .any((String line) => line.contains('unusable image address')),
        isTrue,
      );
    });

    test('execute_givenABlankOrNonHttpValue_dropsItAndKeepsTheRest', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          _html(<String>['   ', 'ftp://img.test/1.jpg', '/img/2.jpg']),
        );
      final ({FetchMangaPages useCase, FakeLogPrinter printer}) fixture =
          _useCase(http);

      final MangaPages pages = _data(
        await fixture.useCase.execute(
          _source(),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(pages.urls, <String>['https://example-novel.test/img/2.jpg']);
    });

    test(
      'execute_givenAFailingContinuationPage_propagatesItsFailure',
      () async {
        // 分页的**后续**页失败：整章失败，而不是悄悄只返回第一页（ADR-0053 §决策 2）。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(
            _chapterUrl,
            '<div class="page"><img src="/img/1.jpg"></div>'
            '<a class="next" href="/book/1/1.html?page=2">下一页</a>',
          )
          ..failWith(
            'https://example-novel.test/book/1/1.html?page=2',
            ParseFailureKind.networkFailed,
          );
        final BookSource paged = _source().copyWith(
          contentRule: _source().contentRule.copyWith(
            nextContentUrl: 'class.next@href',
          ),
        );
        final ({FetchMangaPages useCase, FakeLogPrinter printer}) fixture =
            _useCase(http);

        final ParseFailure<Never> failure = _failure(
          await fixture.useCase.execute(
            paged,
            const ChapterRequest(url: _chapterUrl),
          ),
        );

        expect(failure.kind, ParseFailureKind.networkFailed);
        expect(failure.rulePath, 'ruleContent');
      },
    );

    test('execute_givenARejectedImageRule_failsAtThatRule', () async {
      // 顶层规则被 JS 拒绝：整章失败并点名规则，而不是返回空图集（C-SRC-4）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _html(<String>['/img/1.jpg']));
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = const ParseFailure<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'contentRule.content',
        );
      final ({FetchMangaPages useCase, FakeLogPrinter printer}) fixture =
          _useCase(http, bridge);

      final ParseFailure<Never> failure = _failure(
        await fixture.useCase.execute(
          _source(contentRule: 'class.page@tag.img@src@js:result'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'contentRule.content');
    });

    test('execute_givenAFailedChapterPage_propagatesTheFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_chapterUrl, ParseFailureKind.networkFailed);
      final ({FetchMangaPages useCase, FakeLogPrinter printer}) fixture =
          _useCase(http);

      final ParseFailure<Never> failure = _failure(
        await fixture.useCase.execute(
          _source(),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(failure.kind, ParseFailureKind.networkFailed);
      expect(failure.rulePath, 'ruleContent');
    });

    test('execute_givenPagedContent_keepsRuleOrderAndDropsRepeats', () async {
      // 第二章续页把第一张图又写了一次：分页站点常见，去重后不能出现两遍。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '<div class="page"><img src="/img/1.jpg"></div>'
          '<a class="next" href="/book/1/1.html?page=2">下一页</a>',
        )
        ..serve(
          'https://example-novel.test/book/1/1.html?page=2',
          _html(<String>['/img/1.jpg', '/img/3.jpg']),
        );
      final BookSource paged = _source().copyWith(
        contentRule: _source().contentRule.copyWith(
          nextContentUrl: 'class.next@href',
        ),
      );
      final ({FetchMangaPages useCase, FakeLogPrinter printer}) fixture =
          _useCase(http);

      final MangaPages pages = _data(
        await fixture.useCase.execute(
          paged,
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(pages.urls, <String>[
        'https://example-novel.test/img/1.jpg',
        'https://example-novel.test/img/3.jpg',
      ]);
    });
  });
}
