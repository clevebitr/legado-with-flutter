import 'dart:typed_data';

import 'package:flutter_reader/core/font/ttf_font.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_ttf.dart';

/// Reads a font whose only `cmap` subtable is [codes] in [format].
TtfFont _font(
  Map<int, int> codes, {
  int format = 4,
  bool useDeltaForm = false,
  Map<int, String> names = const <int, String>{},
  bool includePost = true,
  Uint8List? postOverride,
  bool version3 = false,
  List<({int platformId, int encodingId, Uint8List subtable})> additional =
      const <({int platformId, int encodingId, Uint8List subtable})>[],
}) => TtfFont.parse(
  buildSyntheticFont(
    cmapOverride: buildSyntheticCmap(
      codes: codes,
      format: format,
      // format 12 的合法平台是 3/10（UCS-4）；3/1 只有 BMP，本仓按名跳过。
      encodingId: format == 12 ? 10 : 1,
      useDeltaForm: useDeltaForm,
      additional: additional,
    ),
    includePost: includePost,
    postOverride:
        postOverride ??
        (includePost
            ? buildSyntheticPost(
                // 字形 id 的最大值决定 post 表要覆盖多少个字形。
                numGlyphs:
                    <int>[
                      ...codes.values,
                      ...names.keys,
                      0,
                    ].reduce((int a, int b) => a > b ? a : b) +
                    1,
                names: names,
                version3: version3,
              )
            : null),
  ),
);

/// The exception [build] throws, failing the test when nothing is thrown.
Object _throws(void Function() build) {
  try {
    build();
  } on FormatException catch (error) {
    return error;
  }
  fail('Expected a FormatException.');
}

