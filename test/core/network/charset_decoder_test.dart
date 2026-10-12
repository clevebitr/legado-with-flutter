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

    test(
      'decodeBody_whenBytesLookMalformedWithoutADeclaration_neverTolerates',
      () {
        // 嗅探车道不做宽容解码（ADR-0031 §决策 3）：标签是猜的，静默替换会把「猜错编码」
        // 变成乱码正文。
        //
        // 为什么这里断言的是「标签 + 零替换」而不是 `throwsFormatException`：实测
        // （2026-10-12，`betto_charset_detector 0.1.0`）它的候选表里**没有 utf-8**，而会招
        // `FormatException` 的 `gbk` 在嗅探下不可达——构造与真实样本一律被判成
        // iso-8859-1 / windows-1252 / euc-kr（宽容解码器）或 shift-jis / euc-jp，
        // 后者在字节不完整时抛的是 `RangeError`（`Error`，已登记在 `PLAN.md` §3.7）。
        // 因此「不宽容」是这条车道唯一可观测且在仓内可钉的行为；依赖修好后，嗅探车道
        // 会抛异常的直接用例可再补。
        final List<({List<int> bytes, String label})> samples =
            <({List<int> bytes, String label})>[
              (bytes: _utf8WithStrayByte, label: 'shift-jis'),
              (bytes: <int>[0xB0, 0xA1, 0x81, 0xB0, 0xA1], label: 'iso-8859-1'),
              (bytes: <int>[0x82, 0xA0, 0x82], label: 'windows-1252'),
              (bytes: <int>[0xCC, 0xEC, 0x81], label: 'euc-kr'),
            ];

        for (final ({List<int> bytes, String label}) sample in samples) {
          final DecodedBody decoded = decodeBody(sample.bytes);

          expect(decoded.charset, sample.label, reason: '${sample.bytes}');
          expect(
            decoded.toleratedMalformedBytes,
            isFalse,
            reason: '${sample.bytes}',
          );
          expect(decoded.malformedByteCount, 0, reason: '${sample.bytes}');
        }
      },
    );

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
        // `us-ascii` / `utf-16` / `utf-32` 的**排除策略**归 `book-source.md` §5.1：声明了
        // 它们却解不开，说明声明本身错了（不是「坏字节」），宽容只会把整页变成垃圾。
        // 代码只回链该节，不在这里复述（ADR-0013 §3）。
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

    test('decodeBody_givenASniffedCharset_usesItInsteadOfDetecting', () {
      // 缓存命中（book-source.md §5）：同一 (书源, URL) 的第二次请求把上次的检测结果带进来。
      // 这里把 **UTF-8** 字节配上缓存标签 `gbk`：解出来是 GBK 读法而不是 `剑来`，
      // 证明嗅探确实没有跑（嗅探会选 utf-8）——这正是「第二次不再嗅探」的可观测形式，
      // 也说明缓存的前提是「同一 URL 的编码不变」（§5 的固有假设）。
      final DecodedBody decoded = decodeBody(
        utf8.encode('剑来'),
        sniffedCharset: 'gbk',
      );

      expect(decoded.charset, 'gbk');
      expect(decoded.isDetected, isTrue);
      expect(decoded.text, isNot('剑来'));
      expect(decoded.text, isNotEmpty);
    });

    test(
      'decodeBody_givenBothADeclarationAndASniffedCharset_theDeclarationWins',
      () {
        // 声明永远优先于缓存：ADR-0031 的两条车道不得因为缓存而改变。
        final DecodedBody decoded = decodeBody(
          _gbkTian,
          contentType: 'text/html; charset=gbk',
          sniffedCharset: 'utf-8',
        );

        expect(decoded.charset, 'gbk');
        expect(decoded.isDetected, isFalse);
        expect(decoded.text, '天');
      },
    );

    test('decodeBody_givenNoDeclaration_reportsThatItDetected', () {
      // `isDetected` 是「这个标签值不值得缓存」的判据：只有嗅探出来的才写缓存。
      expect(decodeBody(utf8.encode('天')).isDetected, isTrue);
      expect(
        decodeBody(_gbkTian, contentType: 'text/html; charset=gbk').isDetected,
        isFalse,
      );
    });
  });
}
