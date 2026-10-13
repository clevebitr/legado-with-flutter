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
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// The real default-rule source of the offline corpus.
const String _sourceFixture =
    'test/fixtures/book_sources/legado_default_rules_source.json';

/// The book URL the corpus search page points at.
const String _bookUrl = 'https://example-novel.test/book/1/';

/// Loads the corpus book source.
BookSource _source() => BookSource.fromLegadoJson(
  jsonDecode(File(_sourceFixture).readAsStringSync()) as Map<String, Object?>,
);

/// Reads one page of the offline corpus.
String _page(String name) =>
    File('test/fixtures/html/$name').readAsStringSync();

/// Builds the page service under test around [http].
PageFetchService _service(FakeHttpClient http) {
  final AppLogger logger = AppLogger(
    level: LogLevel.debug,
    printer: FakeLogPrinter(),
  );

  return PageFetchService(
    engine: RuleEngine(
      logger: logger,
      jsBridge: FakeJsBridge(),
      variables: JsVariableStore(),
    ),
    http: http,
    logger: logger,
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
  group('FetchBookInfo', () {
    test('execute_givenBookPage_readsEveryField', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_bookUrl, _page('book_page.html'));

      final BookInfo info = _data(
        await FetchBookInfo(pages: _service(http)).execute(_source(), _bookUrl),
      );

      expect(http.requestedUrls, <String>[_bookUrl]);
      expect(http.requestedRulePaths, <String>['ruleBookInfo']);
      expect(info.name, '书名一');
      expect(info.url, _bookUrl);
      expect(info.author, '作 者：作者甲');
      expect(info.intro, '这是简介第一段。');
      expect(info.coverUrl, 'https://example-novel.test/img/1.jpg');
      // 书源没有 `tocUrl` 规则 → 目录就在书籍页本身。
      expect(info.tocUrl, _bookUrl);
    });

    test('execute_givenTocUrlRule_resolvesItAgainstTheBookUrl', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_bookUrl, _page('book_page.html'));
      final BookSource source = _source();
      final BookSource withTocRule = source.copyWith(
        bookInfoRule: source.bookInfoRule?.copyWith(tocUrl: 'tag.a.0@href'),
      );

      final BookInfo info = _data(
        await FetchBookInfo(pages: _service(http))
            .execute(withTocRule, _bookUrl),
      );

      expect(info.tocUrl, 'https://example-novel.test/book/1/1.html');
    });

    test('execute_givenHttpFailure_returnsTheSameFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_bookUrl, ParseFailureKind.notFound);

      final ParseFailure<Never> failure = _failure(
        await FetchBookInfo(pages: _service(http)).execute(_source(), _bookUrl),
      );

      expect(failure.kind, ParseFailureKind.notFound);
      expect(failure.rulePath, 'ruleBookInfo');
    });

    test(
      'execute_givenUnsupportedFieldRule_degradesToEmptyWithAWarning',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_bookUrl, _page('book_page.html'));
        final BookSource source = _source();
        final BookSource withJs = source.copyWith(
          bookInfoRule: source.bookInfoRule?.copyWith(intro: '@xpath://div'),
        );
        final FakeLogPrinter printer = FakeLogPrinter();
        final AppLogger logger = AppLogger(
          level: LogLevel.debug,
          printer: printer,
        );

        final ParseResult<BookInfo> result = await FetchBookInfo(
          pages: PageFetchService(
            engine: RuleEngine(
              logger: logger,
              jsBridge: FakeJsBridge(),
              variables: JsVariableStore(),
            ),
            http: http,
            logger: logger,
          ),
        ).execute(withJs, _bookUrl);

        // ADR-0026 §决策 2：非顶层字段被拒 → 置空 + warning，整页照常返回。
        expect(result.dataOrNull, isNotNull);
        expect(result.dataOrNull?.intro, isNull);
        expect(
          printer.events.last.message.toString(),
          allOf(contains('bookInfoRule.intro'), contains(source.url)),
        );
      },
    );

    test(
      'execute_givenMalformedFieldRule_degradesToEmptyWithAWarning',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_bookUrl, _page('book_page.html'));
        final BookSource source = _source();
        // ADR-0026 §决策 2 的复审修订：非顶层字段**畸形**（`tag@text` 的选择器段缺名称 →
        // parseFailed）与「被拒」同口径降级 —— 若上抛，调用方只取 dataOrNull，会静默变成 null。
        // 注意单段值规则（如 `class.`）是**属性名**而不是选择器，不会走到这条路径。
        final BookSource malformed = source.copyWith(
          bookInfoRule: source.bookInfoRule?.copyWith(intro: 'tag@text'),
        );
        final FakeLogPrinter printer = FakeLogPrinter();
        final AppLogger logger = AppLogger(
          level: LogLevel.debug,
          printer: printer,
        );

        final ParseResult<BookInfo> result = await FetchBookInfo(
          pages: PageFetchService(
            engine: RuleEngine(
              logger: logger,
              jsBridge: FakeJsBridge(),
              variables: JsVariableStore(),
            ),
            http: http,
            logger: logger,
          ),
        ).execute(malformed, _bookUrl);

        expect(result.dataOrNull, isNotNull);
        expect(result.dataOrNull?.intro, isNull);
        expect(
          printer.events.last.message.toString(),
          allOf(
            contains('bookInfoRule.intro'),
            contains(ParseFailureKind.parseFailed.name),
            contains(source.url),
          ),
        );
      },
    );

    test(
      'execute_givenSourceWithoutBookInfoRules_returnsEmptyFields',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_bookUrl, _page('book_page.html'));
        final BookSource source = _source();

        final BookInfo info = _data(
          await FetchBookInfo(pages: _service(http))
              .execute(source.copyWith(bookInfoRule: null), _bookUrl),
        );

        expect(info.name, isEmpty);
        expect(info.author, isNull);
        expect(info.tocUrl, _bookUrl);
      },
    );
    test('execute_givenAnUpdateTimeRule_carriesItOnTheBookInfo', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _bookUrl,
          '<div id="info"><p class="time">2026/10/13 09:05</p></div>',
        );
      final BookSource source = _source();
      final BookSource withUpdateTime = source.copyWith(
        bookInfoRule: (source.bookInfoRule ?? const BookInfoRule()).copyWith(
          updateTime: 'class.time@text',
        ),
      );

      final BookInfo info = _data(
        await FetchBookInfo(pages: _service(http))
            .execute(withUpdateTime, _bookUrl),
      );

      // 展示用字符串：规则结果原文，模型不做日期解析（book-source.md §2）。
      expect(info.updateTime, '2026/10/13 09:05');
    });
    test('execute_givenACanReNameRule_reportsItWithoutEvaluatingIt', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_bookUrl, '<div id="info"><p>x</p></div>');
      final BookSource source = _source();
      final BookSource withRename = source.copyWith(
        bookInfoRule: (source.bookInfoRule ?? const BookInfoRule()).copyWith(
          // 规则内容本身不会被求值（上游 `BookInfo.kt:65`）——它甚至不是一条可跑的规则。
          canReName: '随便什么字符串',
        ),
      );

      final BookInfo info = _data(
        await FetchBookInfo(pages: _service(http))
            .execute(withRename, _bookUrl),
      );

      expect(info.canReName, isTrue);
    });

    test('execute_givenNoCanReNameRule_reportsFalse', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_bookUrl, '<div id="info"><p>x</p></div>');

      final BookInfo info = _data(
        await FetchBookInfo(pages: _service(http)).execute(_source(), _bookUrl),
      );

      expect(info.canReName, isFalse);
    });

    test('declaresCanReName_givenBlankOrMissingText_isFalse', () {
      // 上游判的是「字段非空白」（`BookInfo.kt:65`）：空白、空串、缺失都不算声明。
      expect(declaresCanReName(null), isFalse);
      expect(declaresCanReName(const BookInfoRule()), isFalse);
      expect(declaresCanReName(const BookInfoRule(canReName: '')), isFalse);
      expect(declaresCanReName(const BookInfoRule(canReName: '   ')), isFalse);
      expect(declaresCanReName(const BookInfoRule(canReName: 'true')), isTrue);
    });
  });
}
