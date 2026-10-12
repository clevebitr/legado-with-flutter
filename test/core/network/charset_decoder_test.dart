import 'dart:convert';

import 'package:flutter_reader/core/network/charset_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// GBK bytes for 「天」, the kind of non-UTF-8 page Chinese book sources serve.
const List<int> _gbkTian = <int>[0xCC, 0xEC];

/// UTF-8 bytes for 「剑」 followed by one byte that cannot continue the sequence: the
/// shape of a real page whose declaration is right but whose byte stream is not
/// (ADR-0031, found by the G2b spot-check).
const List<int> _utf8WithStrayByte = <int>[0xE5, 0x89, 0x91, 0x8B];

void main() {
  group('decodeBody', () {
    test('decodeBody_whenContentTypeDeclaresUtf8_decodesUtf8Bytes', () {
      expect(
        decodeBody(
          utf8.encode('天'),
          contentType: 'text/html; charset=utf-8',
        ).text,
        '天',
      );
    });

    test('decodeBody_whenContentTypeDeclaresGbk_decodesGbkBytes', () {
      expect(
        decodeBody(_gbkTian, contentType: 'text/html; charset=GBK').text,
        '天',
      );
    });

    test('decodeBody_whenContentTypeQuotesTheCharset_decodesIt', () {
      expect(
        decodeBody(_gbkTian, contentType: 'text/html; charset="gbk"').text,
        '天',
      );
    });

    test('decodeBody_whenMetaDeclaresGbk_decodesGbkBytes', () {
      final List<int> page = <int>[
        ...utf8.encode('<html><head><meta charset="gbk"></head><body>'),
        ..._gbkTian,
        ...utf8.encode('</body></html>'),
      ];

      expect(decodeBody(page).text, contains('天'));
    });

    test('decodeBody_whenMetaUsesHttpEquiv_decodesGbkBytes', () {
      final List<int> page = <int>[
        ...utf8.encode(
          '<meta http-equiv="Content-Type" content="text/html; charset=gbk">',
        ),
        ..._gbkTian,
      ];

      expect(decodeBody(page).text, contains('天'));
    });

    test('decodeBody_whenNothingIsDeclared_detectsUtf8', () {
      expect(decodeBody(utf8.encode('天')).text, '天');
    });

    test('decodeBody_whenDeclaredLabelIsUnknown_fallsBackToUtf8', () {
      expect(
        decodeBody(
          utf8.encode('天'),
          contentType: 'text/html; charset=x-unknown',
        ).text,
        '天',
      );
    });

    test('decodeBody_whenMetaSitsBeyondTheScanWindow_ignoresIt', () {
      final List<int> page = <int>[
        ...List<int>.filled(metaScanLimit, 0x20),
        ...utf8.encode('<meta charset="gbk">'),
      ];

      expect(decodeBody(page).text, contains('<meta charset="gbk">'));
    });

    test(
      'decodeBody_whenDeclaredCharsetHasAStrayByte_replacesItAndReportsIt',
      () {
        final DecodedBody decoded = decodeBody(
          _utf8WithStrayByte,
          contentType: 'text/html; charset=utf-8',
        );

        // ADR-0031 §决策 1/2：声明是权威，坏字节用替换字符顶上，整页仍然可用 —— 但必须留痕
        // （声明的编码 + 替换数量），否则就是 C-NET-3 禁止的静默吞掉。
        expect(decoded.toleratedMalformedBytes, isTrue);
        expect(decoded.charset, 'utf-8');
        expect(decoded.malformedByteCount, 1);
        expect(decoded.text.startsWith('剑'), isTrue);
        expect(decoded.text, contains('\uFFFD'));
      },
    );

    test('decodeBody_whenMetaDeclaredCharsetHasAStrayByte_toleratesIt', () {
      final List<int> page = <int>[
        ...utf8.encode('<meta charset="utf-8">'),
        ..._utf8WithStrayByte,
      ];

      final DecodedBody decoded = decodeBody(page);

      expect(decoded.toleratedMalformedBytes, isTrue);
      expect(decoded.charset, 'utf-8');
      expect(decoded.text, contains('\uFFFD'));
    });

    test('decodeBody_whenDeclaredGbkCharsetHasAStrayByte_toleratesIt', () {
      // 声明 gbk 而尾随一个不完整的双字节序列：GBK 解码器能宽容，非法字节变成 U+FFFD
      // 且不影响后面的字节（实测：`[0xCC,0xEC,0x81]` → `天�`）。
      final DecodedBody decoded = decodeBody(<int>[
        0xCC,
        0xEC,
        0x81,
      ], contentType: 'text/html; charset=gbk');

      expect(decoded.toleratedMalformedBytes, isTrue);
      expect(decoded.charset, 'gbk');
      expect(decoded.malformedByteCount, 1);
      expect(decoded.text, '天\uFFFD');
    });

    test('decodeBody_whenAValidPageIsDecoded_doesNotReportTolerance', () {
      final DecodedBody decoded = decodeBody(
        utf8.encode('天'),
        contentType: 'text/html; charset=utf-8',
      );

      expect(decoded.toleratedMalformedBytes, isFalse);
      expect(decoded.charset, 'utf-8');
      expect(decoded.malformedByteCount, 0);
    });

    test('decodeBody_whenSniffedBodyHasAStrayByte_doesNotTolerateIt', () {
      // 嗅探车道不做宽容解码：那里「编码猜错了」与「字节坏了」无法区分，静默替换
      // 会得到乱码正文（ADR-0031 §决策 2）。这个输入恰好被侦测为 shift-jis 且能
      // 解码，因此断言的是「没有走宽容通道」，而不是「抛异常」。
      final DecodedBody decoded = decodeBody(_utf8WithStrayByte);

      expect(decoded.toleratedMalformedBytes, isFalse);
      // 嗅探车道记录的是「实际用了哪个标签」，而不是「声明了哪个」。
      expect(decoded.charset, isNotEmpty);
      expect(decoded.malformedByteCount, 0);
    });

    test('decodeBody_whenDeclaredLabelIsUnknownAndBytesAreNotUtf8_throwsFormatException', () {
      // 未知标签会回退 UTF-8（§5 的最后一步），那是回退车道，仍严格失败。
      expect(
        () => decodeBody(<int>[
          0xFF,
          0xFE,
          0xFD,
        ], contentType: 'text/html; charset=x-unknown'),
        throwsFormatException,
      );
    });

    test(
      'decodeBody_whenDeclaredLabelHasNoTolerantCodec_throwsFormatException',
      () {
        // `us-ascii` 明确不在宽容映射里：声明成 ascii 却带高位字节，是声明本身错了，
        // 宽容解码只会把整页变成垃圾（ADR-0031 §决策 4）。
        expect(
          () => decodeBody(<int>[
            0xFF,
            0xFE,
            0xFD,
          ], contentType: 'text/html; charset=us-ascii'),
          throwsFormatException,
        );
      },
    );
  });
}
