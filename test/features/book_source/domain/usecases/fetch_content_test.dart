import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/capturing_log_printer.dart';
import '../../../../support/fake_http_client.dart';

/// The real default-rule source of the offline corpus.
const String _sourceFixture =
    'test/fixtures/book_sources/legado_default_rules_source.json';

/// A chapter URL of the corpus.
const String _chapterUrl = 'https://example-novel.test/book/1/1.html';

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
    printer: CapturingLogPrinter(),
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
  group('FetchContent', () {
    test('execute_givenChapterPage_returnsThePlainTextBody', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, _page('chapter_page.html'));

      final String content = _data(
        await FetchContent(pages: _service(http))
            .execute(_source(), _chapterUrl),
      );

      expect(http.requestedUrls, <String>[_chapterUrl]);
      expect(http.requestedRulePaths, <String>['ruleContent']);
      expect(content, '正文第一段。\n正文第二段。\n正文第三段。');
    });

    test('execute_givenHttpFailure_returnsTheSameFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_chapterUrl, ParseFailureKind.networkForbidden);

      final ParseFailure<Never> failure = _failure(
        await FetchContent(pages: _service(http))
            .execute(_source(), _chapterUrl),
      );

      expect(failure.kind, ParseFailureKind.networkForbidden);
      expect(failure.rulePath, 'ruleContent');
    });

    test('execute_givenPageWithoutContent_returnsParseFailed', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, '<html><body><p>空页</p></body></html>');

      final ParseFailure<Never> failure = _failure(
        await FetchContent(pages: _service(http))
            .execute(_source(), _chapterUrl),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'contentRule.content');
    });

    test(
      'execute_givenUnsupportedContentRule_propagatesUnsupportedRule',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve(_chapterUrl, _page('chapter_page.html'));
        final BookSource source = _source();
        final BookSource withCss = source.copyWith(
          contentRule: source.contentRule.copyWith(
            content: '@css:div#content @html',
          ),
        );

        final ParseFailure<Never> failure = _failure(
          await FetchContent(pages: _service(http))
              .execute(withCss, _chapterUrl),
        );

        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@css:');
      },
    );
  });
}
