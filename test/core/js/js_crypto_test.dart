import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_reader/core/js/js_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Calls one binding op, with the registry the worker would pass in.
Object? _call(Map<String, Object?> args, {JsSymmetricRegistry? ciphers}) =>
    applyJsCryptoCall(args, ciphers: ciphers ?? JsSymmetricRegistry());

String _text(Object? answer) => answer as String;

Uint8List _bytes(Object? answer) => answer as Uint8List;

/// The message of a failure envelope; fails the test when [answer] is not one.
String _error(Object? answer) {
  expect(answer, isA<Map<Object?, Object?>>());
  final Map<Object?, Object?> envelope = answer as Map<Object?, Object?>;
  expect(envelope, contains(jsCryptoErrorKey));

  return envelope[jsCryptoErrorKey] as String;
}

/// Creates a cipher and answers the handle id the sandbox would hold.
int _create(
  JsSymmetricRegistry registry,
  String transformation, {
  Object? key,
  Object? iv,
}) {
  final Object? answer = _call(<String, Object?>{
    'operation': 'symmetricCreate',
    'transformation': transformation,
    'key': key,
    'iv': iv,
  }, ciphers: registry);
  expect(answer, isA<Map<Object?, Object?>>());

  return (answer as Map<Object?, Object?>)['id']! as int;
}

/// Calls one method on an existing handle.
Object? _method(
  JsSymmetricRegistry registry,
  int id,
  String method,
  Object? value, {
  String? charset,
}) => _call(<String, Object?>{
  'operation': 'symmetricCall',
  'id': id,
  'method': method,
  'value': value,
  'charset': ?charset,
}, ciphers: registry);

