import 'dart:convert';

import 'package:flutter_reader/core/text/charset_encoding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('charsetBytes', () {
    test('charsetBytes_givenAKnownCharset_encodesInIt', () {
      // GBK 的「美女」是 C3C0 / C5AE（与 UTF-8 的 E7BE8E / E5A5B3 不同）。
      expect(charsetBytes('美女', charset: 'gbk'), <int>[0xC3, 0xC0, 0xC5, 0xAE]);
    });

    test('charsetBytes_givenNoCharset_usesUtf8', () {
      expect(charsetBytes('美女'), utf8.encode('美女'));
      expect(charsetBytes('美女', charset: ''), utf8.encode('美女'));
    });

    test('charsetBytes_givenAnUnknownCharset_fallsBackToUtf8', () {
      // 源把 `GBK` 拼错时，退到 UTF-8 比抛错更有用：站点可能接受，抛错一定失败。
      expect(charsetBytes('美女', charset: 'not-a-charset'), utf8.encode('美女'));
    });
  });
}