void main() {
  group('TtfFont cmap', () {
    test('parse_givenFormat4WithGlyphIdArray_mapsTheCodePoints', () {
      // 私有区码位 → 字形 id：这就是字体反爬的输入形状（ADR-0068 §决策 9）。
      final TtfFont font = _font(<int, int>{0xE001: 1, 0xE003: 3});

      expect(font.glyphOf(0xE001), 1);
      // 中间那个码位在 glyphIdArray 里是 0：字体没有为它画字形，不能当成映射。
      expect(font.glyphOf(0xE002), isNull);
      expect(font.glyphOf(0xE003), 3);
    });

    test('parse_givenFormat4DeltaForm_appliesTheDelta', () {
      // `idRangeOffset == 0` 的段：glyph = code + idDelta（A→3 / B→4 / C→5）。
      final TtfFont font = _font(<int, int>{
        0x41: 3,
        0x42: 4,
        0x43: 5,
      }, useDeltaForm: true);

      expect(font.glyphOf(0x41), 3);
      expect(font.glyphOf(0x43), 5);
    });

    test('parse_givenFormat12_mapsCodePointsBeyondTheBmp', () {
      final TtfFont font = _font(<int, int>{0x20000: 1, 0x5251: 2}, format: 12);

      expect(font.glyphOf(0x20000), 1);
      expect(font.codeByGlyph[2], 0x5251);
    });

    test('parse_givenFormat6_readsTheTrimmedTable', () {
      final TtfFont font = _font(<int, int>{0x30: 7, 0x31: 8}, format: 6);

      expect(font.glyphOf(0x30), 7);
      expect(font.glyphOf(0x31), 8);
    });

    test('parse_givenFormat0_readsTheByteEncoding', () {
      final TtfFont font = _font(<int, int>{0x41: 9}, format: 0);

      expect(font.glyphOf(0x41), 9);
    });

    test('parse_givenAnEmptySubtableBeforeAGoodOne_fallsBack', () {
      // 有的字体同时在 3/1 放一张空的 format 4、在 3/10 放完整的 format 12。
      final TtfFont font = _font(
        const <int, int>{},
        additional: <({int platformId, int encodingId, Uint8List subtable})>[
          (
            platformId: 3,
            encodingId: 10,
            subtable: buildSyntheticSubtable(
              format: 12,
              codes: <int, int>{0x4E00: 5},
            ),
          ),
        ],
      );

      expect(font.glyphOf(0x4E00), 5);
    });

    test('parse_givenNoCmapTable_throwsFormatException', () {
      _throws(
        () => TtfFont.parse(
          buildSyntheticFont(includeCmap: false, includePost: true),
        ),
      );
    });

    test('parse_givenAShortFile_throwsFormatException', () {
      _throws(() => TtfFont.parse(Uint8List(4)));
    });

    test('parse_givenOnlyANonUnicodeSubtable_throwsFormatException', () {
      // 平台 1 / 编码 0 是 Macintosh 字节编码：它的「码位」不是字符，猜一个只会换错字。
      _throws(
        () => TtfFont.parse(
          buildSyntheticFont(
            cmapOverride: buildSyntheticCmap(
              codes: <int, int>{0x41: 1},
              platformId: 1,
              encodingId: 0,
            ),
          ),
        ),
      );
    });

    test('parse_givenOnlyASymbolSubtable_throwsFormatException', () {
      _throws(
        () => TtfFont.parse(
          buildSyntheticFont(
            cmapOverride: buildSyntheticCmap(
              codes: <int, int>{0xF041: 1},
              platformId: 3,
              encodingId: 0,
            ),
          ),
        ),
      );
    });

    test('parse_givenAnUnsupportedCmapFormat_throwsFormatException', () {
      // format 2 / 8 / 10 / 13 不在支持面：跳过它们，没有可用子表就是读不出来。
      _throws(
        () => TtfFont.parse(
          buildSyntheticFont(
            cmapOverride: buildSyntheticCmap(
              codes: const <int, int>{},
              additional:
                  <({int platformId, int encodingId, Uint8List subtable})>[
                    (platformId: 3, encodingId: 10, subtable: _rawSubtable(2)),
                  ],
            ),
          ),
        ),
      );
    });

    test('parse_givenASegmentThatEndsBeforeItStarts_skipsIt', () {
      _throws(
        () => TtfFont.parse(
          buildSyntheticFont(
            cmapOverride: _bogusFormat4(start: 0x50, end: 0x10),
          ),
        ),
      );
    });

    test('parse_givenAGroupThatEndsBeforeItStarts_skipsIt', () {
      _throws(
        () => TtfFont.parse(
          buildSyntheticFont(
            cmapOverride: _rawCmap(
              _bogusFormat12(start: 0x2000, end: 0x1000, glyph: 1),
            ),
          ),
        ),
      );
    });

    test('parse_givenAGroupAboveTheLastCodePoint_skipsIt', () {
      // `start + count > 0x110000`：不是字符的码位一个都不收，否则一张坏表能撑爆内存。
      _throws(
        () => TtfFont.parse(
          buildSyntheticFont(
            cmapOverride: _rawCmap(
              _bogusFormat12(start: 0x110000, end: 0x110002, glyph: 1),
            ),
          ),
        ),
      );
    });

    test('parse_givenATruncatedSubtable_throwsFormatException', () {
      _throws(
        () => TtfFont.parse(
          buildSyntheticFont(
            cmapOverride: _rawCmap(_rawSubtable(6, declaredEntries: 8)),
          ),
        ),
      );
    });
  });

  group('TtfFont post names', () {
    test('parse_givenPostFormat2_keepsTheCustomNames', () {
      final TtfFont font = _font(
        <int, int>{0xE001: 1},
        names: <int, String>{1: 'uni5251'},
      );

      expect(font.nameOfGlyph(1), 'uni5251');
    });

    test('parse_givenAStandardNameIndex_keepsNoName', () {
      // 索引 < 258 是标准 Macintosh 名，本仓不内置那张表：这些字形走 id 回退。
      final TtfFont font = _font(<int, int>{0xE001: 1});

      expect(font.glyphNames, isEmpty);
      expect(font.nameOfGlyph(1), isNull);
    });

    test('parse_givenPostFormat3_keepsNoNames', () {
      final TtfFont font = _font(
        <int, int>{0xE001: 1},
        names: <int, String>{1: 'uni5251'},
        version3: true,
      );

      expect(font.glyphNames, isEmpty);
    });

    test('parse_givenATinyPostTable_keepsNoNames', () {
      final TtfFont font = _font(<int, int>{
        0xE001: 1,
      }, postOverride: Uint8List(20));

      expect(font.glyphNames, isEmpty);
    });

    test('parse_givenNoPostTable_keepsNoNames', () {
      final TtfFont font = _font(<int, int>{0xE001: 1}, includePost: false);

      expect(font.glyphNames, isEmpty);
    });
  });

  group('replaceFontText', () {
    test('givenBothFontsNameTheirGlyphs_mapsByGlyphName', () {
      // 站点把「剑客」画成 U+E001/U+E002，而两套字体的字形名都是 `uniXXXX`：
      // 子集化把字形 id 重排了也不影响这条链路。
      final TtfFont errorFont = _font(
        <int, int>{0xE001: 1, 0xE002: 2},
        names: <int, String>{1: 'uni5251', 2: 'uni5BA2'},
      );
      final TtfFont correctFont = _font(
        <int, int>{0x5251: 41, 0x5BA2: 42},
        names: <int, String>{41: 'uni5251', 42: 'uni5BA2'},
      );

      expect(
        replaceFontText(
          '前面\ue001\ue002后面',
          errorFont: errorFont,
          correctFont: correctFont,
        ),
        '前面剑客后面',
      );
    });

    test('givenNoGlyphNames_fallsBackToGlyphIds', () {
      final TtfFont errorFont = _font(<int, int>{0xE001: 7});
      final TtfFont correctFont = _font(<int, int>{0x5251: 7});

      expect(
        replaceFontText(
          '\ue001',
          errorFont: errorFont,
          correctFont: correctFont,
        ),
        '剑',
      );
    });

    test('givenACharacterTheFontDoesNotMap_keepsIt', () {
      final TtfFont errorFont = _font(<int, int>{0xE001: 1});
      final TtfFont correctFont = _font(<int, int>{0x5251: 1});

      expect(
        replaceFontText('普通文字', errorFont: errorFont, correctFont: correctFont),
        '普通文字',
      );
    });

    test('givenAGlyphTheCorrectFontLacks_keepsTheCharacter', () {
      final TtfFont errorFont = _font(<int, int>{0xE001: 9});
      final TtfFont correctFont = _font(<int, int>{0x5251: 1});

      expect(
        replaceFontText(
          '\ue001',
          errorFont: errorFont,
          correctFont: correctFont,
        ),
        '\ue001',
      );
    });

    test('givenANameTheCorrectFontLacks_fallsBackToTheGlyphId', () {
      final TtfFont errorFont = _font(
        <int, int>{0xE001: 1},
        names: <int, String>{1: 'uni5251'},
      );
      final TtfFont correctFont = _font(<int, int>{0x5BA2: 1});

      expect(
        replaceFontText(
          '\ue001',
          errorFont: errorFont,
          correctFont: correctFont,
        ),
        '客',
      );
    });

    test('givenACodePointRange_replacesOnlyInsideIt', () {
      final TtfFont errorFont = _font(
        <int, int>{0xE001: 1, 0xE002: 2},
        names: <int, String>{1: 'uni5251', 2: 'uni5BA2'},
      );
      final TtfFont correctFont = _font(
        <int, int>{0x5251: 1, 0x5BA2: 2},
        names: <int, String>{1: 'uni5251', 2: 'uni5BA2'},
      );

      expect(
        replaceFontText(
          '\ue001\ue002',
          errorFont: errorFont,
          correctFont: correctFont,
          firstCode: 0xE002,
        ),
        '\ue001客',
      );
      expect(
        replaceFontText(
          '\ue001\ue002',
          errorFont: errorFont,
          correctFont: correctFont,
          lastCode: 0xE001,
        ),
        '剑\ue002',
      );
    });

    test('givenASupplementaryCodePoint_mapsIt', () {
      // 代理对在 Dart 里是一个 rune；写回时也要变回代理对，不能拆成两个替换字符。
      final TtfFont errorFont = _font(<int, int>{0x20001: 1}, format: 12);
      final TtfFont correctFont = _font(<int, int>{0x2A6D6: 1}, format: 12);

      expect(
        replaceFontText(
          String.fromCharCode(0x20001),
          errorFont: errorFont,
          correctFont: correctFont,
        ),
        String.fromCharCode(0x2A6D6),
      );
    });
  });
}

