import 'package:flutter_reader/core/logging/redaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactHeaders', () {
    test('redactHeaders_whenHeaderIsSensitive_masksItsValue', () {
      final Map<String, String> redacted = redactHeaders(<String, String>{
        'Cookie': 'session=abc',
        'Authorization': 'Bearer abc',
        'X-Api-Key': 'key-123',
        'Accept': 'text/html',
      });

      expect(redacted['Cookie'], '***');
      expect(redacted['Authorization'], '***');
      expect(redacted['X-Api-Key'], '***');
      expect(redacted['Accept'], 'text/html');
    });

    test('redactHeaders_whenHeaderNameHasPadding_masksItsValue', () {
      final Map<String, String> redacted = redactHeaders(<String, String>{
        ' Cookie ': 'session=abc',
      });

      expect(redacted[' Cookie '], '***');
    });

    test('redactHeaders_whenCalled_leavesTheInputUntouched', () {
      final Map<String, String> headers = <String, String>{
        'Cookie': 'session=abc',
      };

      redactHeaders(headers);

      expect(headers['Cookie'], 'session=abc');
    });
  });

  group('redactUrl', () {
    test('redactUrl_whenQueryIsPresent_masksEveryValueButKeepsNames', () {
      expect(
        redactUrl('https://example.com/search?q=%E5%A4%A9&page=2'),
        'https://example.com/search?q=***&page=***',
      );
    });

    test('redactUrl_whenQueryIsAbsent_returnsTheUrlUnchanged', () {
      expect(
        redactUrl('https://example.com/book/1'),
        'https://example.com/book/1',
      );
    });

    test('redactUrl_whenKeywordIsGiven_masksItsPathRendering', () {
      expect(
        redactUrl('https://example.com/search/%E5%A4%A9?page=1', keyword: '天'),
        'https://example.com/search/***?page=***',
      );
    });

    test('redactUrl_whenKeywordIsGiven_masksItsRawRendering', () {
      expect(
        redactUrl('https://example.com/search/hello?page=1', keyword: 'hello'),
        'https://example.com/search/***?page=***',
      );
    });

    test('redactUrl_whenKeywordAlsoOccursInTheHost_keepsTheHost', () {
      expect(
        redactUrl('https://example.com/search?q=1', keyword: 'com'),
        'https://example.com/search?q=***',
      );
    });

    test('redactUrl_whenKeywordIsASingleCharacter_masksThePathSegment', () {
      expect(
        redactUrl('https://example.com/a?q=1', keyword: 'a'),
        'https://example.com/***?q=***',
      );
    });

    test('redactUrl_whenKeywordIsPartOfASegment_masksOnlyThatPart', () {
      expect(
        redactUrl(
          'https://example.com/search/hello-world?page=1',
          keyword: 'hello',
        ),
        'https://example.com/search/***-world?page=***',
      );
    });

    test('redactUrl_whenKeywordIsBlank_keepsThePath', () {
      expect(
        redactUrl('https://example.com/a?q=1', keyword: '  '),
        'https://example.com/a?q=***',
      );
    });

    test('redactUrl_whenUrlCarriesUserInfo_masksTheCredentials', () {
      expect(
        redactUrl('https://user:pass@example.com/book/1'),
        'https://***@example.com/book/1',
      );
    });

    test('redactUrl_whenPathFollowsASensitiveName_masksOnlyThatSegment', () {
      expect(
        redactUrl('https://example.com/token/abc123/book/1'),
        'https://example.com/token/***/book/1',
      );
      expect(
        redactUrl('https://example.com/api_key/abc123'),
        'https://example.com/api_key/***',
      );
    });

    test('redactUrl_whenPathEndsWithASensitiveName_keepsIt', () {
      expect(
        redactUrl('https://example.com/token'),
        'https://example.com/token',
      );
    });

    test('redactUrl_whenUrlCannotBeParsed_returnsAPlaceholder', () {
      expect(redactUrl('http://[bad'), '<unparsable-url>');
    });

    test('redactUrl_whenQueryCannotBeDecoded_stillReturnsAMaskedUrl', () {
      // 真实书源会把关键词按 GBK 编码写进模板，或由 JS 拼出非法字节：
      // `queryParameters` 对这类值抛 FormatException，而打日志绝不能成为请求失败的原因。
      expect(
        redactUrl('https://example.com/s?q=%FF%FE&page=1'),
        'https://example.com/s?q=***&page=***',
      );
      expect(
        redactUrl('https://example.com/s?%FF'),
        'https://example.com/s?***',
      );
    });
  });

  group('describeKeyword', () {
    test('describeKeyword_whenCalled_reportsLengthAndDigestOnly', () {
      expect(describeKeyword('abc'), '<keyword: 3 chars, sha256=ba7816bf>');
    });

    test('describeKeyword_whenCalled_neverEchoesTheKeyword', () {
      expect(describeKeyword('secret-keyword'), isNot(contains('secret')));
    });

    test('describeKeyword_whenCalledTwiceWithTheSameInput_isStable', () {
      expect(describeKeyword('天'), describeKeyword('天'));
    });
  });

  group('describePayload', () {
    test('describePayload_whenCalled_reportsLengthAndDigestOnly', () {
      final String described = describePayload(
        '<html><body>secret</body></html>',
      );

      expect(described, startsWith('<payload: 32 chars, sha256='));
      expect(described, isNot(contains('secret')));
    });
  });

  group('describeError', () {
    test('describeError_whenExceptionEmbedsAUrl_neverEchoesItsText', () {
      final String described = describeError(
        const FormatException('GET https://example.com/a?token=abc failed'),
      );

      expect(described, startsWith('<FormatException: '));
      expect(described, contains('chars, sha256='));
      expect(described, isNot(contains('example.com')));
      expect(described, isNot(contains('abc')));
    });

    test('describeError_whenCalledForEquivalentErrors_isStable', () {
      expect(
        describeError(const FormatException('broken payload')),
        describeError(const FormatException('broken payload')),
      );
    });
  });

  group('redactMessage', () {
    test('redactMessage_whenAssignmentIsSensitive_masksTheValue', () {
      expect(
        redactMessage('GET https://example.com/a?token=abc123 failed'),
        'GET https://example.com/a?token=*** failed',
      );
    });

    test('redactMessage_whenHeaderLikePairIsSensitive_masksTheValue', () {
      expect(redactMessage('Cookie: session=abc'), 'Cookie: ***');
    });

    test('redactMessage_whenJsonPairIsSensitive_masksTheValue', () {
      expect(redactMessage('{"api_key": "abc123"}'), '{"api_key": "***"}');
    });

    test('redactMessage_whenPathFollowsASensitiveName_masksTheValue', () {
      expect(
        redactMessage('GET https://example.com/token/abc123 failed'),
        'GET https://example.com/token/*** failed',
      );
    });

    test('redactMessage_whenUserInfoIsPresent_masksTheCredentials', () {
      expect(
        redactMessage('GET https://user:pass@example.com/book failed'),
        'GET https://user:***@example.com/book failed',
      );
    });

    test('redactMessage_whenBearerCredentialIsPresent_masksIt', () {
      expect(
        redactMessage('Authorization: Bearer abc123'),
        'Authorization: *** ***',
      );
      expect(
        redactMessage('GET /x with Basic dXNlcjpwYXNz'),
        'GET /x with Basic ***',
      );
    });

    test('redactMessage_whenNameIsHyphenated_masksItsValue', () {
      expect(redactMessage('x-token=abc123'), 'x-token=***');
    });

    test('redactMessage_whenAssignmentIsHarmless_keepsTheMessage', () {
      expect(
        redactMessage('page=3 returned 0 items'),
        'page=3 returned 0 items',
      );
    });

    test('redactMessage_whenSensitiveWordHasNoAssignment_keepsTheMessage', () {
      expect(
        redactMessage('signature verification failed'),
        'signature verification failed',
      );
    });
  });
}
