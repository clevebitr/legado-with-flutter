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
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
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
    engine: RuleEngine(logger: logger),
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
      'execute_givenUnsupportedFieldRule_propagatesUnsupportedRule',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_bookUrl, _page('book_page.html'));
        final BookSource source = _source();
        final BookSource withCss = source.copyWith(
          bookInfoRule: source.bookInfoRule?.copyWith(intro: '@css:p @text'),
        );

        final ParseFailure<Never> failure = _failure(
          await FetchBookInfo(pages: _service(http)).execute(withCss, _bookUrl),
        );

        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@css:');
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
  });
}