/// A `cmap` table holding one raw subtable, for the malformed cases the builder cannot express.
Uint8List _rawCmap(Uint8List subtable) {
  final Uint8List table = Uint8List(12 + subtable.length);
  final ByteData data = ByteData.sublistView(table);
  data.setUint16(2, 1);
  data.setUint16(4, 3);
  data.setUint16(6, 10);
  data.setUint32(8, 12);
  table.setRange(12, 12 + subtable.length, subtable);

  return table;
}

/// A subtable of [format] with a plausible header and no payload (or a lying entry count).
Uint8List _rawSubtable(int format, {int declaredEntries = 0}) {
  final Uint8List bytes = Uint8List(format == 6 ? 10 : 12);
  final ByteData data = ByteData.sublistView(bytes);
  data.setUint16(0, format);
  if (format == 6) {
    data.setUint16(8, declaredEntries);
  }

  return bytes;
}

/// A `format 4` subtable whose single segment ends before it starts.
Uint8List _bogusFormat4({required int start, required int end}) {
  final Uint8List bytes = Uint8List(14 + 2 * 8 + 2);
  final ByteData data = ByteData.sublistView(bytes);
  data.setUint16(0, 4);
  data.setUint16(6, 2);
  data.setUint16(14, end);
  data.setUint16(14 + 2 + 2, start);

  return bytes;
}

/// A `format 12` subtable with one group that ends before it starts (or above `0x10FFFF`).
Uint8List _bogusFormat12({
  required int start,
  required int end,
  required int glyph,
}) {
  final Uint8List bytes = Uint8List(16 + 12);
  final ByteData data = ByteData.sublistView(bytes);
  data.setUint16(0, 12);
  data.setUint32(12, 1);
  data.setUint32(16, start);
  data.setUint32(20, end);
  data.setUint32(24, glyph);

  return bytes;
}
