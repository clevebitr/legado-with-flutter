import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/capturing_log_printer.dart';
import '../../../../support/fake_http_client.dart';

/// The real default-rule source of the offline corpus.
const String _sourceFixture =
    'test/fixtures/book_sources/legado_default_rules_source.json';

/// The book URL that carries the chapter list in the corpus.
const String _tocUrl = 'https://example-novel.test/book/1/';

/// Loads the corpus book source.
BookSource _source() => BookSource.fromLegadoJson(
  jsonDecode(File(_sourceFixture).readAsStringSync()) as Map<String, Object?>,
);

/// Reads one page of the offline corpus.
String _page(String name) =>
    File('test/fixtures/html/$name').readAsStringSync();

/// Builds the page service under test around [http].
({PageFetchService pages, CapturingLogPrinter printer}) _service(
  FakeHttpClient http,
) {
  final CapturingLogPrinter printer = CapturingLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);

  return (
    pages: PageFetchService(
      engine: RuleEngine(logger: logger),
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
      final ({PageFetchService pages, CapturingLogPrinter printer}) service =
          _service(http);

      final List<Chapter> chapters = _data(
        await FetchToc(pages: service.pages).execute(_source(), _tocUrl),
      );

      expect(chapters, hasLength(1));
      expect(chapters.single.name, '第1章');
      expect(service.printer.events, hasLength(1));
    });

    test(
      'execute_givenUnsupportedFieldRule_propagatesUnsupportedRule',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_tocUrl, _page('book_page.html'));
        final BookSource source = _source();
        final BookSource withCss = source.copyWith(
          tocRule: source.tocRule.copyWith(chapterName: '@css:a @text'),
        );

        final ParseFailure<Never> failure = _failure(
          await FetchToc(pages: _service(http).pages).execute(withCss, _tocUrl),
        );

        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@css:');
      },
    );
  });
}