void main() {
  group('applyJsCryptoCall digests', () {
    test('applyJsCryptoCall_givenMd5Encode16_answersTheMiddleSixteen', () {
      // `md5('abc')` = 900150983cd24fb0d6963f7d28e17f72；上游取第 9..24 位字符。
      expect(
        _call(<String, Object?>{'operation': 'md5Encode16', 'value': 'abc'}),
        '3cd24fb0d6963f7d',
      );
    });

    test('applyJsCryptoCall_givenDigestHex_answersTheLowercaseDigest', () {
      expect(
        _call(<String, Object?>{
          'operation': 'digestHex',
          'value': 'abc',
          'algorithm': 'SHA-256',
        }),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('applyJsCryptoCall_givenDigestBase64Str_answersBase64', () {
      expect(
        _call(<String, Object?>{
          'operation': 'digestBase64Str',
          'value': 'abc',
          'algorithm': 'sha256',
        }),
        'ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=',
      );
    });

    test('applyJsCryptoCall_givenHMacHex_answersTheHmac', () {
      // 已知向量由 `openssl dgst -sha256 -hmac key` 复算，key 是 UTF-8 字节。
      expect(
        _call(<String, Object?>{
          'operation': 'HMacHex',
          'value': 'The quick brown fox',
          'algorithm': 'HmacSHA256',
          'key': 'key',
        }),
        '203d1e5cedd2d18f8c5a3beff0bd9c1ebcb97097dfcb288c46b00c9227fde2c0',
      );
    });

    test('applyJsCryptoCall_givenHMacBase64_answersBase64', () {
      expect(
        _call(<String, Object?>{
          'operation': 'HMacBase64',
          'value': 'The quick brown fox',
          'algorithm': 'HmacSHA256',
          'key': 'key',
        }),
        'ID0eXO3S0Y+MWjvv8L2cHry5cJffyyiMRrAMkif94sA=',
      );
    });

    test('applyJsCryptoCall_givenUnknownAlgorithm_reportsIt', () {
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'digestHex',
            'value': 'abc',
            'algorithm': 'ROT13',
          }),
        ),
        contains('unsupported digest algorithm'),
      );
    });
  });

  group('applyJsCryptoCall byte codecs', () {
    test('applyJsCryptoCall_givenHexBytes_answersTheUtf8Text', () {
      expect(
        _call(<String, Object?>{
          'operation': 'hexDecodeToString',
          'value': 'e99885e8afbb',
        }),
        '阅读',
      );
    });

    test('applyJsCryptoCall_givenText_answersItsHex', () {
      expect(
        _call(<String, Object?>{
          'operation': 'hexEncodeToString',
          'value': '阅读',
        }),
        'e99885e8afbb',
      );
    });

    test('applyJsCryptoCall_givenOddHex_reportsTheLength', () {
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'hexDecodeToByteArray',
            'value': 'abc',
          }),
        ),
        contains('even number of characters'),
      );
    });

    test('applyJsCryptoCall_givenNonHex_reportsTheCharacter', () {
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'hexDecodeToByteArray',
            'value': 'zz',
          }),
        ),
        contains('non-hex character'),
      );
    });

    test('applyJsCryptoCall_givenUrlSafeBase64_decodesIt', () {
      // hutool 的宽容解码器（上游 `base64ToByteArray`）：`-`/`_`、缺填充、空白都接受。
      final Uint8List bytes = _bytes(
        _call(<String, Object?>{
          'operation': 'base64DecodeToByteArray',
          'value': ' Pz8-Pw\n',
        }),
      );
      expect(bytes, <int>[0x3F, 0x3F, 0x3E, 0x3F]);
    });

    test('applyJsCryptoCall_givenBlankBase64_answersNull', () {
      expect(
        _call(<String, Object?>{
          'operation': 'base64DecodeToByteArray',
          'value': '   ',
        }),
        isNull,
      );
    });

    test('applyJsCryptoCall_givenCharsetBytes_roundTripsThroughText', () {
      final Object? bytes = _call(<String, Object?>{
        'operation': 'strToBytes',
        'value': '阅读',
        'charset': 'UTF-8',
      });
      expect(_bytes(bytes), utf8.encode('阅读'));
      expect(
        _call(<String, Object?>{
          'operation': 'bytesToStr',
          'value': bytes,
          'charset': 'UTF-8',
        }),
        '阅读',
      );
    });

    test('applyJsCryptoCall_givenNonStringOperation_reportsIt', () {
      expect(
        _error(_call(<String, Object?>{'operation': 5})),
        contains('malformed'),
      );
      expect(
        _error(_call(<String, Object?>{'operation': ''})),
        contains('malformed'),
      );
    });

    test('applyJsCryptoCall_givenUppercaseHex_decodesIt', () {
      expect(
        _call(<String, Object?>{
          'operation': 'hexDecodeToString',
          'value': 'E99885E8AFBB',
        }),
        '阅读',
      );
    });

    test('applyJsCryptoCall_givenNonStringValue_stringifiesIt', () {
      expect(
        _call(<String, Object?>{
          'operation': 'hexEncodeToString',
          'value': 123,
        }),
        '313233',
      );
    });

    test('applyJsCryptoCall_givenUnknownCharset_fallsBackToUtf8', () {
      final Object? bytes = _call(<String, Object?>{
        'operation': 'strToBytes',
        'value': '阅读',
        'charset': 'X-UNKNOWN',
      });

      expect(_bytes(bytes), utf8.encode('阅读'));
    });

    test(
      'applyJsCryptoCall_givenBytesWithAnUnknownCharset_fallsBackToUtf8',
      () {
        expect(
          _call(<String, Object?>{
            'operation': 'bytesToStr',
            'value': <int>[0x41, 0x42],
            'charset': 'X-UNKNOWN',
          }),
          'AB',
        );
      },
    );

    test('applyJsCryptoCall_givenUndecodableBytes_stillAnswersText', () {
      // 声明 GBK 却喂坏字节：退 UTF-8 宽容解码，不抛错（Java 的 `String(bytes, charset)` 同样不抛）。
      final String text = _text(
        _call(<String, Object?>{
          'operation': 'bytesToStr',
          'value': <int>[0xFF, 0xFE, 0x41],
          'charset': 'GBK',
        }),
      );

      expect(text, contains('A'));
    });

    test('applyJsCryptoCall_givenMalformedCall_reportsIt', () {
      expect(_error(applyJsCryptoCall('not a map')), contains('malformed'));
      expect(
        _error(_call(<String, Object?>{'operation': 'nope'})),
        contains('is not a crypto binding'),
      );
    });

    test('applyJsCryptoCall_givenLegacyVerb_delegatesToTheStringFamily', () {
      expect(
        _call(<String, Object?>{'operation': 'md5', 'value': 'abc'}),
        '900150983cd24fb0d6963f7d28e17f72',
      );
    });
  });

  group('JsSymmetricCrypto', () {
    test('JsSymmetricCrypto_givenAesCbc_encryptsLikeTheJvm', () {
      // 向量由 `openssl enc -aes-128-cbc -K <key> -iv <iv>` 复算（PKCS7 = Java 的 PKCS5）。
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'AES/CBC/PKCS5Padding',
        key: 'D2o4XyQeIFobJ4tS',
        iv: 'sciCuBC7orQtDhTO',
      );

      expect(
        _method(registry, handle, 'encryptBase64', 'hello'),
        '72D9l7h5ia1n6LhEDc4fEg==',
      );
      expect(
        _method(registry, handle, 'decryptStr', '72D9l7h5ia1n6LhEDc4fEg=='),
        'hello',
      );
    });

    test('JsSymmetricCrypto_givenNoSlash_defaultsToEcbAndPkcs5', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int implicit = _create(registry, 'AES', key: '0123456789abcdef');
      final int explicit = _create(
        registry,
        'AES/ECB/PKCS5Padding',
        key: '0123456789abcdef',
      );
      const String plain = '阅读器测试';

      expect(
        _method(registry, implicit, 'encryptBase64', plain),
        _method(registry, explicit, 'encryptBase64', plain),
      );
      expect(
        _method(registry, implicit, 'encryptBase64', plain),
        'lrjbNr7JOU31x2/npa/ToQ==',
      );
    });

    test('JsSymmetricCrypto_givenSingleDes_usesTheDesedeTripleOfIt', () {
      // pointycastle 没有单 DES 引擎，本仓用 K1 = K2 = K3 的 DESede 顶替：与 `openssl enc
      // -des-cbc` 逐字节相同（同一向量已用两种 openssl 密码器互验）。
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'DES/CBC/PKCS5Padding',
        key: '12345678',
        iv: '87654321',
      );

      expect(
        _method(registry, handle, 'encryptBase64', 'hello'),
        '9GxQvERTbMU=',
      );
      expect(_method(registry, handle, 'decryptStr', '9GxQvERTbMU='), 'hello');
    });

    test('JsSymmetricCrypto_givenDesKeyLongerThanEightBytes_truncatesIt', () {
      // 上游 `SymmetricCryptoAndroid.normalizedKey`：DES 取前 8 字节。
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'DESede/CBC/PKCS5Padding',
        key: utf8.encode('123456789012345678901234'),
        iv: utf8.encode('87654321'),
      );

      expect(
        _method(registry, handle, 'encryptBase64', 'hello'),
        '0JSpoyU/76E=',
      );
    });

    test('JsSymmetricCrypto_givenNoPadding_encryptsExactlyOneBlock', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'AES/CBC/NoPadding',
        key: 'D2o4XyQeIFobJ4tS',
        iv: 'sciCuBC7orQtDhTO',
      );

      expect(
        _method(registry, handle, 'encryptBase64', '0123456789abcdef'),
        '3VuVGk/4hXTJ9LOCt75RWg==',
      );
    });

    test('JsSymmetricCrypto_givenPartialBlockWithNoPadding_reportsIt', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'AES/CBC/NoPadding',
        key: 'D2o4XyQeIFobJ4tS',
        iv: 'sciCuBC7orQtDhTO',
      );

      expect(
        _error(_method(registry, handle, 'encrypt', 'short')),
        contains('multiple of 16 bytes'),
      );
    });

    test('JsSymmetricCrypto_givenCbcWithoutIv_reportsIt', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'AES/CBC/PKCS5Padding',
        key: 'D2o4XyQeIFobJ4tS',
      );

      expect(
        _error(_method(registry, handle, 'encryptBase64', 'hello')),
        contains('needs an iv'),
      );
    });

    test('JsSymmetricCrypto_givenWrongAesKeyLength_reportsIt', () {
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'symmetricCreate',
            'transformation': 'AES/CBC/PKCS5Padding',
            'key': 'fifteen bytes!!',
          }, ciphers: JsSymmetricRegistry()),
        ),
        contains('16, 24 or 32 bytes'),
      );
    });

    test('JsSymmetricCrypto_givenUnsupportedTransformation_reportsIt', () {
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'symmetricCreate',
            'transformation': 'RC4',
          }, ciphers: JsSymmetricRegistry()),
        ),
        contains('unsupported algorithm'),
      );
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'symmetricCreate',
            'transformation': 'AES/CTR/PKCS5Padding',
            'key': 'D2o4XyQeIFobJ4tS',
          }, ciphers: JsSymmetricRegistry()),
        ),
        contains('unsupported mode'),
      );
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'symmetricCreate',
            'transformation': 'AES/CBC/ISO10126Padding',
            'key': 'D2o4XyQeIFobJ4tS',
          }, ciphers: JsSymmetricRegistry()),
        ),
        contains('unsupported padding'),
      );
    });

    test('JsSymmetricCrypto_givenDecryptGuess_acceptsHexAndBase64', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'AES/CBC/PKCS5Padding',
        key: 'D2o4XyQeIFobJ4tS',
        iv: 'sciCuBC7orQtDhTO',
      );
      final String hex = _text(
        _method(registry, handle, 'encryptHex', 'hello'),
      );

      // `decrypt(String)` 自己猜编码（上游 `SymmetricCryptoAndroid.kt:80-90`）。
      expect(_method(registry, handle, 'decryptStr', hex), 'hello');
      expect(
        _method(registry, handle, 'decryptStr', '72D9l7h5ia1n6LhEDc4fEg=='),
        'hello',
      );
      expect(
        _method(registry, handle, 'decryptHex', hex),
        utf8.encode('hello'),
      );
      expect(
        _method(registry, handle, 'decryptBase64', '72D9l7h5ia1n6LhEDc4fEg=='),
        utf8.encode('hello'),
      );
    });

    test('JsSymmetricCrypto_givenByteArrayOperand_encryptsTheRawBytes', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'AES/CBC/PKCS5Padding',
        key: 'D2o4XyQeIFobJ4tS',
        iv: 'sciCuBC7orQtDhTO',
      );
      final Object? ciphertext = _method(
        registry,
        handle,
        'encrypt',
        Uint8List.fromList(utf8.encode('hello')),
      );

      expect(ciphertext, isA<Uint8List>());
      expect(
        base64Encode(ciphertext! as Uint8List),
        '72D9l7h5ia1n6LhEDc4fEg==',
      );
      // 字节数组这条路径同样接受普通 List（JS 的 `Array.from(bytes)`）。
      expect(
        _method(registry, handle, 'decryptStr', <int>[
          ...ciphertext as Uint8List,
        ]),
        'hello',
      );
    });

    test(
      'JsSymmetricCrypto_givenSetIv_changesTheCipherAndReturnsTheHandle',
      () {
        final JsSymmetricRegistry registry = JsSymmetricRegistry();
        final int handle = _create(
          registry,
          'AES/CBC/PKCS5Padding',
          key: 'D2o4XyQeIFobJ4tS',
          iv: 'AAAAAAAAAAAAAAAA',
        );
        final Object? before = _method(
          registry,
          handle,
          'encryptBase64',
          'hello',
        );
        expect(_method(registry, handle, 'setIv', 'sciCuBC7orQtDhTO'), isTrue);
        final Object? after = _method(
          registry,
          handle,
          'encryptBase64',
          'hello',
        );

        expect(before, isNot(after));
        expect(after, '72D9l7h5ia1n6LhEDc4fEg==');
      },
    );

    test('JsSymmetricCrypto_givenUnknownOrExpiredHandle_reportsIt', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      expect(
        _error(_method(registry, 404, 'encrypt', 'hello')),
        contains('unknown symmetric crypto handle'),
      );

      final int handle = _create(
        registry,
        'AES/ECB/PKCS5Padding',
        key: '0123456789abcdef',
      );
      registry.clear();

      // 句柄表随 job 失效：脚本把句柄存到 globalThis 跨 job 用会拿到这一条，而不是别人的密码器。
      expect(
        _error(_method(registry, handle, 'encrypt', 'hello')),
        contains('unknown symmetric crypto handle'),
      );
    });

    test('JsSymmetricRegistry_givenMoreThanTheCap_dropsTheOldestHandle', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry(maxCiphers: 2);
      final int first = _create(registry, 'AES', key: '0123456789abcdef');
      _create(registry, 'AES', key: '0123456789abcdef');
      _create(registry, 'AES', key: '0123456789abcdef');

      expect(registry.length, 2);
      expect(registry.resolve(first), isNull);
    });

    test('JsSymmetricCrypto_givenNullKey_generatesOneAndStillRoundTrips', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'AES/CBC/PKCS5Padding',
        iv: 'sciCuBC7orQtDhTO',
      );
      final Object? ciphertext = _method(
        registry,
        handle,
        'encryptBase64',
        'hello',
      );

      expect(_method(registry, handle, 'decryptStr', ciphertext), 'hello');
    });

    test(
      'JsSymmetricCrypto_givenSingleDesWithoutKey_generatesAnEightByteKey',
      () {
        final JsSymmetricRegistry registry = JsSymmetricRegistry();
        final int handle = _create(
          registry,
          'DES/CBC/PKCS5Padding',
          iv: '87654321',
        );
        final Object? ciphertext = _method(
          registry,
          handle,
          'encryptBase64',
          'hello',
        );

        expect(_method(registry, handle, 'decryptStr', ciphertext), 'hello');
      },
    );

    test('JsSymmetricCrypto_givenShortDesKey_reportsIt', () {
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'symmetricCreate',
            'transformation': 'DES',
            'key': 'short',
          }, ciphers: JsSymmetricRegistry()),
        ),
        contains('DES key must be 8 bytes'),
      );
    });

    test('JsSymmetricCrypto_givenDesedeKeyEdges_normalisesThem', () {
      // 24 字节以上截前 24；16 字节（2-key 3DES）原样放行；其余长度按 Java 的 InvalidKey 失败。
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int long = _create(
        registry,
        'DESede/CBC/PKCS5Padding',
        key: utf8.encode('123456789012345678901234EXTRA'),
        iv: '87654321',
      );
      final int twoKey = _create(
        registry,
        'DESede/CBC/PKCS5Padding',
        key: utf8.encode('1234567890123456'),
        iv: '87654321',
      );

      final int exact = _create(
        registry,
        'DESede/CBC/PKCS5Padding',
        key: '123456789012345678901234',
        iv: '87654321',
      );

      expect(
        _method(registry, long, 'encryptBase64', 'hello'),
        _method(registry, exact, 'encryptBase64', 'hello'),
      );
      // 2-key 3DES 同样能往返（16 字节密钥原样进 pointycastle 的 DESede）。
      final Object? ciphertext = _method(
        registry,
        twoKey,
        'encryptBase64',
        'hello',
      );
      expect(_method(registry, twoKey, 'decryptStr', ciphertext), 'hello');
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'symmetricCreate',
            'transformation': 'DESede',
            'key': 'twenty-byte-key-here',
          }, ciphers: JsSymmetricRegistry()),
        ),
        contains('DESede key must be 16 or 24 bytes'),
      );
    });

    test(
      'JsSymmetricCrypto_givenDesedeWithoutKey_generatesATwentyFourByteKey',
      () {
        final JsSymmetricRegistry registry = JsSymmetricRegistry();
        final int handle = _create(
          registry,
          'DESede/CBC/PKCS5Padding',
          iv: '87654321',
        );
        final Object? ciphertext = _method(
          registry,
          handle,
          'encryptBase64',
          'hello',
        );

        expect(_method(registry, handle, 'decryptStr', ciphertext), 'hello');
      },
    );

    test('JsSymmetricCrypto_givenEncryptStrAndRawDecrypt_roundTrips', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(
        registry,
        'AES/CBC/PKCS5Padding',
        key: 'D2o4XyQeIFobJ4tS',
        iv: 'sciCuBC7orQtDhTO',
      );
      final Object? ciphertext = _method(registry, handle, 'encrypt', 'hello');

      expect(
        _method(registry, handle, 'decrypt', ciphertext),
        utf8.encode('hello'),
      );
      expect(
        _method(registry, handle, 'encryptStr', utf8.encode('hello')),
        isNotEmpty,
      );
      expect(
        _method(registry, handle, 'encryptBase64', 'hello', charset: 'UTF-8'),
        '72D9l7h5ia1n6LhEDc4fEg==',
      );
    });

    test('JsSymmetricCrypto_givenFourPartTransformation_reportsIt', () {
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'symmetricCreate',
            'transformation': 'AES/CBC/PKCS5Padding/extra',
            'key': 'D2o4XyQeIFobJ4tS',
          }, ciphers: JsSymmetricRegistry()),
        ),
        contains('unsupported transformation'),
      );
    });

    test('JsSymmetricCrypto_givenUnknownMethod_reportsIt', () {
      final JsSymmetricRegistry registry = JsSymmetricRegistry();
      final int handle = _create(registry, 'AES', key: '0123456789abcdef');

      expect(
        _error(_method(registry, handle, 'sign', 'hello')),
        contains('unknown symmetric crypto method'),
      );
    });
  });

  group('byte helpers', () {
    test('decodeHexBytes_givenWhitespace_ignoresIt', () {
      expect(decodeHexBytes('e9 98\n85'), <int>[0xE9, 0x98, 0x85]);
    });

    test('encodeHexBytes_givenBytes_answersLowercaseHex', () {
      expect(encodeHexBytes(<int>[0x00, 0x0F, 0xFF]), '000fff');
    });

    test('isHexText_givenUpperAndLowercase_answersTrue', () {
      expect(isHexText('aF09'), isTrue);
      expect(isHexText('aF09z'), isFalse);
      expect(isHexText(''), isTrue);
    });

    test('decodeLooseBase64_givenImpossibleLength_answersNull', () {
      expect(decodeLooseBase64('abcde'), isNull);
    });

    test('decodeLooseBase64_givenInvalidCharacters_answersNull', () {
      // 长度补齐也救不了的输入：解码器自己抛，宽容层把它折成「解不了」。
      expect(decodeLooseBase64(r'abc$def'), isNull);
    });

    test('JsSymmetricCrypto_givenATransformation_exposesTheNormalisedName', () {
      final JsSymmetricCrypto cipher = JsSymmetricCrypto(
        transformation: 'AES',
        key: Uint8List.fromList(utf8.encode('0123456789abcdef')),
      );

      expect(cipher.transformation, 'AES/ECB/PKCS5Padding');
    });
  });
}
