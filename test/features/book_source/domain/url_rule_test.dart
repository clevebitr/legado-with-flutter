import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/url_rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parses [rule] and returns the value, failing the test on a rejection.
UrlRule _parse(String rule) {
  final ParseResult<UrlRule> result = parseUrlRule(rule, rulePath: 'searchUrl');

  return (result as ParseSuccess<UrlRule>).data;
}

void main() {
  group('resolveUrlRule', () {
    test('resolveUrlRule_givenAnOptionSuffix_keepsItOutsideTheUrl', () {
      // 先绝对化会把 `{` 编码成 `%7B`，选项就变成路径的一部分（M17 真源普查的 404）。
      expect(
        resolveUrlRule('/book/1258-1,{webView:“true”}', 'https://ting55.com/'),
        'https://ting55.com/book/1258-1,{webView:“true”}',
      );
    });

    test('resolveUrlRule_givenAPlainRelativeUrl_resolvesIt', () {
      expect(
        resolveUrlRule('c1.html', 'https://a.test/book/1/'),
        'https://a.test/book/1/c1.html',
      );
    });

    test('resolveUrlRule_givenAnAbsoluteUrlWithOptions_keepsThem', () {
      expect(
        resolveUrlRule(
          'https://a.test/1.html,{"method":"GET"}',
          'https://ignored.test/',
        ),
        'https://a.test/1.html,{"method":"GET"}',
      );
    });
  });

  group('parseUrlRule', () {
    test('parseUrlRule_givenAPlainTemplate_hasNoOptions', () {
      final UrlRule rule = _parse('https://a.test/s?q={{key}}&p={{page}}');

      expect(rule.template, 'https://a.test/s?q={{key}}&p={{page}}');
      expect(rule.options, isNull);
    });

    test('parseUrlRule_givenAPostSuffix_readsTheMethodAndTheBody', () {
      // 真实语料的主流形态（50/128 条 searchUrl 带 `,{…}`）。
      final UrlRule rule = _parse(
        '/modules/article/search.php,{   "method": "POST",   '
        '"body": "searchkey={{key}}" }',
      );

      expect(rule.template, '/modules/article/search.php');
      expect(rule.options?.method, UrlRequestMethod.post);
      expect(rule.options?.body, 'searchkey={{key}}');
      expect(rule.options?.unsupported, isEmpty);
    });

    test('parseUrlRule_givenACharsetSuffix_readsTheLabel', () {
      final UrlRule rule = _parse(
        '/modules/article/search.php?searchkey={{key}},{"charset":"gbk"}',
      );

      expect(rule.options?.charset, 'gbk');
      expect(rule.options?.method, UrlRequestMethod.get);
    });

    test('parseUrlRule_givenSingleQuotesAndUnquotedKeys_stillReadsThem', () {
      // 真实书源写的是 GSON 宽松语法，不是严格 JSON。
      final UrlRule rule = _parse(
        "https://a.test/search,{ 'method': 'POST', "
        "body: 'kw={{key}}', charset: 'gbk' }",
      );

      expect(rule.options?.method, UrlRequestMethod.post);
      expect(rule.options?.body, 'kw={{key}}');
      expect(rule.options?.charset, 'gbk');
    });

    test('parseUrlRule_givenAJsonBodyObject_keepsTheTemplatesInPlace', () {
      // `{{key}}` 让这段文本不是合法 JSON：解析器必须把它当模板保留。
      final UrlRule rule = _parse(
        'https://a.test/v1/search,{"method":"POST",'
        '"body":{"keyword":{{key}},"page_index":{{page}},"page_size":20}}',
      );

      expect(rule.options?.method, UrlRequestMethod.post);
      expect(
        rule.options?.body,
        '{"keyword":{{key}},"page_index":{{page}},"page_size":20}',
      );
    });

    test('parseUrlRule_givenSuffixHeaders_mergesThemIntoTheRequest', () {
      final UrlRule rule = _parse(
        'https://a.test/s?k={{key}},{"headers":{"Referer":"https://a.test/"}}',
      );

      expect(rule.options?.headers, <String, String>{
        'Referer': 'https://a.test/',
      });
    });

    test('parseUrlRule_givenHeadersAsAString_readsTheNestedObject', () {
      // `,{ "headers": "{os:'pc'}" }`：headers 被写成一个字符串。
      final UrlRule rule = _parse(
        'https://a.test/s?k={{key}},{"headers":"{os:\'pc\'}"}',
      );

      expect(rule.options?.headers, <String, String>{'os': 'pc'});
    });

    test('parseUrlRule_givenWebView_modelsIt', () {
      // M21a（ADR-0068 §决策 6）：`webView` 从「被忽略的选项」变成字段。
      final UrlRule rule = _parse(
        'https://a.test/s?k={{key}},{"webView":true}',
      );

      expect(rule.options?.webView, isTrue);
      expect(rule.options?.unsupported, isNot(contains('webView')));
    });

    test('parseUrlRule_givenTheWebViewFamily_modelsDelayJsAndOverride', () {
      final UrlRule rule = _parse(
        'https://a.test/s?k={{key}},{"webView":true,"webViewDelayTime":800,'
        '"webJs":"document.body.innerText","overrideUrlRegex":"/result"}',
      );

      expect(rule.options?.webViewDelayTime, const Duration(milliseconds: 800));
      expect(rule.options?.webJs, 'document.body.innerText');
      expect(rule.options?.overrideUrlRegex, '/result');
      expect(rule.options?.unsupported, isEmpty);
    });

    test('parseUrlRule_givenRetryAndReadTimeout_capsThem', () {
      // 上限在这里就钳住：`retry` ≤ 3（C-NET-2），`readTimeout` ≤ 120 s（ADR-0068 §决策 8）。
      final UrlRule rule = _parse(
        'https://a.test/s?k={{key}},{"retry":9,"readTimeout":999999}',
      );

      expect(rule.options?.retry, 3);
      expect(rule.options?.readTimeout, const Duration(seconds: 120));
    });

    test('parseUrlRule_givenABodyWithAGet_reportsTheIgnoredBody', () {
      final UrlRule rule = _parse('https://a.test/s?k={{key}},{"body":"a=1"}');

      expect(rule.options?.body, isNull);
      expect(rule.options?.unsupported, contains('body'));
    });

    test('parseUrlRule_givenAnUnknownVerb_degradesToGetAndReportsIt', () {
      final UrlRule rule = _parse(
        'https://a.test/s?k={{key}},{"method":"HEAD"}',
      );

      expect(rule.options?.method, UrlRequestMethod.get);
      expect(rule.options?.unsupported, contains('method:HEAD'));
    });

    test('parseUrlRule_givenHeadersThatAreNotAnObject_reportsTheField', () {
      final UrlRule rule = _parse(
        'https://a.test/s?k={{key}},{"headers":"not an object"}',
      );

      expect(rule.options?.headers, isEmpty);
      expect(rule.options?.unsupported, contains('headers'));
    });

    test('parseUrlRule_givenAHeadersStringThatIsNotJson_reportsTheField', () {
      // `"headers": "{oops"`：以 `{` 开头但不是对象，宽松扫描器失败后按字段报出来。
      final UrlRule rule = _parse(
        'https://a.test/s?k={{key}},{"headers":"{oops"}',
      );

      expect(rule.options?.headers, isEmpty);
      expect(rule.options?.unsupported, contains('headers'));
    });

    test('parseUrlRule_givenAnArrayValue_keepsItAsRawText', () {
      final UrlRule rule = _parse(
        'https://a.test/s?k={{key}},{"origin":[1,2],"method":"GET"}',
      );

      expect(rule.options?.unsupported, contains('origin'));
      expect(rule.options?.method, UrlRequestMethod.get);
    });

    test('parseUrlRule_givenEscapesInAString_decodesThem', () {
      final UrlRule rule = _parse(
        r'https://a.test/s?k={{key}},{"method":"POST","body":"a=\tb\nc"}',
      );

      expect(rule.options?.body, 'a=\tb\nc');
    });

    test('parseUrlRule_givenAnArrayWithEscapedQuotes_keepsItRaw', () {
      // 数组值里的字符串可以带转义引号：宽松扫描器要按“在字符串里”跳过它。
      final UrlRule rule = _parse(
        r'https://a.test/s?k={{key}},{"origin":["a\"b",2],"method":"GET"}',
      );

      expect(rule.options?.unsupported, contains('origin'));
    });

    test('parseUrlRule_givenAnUnbalancedValue_rejectsItByName', () {
      final ParseResult<UrlRule> result = parseUrlRule(
        'https://a.test/s?k={{key}},{"retry":[1,2}',
        rulePath: 'searchUrl',
      );

      expect(result, isA<ParseFailure<UrlRule>>());
    });

    test('parseUrlRule_givenAnUnterminatedTemplate_rejectsItByName', () {
      final ParseResult<UrlRule> result = parseUrlRule(
        'https://a.test/s?k={{key}},{"body":{{key}',
        rulePath: 'searchUrl',
      );

      expect(result, isA<ParseFailure<UrlRule>>());
    });

    test('parseUrlRule_givenAnUnreadableSuffix_rejectsItByName', () {
      final ParseResult<UrlRule> result = parseUrlRule(
        'https://a.test/s?k={{key}},{oops}',
        rulePath: 'searchUrl',
      );

      expect(result, isA<ParseFailure<UrlRule>>());
      expect(
        (result as ParseFailure<UrlRule>).kind,
        ParseFailureKind.unsupportedRule,
      );
      expect(result.rulePath, 'unsupported:url-options');
    });

    test('parseUrlRule_givenACommaInsideTheAddress_keepsItAsTheUrl', () {
      // 地址里的逗号 + 花括号不是选项：必须整段留在 URL 里。
      final UrlRule rule = _parse('https://a.test/s?q={{key}},1');

      expect(rule.template, 'https://a.test/s?q={{key}},1');
      expect(rule.options, isNull);
    });
  });
}
