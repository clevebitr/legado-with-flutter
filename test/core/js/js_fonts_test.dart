import 'package:flutter_reader/core/font/ttf_font.dart';
import 'package:flutter_reader/core/js/js_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_ttf.dart';

/// A font mapping [code] to glyph 1.
TtfFont _font(int code) => TtfFont.parse(
  buildSyntheticFont(
    cmapOverride: buildSyntheticCmap(codes: <int, int>{code: 1}),
  ),
);

void main() {
  group('JsFontRegistry', () {
    test('add_givenFonts_answersDistinctHandles', () {
      final JsFontRegistry registry = JsFontRegistry();

      expect(registry.add(_font(0xE001)), 1);
      expect(registry.add(_font(0xE002)), 2);
      expect(registry.length, 2);
    });

    test('resolve_givenALiveHandle_answersTheFont', () {
      final JsFontRegistry registry = JsFontRegistry();
      final int id = registry.add(_font(0xE001));

      expect(registry.resolve(id)?.glyphOf(0xE001), 1);
    });

    test('resolve_givenAStaleOrNonIntegerHandle_answersNull', () {
      final JsFontRegistry registry = JsFontRegistry();

      expect(registry.resolve(42), isNull);
      expect(registry.resolve('1'), isNull);
      expect(registry.resolve(null), isNull);
      expect(registry.resolve(<String, Object?>{'id': 1}), isNull);
    });

    test('add_givenMoreThanTheLimit_dropsTheOldest', () {
      // 一章最多两张字体；上限存在的意义是「一个 job 里被循环查询上千次」时不涨内存。
      final JsFontRegistry registry = JsFontRegistry(maxFonts: 2);
      final int first = registry.add(_font(0xE001));
      registry.add(_font(0xE002));
      registry.add(_font(0xE003));

      expect(registry.length, 2);
      expect(registry.resolve(first), isNull);
    });

    test('clear_forgetsTheFontsButNeverReusesAHandle', () {
      // 句柄 id 不复用：脚本把句柄存在 globalThis 里再跨 job 使用时，必须「找不到」而不是
      // 悄悄读到下一个源的同号字体。
      final JsFontRegistry registry = JsFontRegistry();
      final int first = registry.add(_font(0xE001));
      registry.clear();

      expect(registry.length, 0);
      expect(registry.resolve(first), isNull);
      expect(registry.add(_font(0xE002)), first + 1);
    });
  });
}
