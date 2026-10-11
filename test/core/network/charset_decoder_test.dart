import 'dart:convert';

import 'package:flutter_reader/core/network/charset_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// GBK bytes for 「天」, the kind of non-UTF-8 page Chinese book sources serve.
const List<int> _gbkTian = <int>[0xCC, 0xEC];

void main() {
  group('decodeBody', () {
    test('decodeBody_whenContentTypeDeclaresUtf8_decodesUtf8Bytes', () {
      expect(
        decodeBody(utf8.encode('天'), contentType: 'text/html; charset=utf-8'),
        '天',
      );
    });

    test('decodeBody_whenContentTypeDeclaresGbk_decodesGbkBytes', () {
      expect(decodeBody(_gbkTian, contentType: 'text/html; charset=GBK'), '天');
    });

    test('decodeBody_whenContentTypeQuotesTheCharset_decodesIt', () {
      expect(
        decodeBody(_gbkTian, contentType: 'text/html; charset="gbk"'),
        '天',
      );
    });

    test('decodeBody_whenMetaDeclaresGbk_decodesGbkBytes', () {
      final List<int> page = <int>[
        ...utf8.encode('<html><head><meta charset="gbk"></head><body>'),
        ..._gbkTian,
        ...utf8.encode('</body></html>'),
      ];

      expect(decodeBody(page), contains('天'));
    });

    test('decodeBody_whenMetaUsesHttpEquiv_decodesGbkBytes', () {
      final List<int> page = <int>[
        ...utf8.encode(
          '<meta http-equiv="Content-Type" content="text/html; charset=gbk">',
        ),
        ..._gbkTian,
      ];

      expect(decodeBody(page), contains('天'));
    });

    test('decodeBody_whenNothingIsDeclared_detectsUtf8', () {
      expect(decodeBody(utf8.encode('天')), '天');
    });

    test('decodeBody_whenDeclaredLabelIsUnknown_fallsBackToUtf8', () {
      expect(
        decodeBody(
          utf8.encode('天'),
          contentType: 'text/html; charset=x-unknown',
        ),
        '天',
      );
    });

    test('decodeBody_whenMetaSitsBeyondTheScanWindow_ignoresIt', () {
      final List<int> page = <int>[
        ...List<int>.filled(metaScanLimit, 0x20),
        ...utf8.encode('<meta charset="gbk">'),
      ];

      expect(decodeBody(page), contains('<meta charset="gbk">'));
    });

    test(
      'decodeBody_whenBytesAreInvalidForTheCharset_throwsFormatException',
      () {
        expect(
          () => decodeBody(<int>[
            0xFF,
            0xFE,
            0xFD,
          ], contentType: 'text/html; charset=utf-8'),
          throwsFormatException,
        );
      },
    );
  });
}
