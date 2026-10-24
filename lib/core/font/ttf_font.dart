import 'dart:typed_data';

/// One `sfnt` table's place in the font file.
final class _Table {
  const _Table({required this.offset, required this.length});

  final int offset;
  final int length;
}

/// One `cmap` subtable, with the preference [TtfFont.parse] sorts it by.
final class _CmapCandidate {
  const _CmapCandidate({
    required this.rank,
    required this.format,
    required this.offset,
  });

  /// Higher wins: a Unicode `format 12` beats a Unicode `format 4` beats a legacy `format 6`.
  final int rank;

  /// The subtable format (`0`, `4`, `6`, `12`).
  final int format;

  /// The subtable's absolute offset in the file.
  final int offset;
}

/// A TrueType/OpenType font, read as far as text de-obfuscation needs it.
///
/// Two facts drive the shape of this class (`docs/dev/book-source.md` §6, ADR-0068 §决策 9):
///
/// * a site hides its text by **remapping the `cmap`** of a real font — the character in the HTML
///   is a private-use code point, and rendering it *with that font* draws the real glyph;
/// * the same glyph keeps its **identity** in both fonts. Upstream compares glyph **names**
///   (`post` table, `uniXXXX` in almost every CJK font), because they survive a remapped `cmap`
///   *and* renumbered glyphs; matching by glyph id only works while both fonts are the same base
///   font without subsetting. So names are tried first and the id is the fallback
///   ([replaceFontText]).
///
/// Parsing is deliberately narrow: table directory, `cmap` (formats 0 / 4 / 6 / 12) and `post`
/// format 2.0 names. `glyf`, `head`, `hmtx`, CFF and format 14 variation selectors are not read,
/// because no book source can consume them.
///
/// **Every read is unchecked.** A font is untrusted input, so [TtfFont.parse] translates a
/// `RangeError` from a short or lying table into a [FormatException] instead of guarding each
/// offset: one `try` costs one branch that a test can reach, twenty guards cost twenty.
final class TtfFont {
  TtfFont._({
    required this.codeToGlyph,
    required this.glyphNames,
    required this.codeByGlyph,
    required this.codeByGlyphName,
  });

  /// Reads one font file, or throws [FormatException] when it is not a readable TrueType font.
  ///
  /// An unreadable font is an exception and not a value because every caller is a sandbox call:
  /// the script should see `java.queryTTF failed`, not a font with an empty map that silently
  /// replaces nothing.
  factory TtfFont.parse(Uint8List bytes) {
    try {
      return _parse(ByteData.sublistView(bytes));
      // 字体是**不可信输入**：短表/撒谎的长度只该变成「这个字体读不出来」，不该让一个
      // RangeError 穿出沙箱调用（ADR-0068 §决策 9）。所以这里刻意接住 Error 子类。
      // ignore: avoid_catching_errors
    } on RangeError catch (error) {
      throw FormatException('the font is truncated: $error');
    }
  }

  /// Character code → glyph id, from the best Unicode `cmap` subtable.
  final Map<int, int> codeToGlyph;

  /// Glyph id → glyph name, from `post` format 2.0; empty when the font keeps no names.
  ///
  /// The 258 standard Macintosh names (`post` indices below 258) are **not** built in: a CJK
  /// obfuscation font names its glyphs `uniXXXX`, which live in the custom-name half.
  final Map<int, String> glyphNames;

  /// Glyph id → the cheapest character code that reaches it (the inverse of [codeToGlyph]).
  final Map<int, int> codeByGlyph;

  /// Glyph name → the cheapest character code that reaches it.
  final Map<String, int> codeByGlyphName;

  /// The glyph [code] is drawn with, or `null` when the font maps no such character.
  int? glyphOf(int code) => codeToGlyph[code];

  /// The name of [glyphId], or `null` when the font keeps no name for it.
  String? nameOfGlyph(int glyphId) => glyphNames[glyphId];

