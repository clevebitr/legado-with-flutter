import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../support/fake_log_printer.dart';

/// An engine-side logger that captures records, so a test can assert the warning.
({AppLogger logger, FakeLogPrinter printer}) _logger() {
  final FakeLogPrinter printer = FakeLogPrinter();

  return (
    logger: AppLogger(level: LogLevel.debug, printer: printer),
    printer: printer,
  );
}

/// Renders [template] with [params] and returns both the result and the records.
({String url, List<String> warnings}) _render(
  String template,
  Map<String, String> params,
) {
  final ({AppLogger logger, FakeLogPrinter printer}) captured = _logger();
  final String url = renderUrlTemplate(
    template,
    params,
    logger: captured.logger,
  );

  return (
    url: url,
    warnings: captured.printer.events
        .map((LogEvent event) => event.message.toString())
        .toList(),
  );
}

void main() {
  group('renderUrlTemplate', () {
    test('renderUrlTemplate_givenKeyAndPage_replacesBothPlaceholders', () {
      final ({String url, List<String> warnings}) result = _render(
        '/search?q={{key}}&page={{page}}',
        <String, String>{'key': '剑来', 'page': '2'},
      );

      expect(result.url, '/search?q=%E5%89%91%E6%9D%A5&page=2');
      expect(result.warnings, isEmpty);
    });

    test('renderUrlTemplate_givenKeywordWithSpace_formEncodesItAsPlus', () {
      // 上游 `URLEncoder.encode` 把空格转成 `+`（表单编码），不是 `%20`。
      final ({String url, List<String> warnings}) result = _render(
        '/search?q={{key}}',
        <String, String>{'key': 'a b'},
      );

      expect(result.url, '/search?q=a+b');
    });

    test('renderUrlTemplate_givenKeywordWithUnsafeCharacters_encodesThem', () {
      // `!` / `'` / `~` 在 Java 的 URLEncoder 下也会被编码，与 Dart 的
      // `Uri.encodeQueryComponent` 不同，因此这里按上游逐字节编码。
      final ({String url, List<String> warnings}) result = _render(
        '/search?q={{key}}',
        <String, String>{'key': "a!b'c~d"},
      );

      expect(result.url, '/search?q=a%21b%27c%7Ed');
    });

    test('renderUrlTemplate_givenAlreadyEncodedKeyword_keepsItUntouched', () {
      // 「只编码一次」：`%XX` 形式（上游 `encodedForm` 认得的形态）不得再编码。
      final ({String url, List<String> warnings}) result = _render(
        '/search?q={{key}}',
        <String, String>{'key': 'a%20b%E5%89%91'},
      );

      expect(result.url, '/search?q=a%20b%E5%89%91');
    });

    test('renderUrlTemplate_givenKeywordWithPlus_encodesThePlus', () {
      // 上游的「已编码」判定不接受 `+`，所以 `+` 会被再编码成 `%2B`——这是上游
      // 行为，调用方因此必须传**原始**关键词（本文件与 UseCase 的契约）。
      final ({String url, List<String> warnings}) result = _render(
        '/search?q={{key}}',
        <String, String>{'key': 'a+b'},
      );

      expect(result.url, '/search?q=a%2Bb');
    });

    test('renderUrlTemplate_givenInvalidEscape_encodesThePercent', () {
      final ({String url, List<String> warnings}) result = _render(
        '/search?q={{key}}',
        <String, String>{'key': 'a%ZZ'},
      );

      expect(result.url, '/search?q=a%25ZZ');
    });

    test('renderUrlTemplate_givenBaseUrl_insertsItWithoutEncoding', () {
      final ({String url, List<String> warnings}) result = _render(
        '{{baseUrl}}/search?q={{key}}',
        <String, String>{
          'baseUrl': 'https://example-novel.test/book/1',
          'key': 'a b',
        },
      );

      expect(result.url, 'https://example-novel.test/book/1/search?q=a+b');
    });

    test('renderUrlTemplate_givenUndefinedVariable_rendersEmptyAndWarns', () {
      final ({String url, List<String> warnings}) result = _render(
        '/search?q={{key}}&x={{unknown}}',
        <String, String>{'key': 'abc'},
      );

      expect(result.url, '/search?q=abc&x=');
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single, contains('unknown'));
      // 模板原文不得进入日志：它可能已经带上关键词（C-ERR-8、C-SEC-4）。
      expect(result.warnings.single, isNot(contains('abc')));
    });

    test('renderUrlTemplate_givenEmptyPlaceholder_treatsItAsUndefined', () {
      final ({String url, List<String> warnings}) result = _render(
        '/search?q={{}}',
        <String, String>{'key': 'abc'},
      );

      expect(result.url, '/search?q=');
      expect(result.warnings, hasLength(1));
    });

    test(
      'renderUrlTemplate_givenNestedRulePlaceholder_treatsItAsUndefined',
      () {
        // 矩阵 #18（`{{}}` 内嵌规则 / JS）是 M1：本阶段按「未定义变量」处理，
        // 即空串 + warning，而不是把 `{{...}}` 原样写进请求。PLAN.md 已登记该边界。
        final ({String url, List<String> warnings}) result = _render(
          '/search?q={{java.encodeURI(key)}}',
          <String, String>{'key': 'abc'},
        );

        expect(result.url, '/search?q=');
        expect(result.warnings, hasLength(1));
      },
    );

    test('renderUrlTemplate_givenNoPlaceholder_returnsTheTemplateAsIs', () {
      final ({String url, List<String> warnings}) result = _render(
        '/search?q=fixed',
        <String, String>{'key': 'abc'},
      );

      expect(result.url, '/search?q=fixed');
      expect(result.warnings, isEmpty);
    });

    test('renderUrlTemplate_givenSeveralUndefinedVariables_warnsOnce', () {
      final ({String url, List<String> warnings}) result = _render(
        '/search?q={{key}}&a={{one}}&b={{two}}',
        <String, String>{'key': 'abc'},
      );

      expect(result.url, '/search?q=abc&a=&b=');
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single, contains('one'));
      expect(result.warnings.single, contains('two'));
    });
  });

  group('resolveAbsoluteUrl', () {
    test('resolveAbsoluteUrl_givenRelativeTarget_resolvesItAgainstTheBase', () {
      expect(
        resolveAbsoluteUrl('/book/1', 'https://example-novel.test/search?q=x'),
        'https://example-novel.test/book/1',
      );
      expect(
        resolveAbsoluteUrl('2.html', 'https://example-novel.test/book/1/'),
        'https://example-novel.test/book/1/2.html',
      );
    });

    test('resolveAbsoluteUrl_givenAbsoluteTarget_keepsIt', () {
      expect(
        resolveAbsoluteUrl(
          'https://other.test/a',
          'https://example-novel.test/',
        ),
        'https://other.test/a',
      );
    });

    test('resolveAbsoluteUrl_givenUnparsableValue_returnsItUnchanged', () {
      // 规则输出畸形时不得抛异常（C-ERR-1）：调用方把它当数据问题报出去。
      expect(
        resolveAbsoluteUrl('http://[bad', 'https://example-novel.test/'),
        'http://[bad',
      );
    });

    test('resolveAbsoluteUrlOrNull_givenAbsentValue_returnsNull', () {
      expect(
        resolveAbsoluteUrlOrNull(null, 'https://example-novel.test/'),
        isNull,
      );
      expect(
        resolveAbsoluteUrlOrNull('', 'https://example-novel.test/'),
        isNull,
      );
    });

    test('resolveAbsoluteUrlOrNull_givenRelativeValue_resolvesIt', () {
      expect(
        resolveAbsoluteUrlOrNull(
          '/img/1.jpg',
          'https://example-novel.test/book/1/',
        ),
        'https://example-novel.test/img/1.jpg',
      );
    });
  });
}
