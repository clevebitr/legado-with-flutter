import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyCryptoOperation', () {
    test('applyCryptoOperation_givenMd5_returnsTheHexDigest', () {
      // `md5('abc')` 是 RFC 1321 的公开测试向量。
      expect(
        applyCryptoOperation('md5', 'abc'),
        '900150983cd24fb0d6963f7d28e17f72',
      );
    });

    test('applyCryptoOperation_givenSha1_returnsTheHexDigest', () {
      expect(
        applyCryptoOperation('sha1', 'abc'),
        'a9993e364706816aba3e25717850c26c9cd0d89d',
      );
    });

    test('applyCryptoOperation_givenUtf8Text_encodesAndDecodesBase64', () {
      final String? encoded = applyCryptoOperation('base64Encode', '剑来');

      expect(encoded, isNotNull);
      // 非 ASCII 先按 UTF-8 编码，再 base64；解码走同一条路，因此能原样往返。
      expect(applyCryptoOperation('base64Decode', encoded as String), '剑来');
      expect(applyCryptoOperation('base64Decode', ''), isEmpty);
    });

    test('applyCryptoOperation_givenUnusableInput_returnsNull', () {
      // 未知操作、非 base64、base64 后不是 UTF-8：都是「没有值」，由 prelude 变成 JS Error。
      expect(applyCryptoOperation('sha256', 'abc'), isNull);
      expect(applyCryptoOperation('base64Decode', 'not base64!'), isNull);
      expect(applyCryptoOperation('base64Decode', '/w=='), isNull);
    });
  });
}