  static TtfFont _parse(ByteData data) {
    final Map<String, _Table> tables = _readTables(data);
    final _Table? cmap = tables['cmap'];
    if (cmap == null) {
      throw const FormatException('the font has no cmap table');
    }
    final Map<int, int> codeToGlyph = _readCmap(data, cmap);
    if (codeToGlyph.isEmpty) {
      throw const FormatException('the cmap table maps no character');
    }
    final _Table? post = tables['post'];
    final Map<int, String> glyphNames = post == null
        ? const <int, String>{}
        : _readPostNames(data, post);

    return TtfFont._(
      codeToGlyph: Map<int, int>.unmodifiable(codeToGlyph),
      glyphNames: Map<int, String>.unmodifiable(glyphNames),
      codeByGlyph: Map<int, int>.unmodifiable(_invert(codeToGlyph)),
      codeByGlyphName: Map<String, int>.unmodifiable(
        _byName(codeToGlyph, glyphNames),
      ),
    );
  }
}

/// Replaces every character [text] drew with the wrong glyph by the character [correctFont] draws
/// with the same glyph (`java.replaceFont`).
///
/// A character whose code [errorFont] does not map is kept as it is: a chapter mixes obfuscated
/// and plain text, and a font only maps what the site obfuscated.
///
/// [firstCode] / [lastCode] narrow the replacement to a code-point range, which is the older
/// `replaceFont(text, f1, f2, start, end)` corpus form (a site that obfuscated one range only).
String replaceFontText(
  String text, {
  required TtfFont errorFont,
  required TtfFont correctFont,
  int? firstCode,
  int? lastCode,
}) {
  final StringBuffer buffer = StringBuffer();

  for (final int rune in text.runes) {
    if ((firstCode != null && rune < firstCode) ||
        (lastCode != null && rune > lastCode)) {
      buffer.writeCharCode(rune);

      continue;
    }
    final int? glyph = errorFont.glyphOf(rune);
    if (glyph == null) {
      buffer.writeCharCode(rune);

      continue;
    }
    // 先按字形名对（子集化会重排字形 id，但 `uniXXXX` 名字还在），再用 id 兜底。
    final String? name = errorFont.nameOfGlyph(glyph);
    final int? mapped =
        (name == null ? null : correctFont.codeByGlyphName[name]) ??
        correctFont.codeByGlyph[glyph];
    buffer.writeCharCode(mapped ?? rune);
  }

  return buffer.toString();
}

/// Reads the `sfnt` table directory, keeping only tables that lie inside the file.
///
/// A record pointing past the end of the file is dropped rather than trusted: some obfuscation
/// fonts are cut short on purpose, and the tables that survived are still usable.
Map<String, _Table> _readTables(ByteData data) {
  if (data.lengthInBytes < 12) {
    throw const FormatException('the file is too short to be a font');
  }
  final int numTables = data.getUint16(4);
  final Map<String, _Table> tables = <String, _Table>{};

  for (int index = 0; index < numTables; index++) {
    final int record = 12 + index * 16;
    if (record + 16 > data.lengthInBytes) {
      break;
    }
    final int offset = data.getUint32(record + 8);
    final int length = data.getUint32(record + 12);
    if (offset + length <= data.lengthInBytes) {
      tables[String.fromCharCodes(<int>[
        data.getUint8(record),
        data.getUint8(record + 1),
        data.getUint8(record + 2),
        data.getUint8(record + 3),
      ])] = _Table(
        offset: offset,
        length: length,
      );
    }
  }

  return tables;
}

/// Reads the best Unicode `cmap` subtable, falling back to the next one when a subtable maps
/// nothing (a few fonts ship an empty format 4 next to a complete format 12).
Map<int, int> _readCmap(ByteData data, _Table cmap) {
  final int count = data.getUint16(cmap.offset + 2);
  final List<_CmapCandidate> candidates = <_CmapCandidate>[];

  for (int index = 0; index < count; index++) {
    final int record = cmap.offset + 4 + index * 8;
    final int platform = data.getUint16(record);
    final int encoding = data.getUint16(record + 2);
    final int subtable = cmap.offset + data.getUint32(record + 4);
    final int format = data.getUint16(subtable);
    final int rank = _rankOf(platform, encoding, format);
    if (rank > 0) {
      candidates.add(
        _CmapCandidate(rank: rank, format: format, offset: subtable),
      );
    }
  }
  candidates.sort(
    (_CmapCandidate left, _CmapCandidate right) => right.rank - left.rank,
  );

  for (final _CmapCandidate candidate in candidates) {
    final Map<int, int> map = switch (candidate.format) {
      0 => _parseFormat0(data, candidate.offset),
      4 => _parseFormat4(data, candidate.offset),
      6 => _parseFormat6(data, candidate.offset),
      _ => _parseFormat12(data, candidate.offset),
    };
    if (map.isNotEmpty) {
      return map;
    }
  }

  return const <int, int>{};
}

/// How much one `cmap` subtable is worth; `0` means "not a Unicode map this repository can read".
///
/// `3/10` (Windows UCS-4) and `0/4`..`0/6` (Unicode platform) are full Unicode; `3/1` and `0/3`
/// are BMP. Symbol (`3/0`) and legacy Macintosh encodings are skipped: their codes are not code
/// points, so a mapping built from them would replace the wrong characters.
int _rankOf(int platform, int encoding, int format) {
  final bool windows = platform == 3;
  final bool unicode = platform == 0;
  if (!windows && !unicode) {
    return 0;
  }
  if (windows && encoding == 0) {
    return 0;
  }
  final bool supported =
      format == 0 || format == 4 || format == 6 || format == 12;
  if (!supported) {
    return 0;
  }
  if (format == 12) {
    return windows && encoding == 10 ? 4 : (unicode ? 3 : 0);
  }
  if (format == 4) {
    return windows && encoding == 1 ? 2 : (unicode ? 2 : 0);
  }

  return 1;
}

/// Reads a `format 0` (byte encoding) subtable: 256 one-byte glyph ids.
Map<int, int> _parseFormat0(ByteData data, int offset) {
  final Map<int, int> map = <int, int>{};
  for (int code = 0; code < 256; code++) {
    final int glyph = data.getUint8(offset + 6 + code);
    if (glyph != 0) {
      map[code] = glyph;
    }
  }

  return map;
}

/// Reads a `format 6` (trimmed table) subtable.
Map<int, int> _parseFormat6(ByteData data, int offset) {
  final Map<int, int> map = <int, int>{};
  final int firstCode = data.getUint16(offset + 6);
  final int entryCount = data.getUint16(offset + 8);
  for (int index = 0; index < entryCount; index++) {
    final int glyph = data.getUint16(offset + 10 + index * 2);
    if (glyph != 0) {
      map[firstCode + index] = glyph;
    }
  }

  return map;
}

/// Reads a `format 4` (segment mapping) subtable, the BMP workhorse.
///
/// The lookup is the spec's `idRangeOffset` arithmetic: when the offset is `0` the glyph is
/// `code + idDelta`, otherwise it is read from `glyphIdArray` at
/// `idRangeOffset/2 + (code - startCode)` words past the offset's own position.
Map<int, int> _parseFormat4(ByteData data, int offset) {
  final Map<int, int> map = <int, int>{};
  final int segCountX2 = data.getUint16(offset + 6);
  final int segCount = segCountX2 ~/ 2;
  if (segCount == 0) {
    return map;
  }
  final int endBase = offset + 14;
  final int startBase = endBase + segCountX2 + 2;
  final int deltaBase = startBase + segCountX2;
  final int rangeBase = deltaBase + segCountX2;

  for (int segment = 0; segment < segCount; segment++) {
    final int endCode = data.getUint16(endBase + segment * 2);
    final int startCode = data.getUint16(startBase + segment * 2);
    if (startCode > endCode) {
      continue;
    }
    final int delta = data.getInt16(deltaBase + segment * 2);
    final int rangeOffset = data.getUint16(rangeBase + segment * 2);

    for (int code = startCode; code <= endCode; code++) {
      if (code == 0xFFFF) {
        continue;
      }
      final int glyph;
      if (rangeOffset == 0) {
        glyph = (code + delta) & 0xFFFF;
      } else {
        final int raw = data.getUint16(
          rangeBase + segment * 2 + rangeOffset + (code - startCode) * 2,
        );
        glyph = raw == 0 ? 0 : (raw + delta) & 0xFFFF;
      }
      if (glyph != 0) {
        map[code] = glyph;
      }
    }
  }

  return map;
}

/// Reads a `format 12` (segmented coverage) subtable, which reaches beyond the BMP.
Map<int, int> _parseFormat12(ByteData data, int offset) {
  final Map<int, int> map = <int, int>{};
  final int groupCount = data.getUint32(offset + 12);
  for (int group = 0; group < groupCount; group++) {
    final int cursor = offset + 16 + group * 12;
    final int start = data.getUint32(cursor);
    final int end = data.getUint32(cursor + 4);
    final int startGlyph = data.getUint32(cursor + 8);
    if (end < start) {
      continue;
    }
    // 坏字体可以声明上百万码位；`0x10FFFF` 以上的都不是字符，直接跳过这一组。
    final int count = end - start + 1;
    if (start + count > 0x110000) {
      continue;
    }
    for (int step = 0; step < count; step++) {
      final int glyph = startGlyph + step;
      if (glyph != 0) {
        map[start + step] = glyph;
      }
    }
  }

  return map;
}

/// Reads the glyph names of a `post` format 2.0 table, keyed by glyph id.
///
/// Format 3.0 (no names) and anything this repository does not recognise answer an empty map,
/// which makes [replaceFontText] fall back to glyph ids.
Map<int, String> _readPostNames(ByteData data, _Table post) {
  if (post.length < 34 || data.getUint32(post.offset) != 0x00020000) {
    return const <int, String>{};
  }
  final int count = data.getUint16(post.offset + 32);
  final int indexBase = post.offset + 34;
  final int tableEnd = post.offset + post.length;

  final List<String> custom = <String>[];
  int cursor = indexBase + count * 2;
  while (cursor < tableEnd) {
    final int length = data.getUint8(cursor);
    final int end = cursor + 1 + length;
    if (end > tableEnd) {
      break;
    }
    custom.add(
      String.fromCharCodes(<int>[
        for (int index = cursor + 1; index < end; index++) data.getUint8(index),
      ]),
    );
    cursor = end;
  }

  final Map<int, String> names = <int, String>{};
  for (int glyph = 0; glyph < count; glyph++) {
    final int nameIndex = data.getUint16(indexBase + glyph * 2);
    // 0..257 是标准 Macintosh 名（本仓不内置那张表）；只取自定义名。
    if (nameIndex < 258) {
      continue;
    }
    final int customIndex = nameIndex - 258;
    if (customIndex < custom.length) {
      names[glyph] = custom[customIndex];
    }
  }

  return names;
}

/// Glyph id → the first character code that reaches it.
Map<int, int> _invert(Map<int, int> codeToGlyph) {
  final Map<int, int> inverse = <int, int>{};
  for (final MapEntry<int, int> entry in codeToGlyph.entries) {
    inverse.putIfAbsent(entry.value, () => entry.key);
  }

  return inverse;
}

/// Glyph name → the first character code whose glyph carries that name.
Map<String, int> _byName(
  Map<int, int> codeToGlyph,
  Map<int, String> glyphNames,
) {
  final Map<int, int> glyphToCode = _invert(codeToGlyph);
  final Map<String, int> byName = <String, int>{};
  for (final MapEntry<int, String> entry in glyphNames.entries) {
    final int? code = glyphToCode[entry.key];
    if (code != null) {
      byName.putIfAbsent(entry.value, () => code);
    }
  }

  return byName;
}
