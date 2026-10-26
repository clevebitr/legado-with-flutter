import 'dart:typed_data';

/// One table of a synthetic font file.
final class _SfntTable {
  const _SfntTable({required this.tag, required this.bytes});

  final String tag;
  final Uint8List bytes;
}

/// Builds a minimal but **real** `sfnt` file around the tables it is given, so font tests need no
/// binary fixture.
///
/// Only the table directory is exact (the checksums are zero, which no reader here looks at);
/// everything else is whatever the caller handed in. That is what makes the malformed cases —
/// a truncated file, a table that lies about its length, a `cmap` full of junk — reproducible
/// byte for byte instead of reproduced as a binary blob nobody dares to touch.
Uint8List buildSyntheticFont({
  bool includeCmap = true,
  Uint8List? cmapOverride,
  bool includePost = false,
  Uint8List? postOverride,
  Int32List? checksums,
  int? numTablesOverride,
  int? truncateTo,
}) {
  final List<_SfntTable> tables = <_SfntTable>[
    if (includeCmap)
      _SfntTable(tag: 'cmap', bytes: cmapOverride ?? buildSyntheticCmap()),
    if (includePost)
      _SfntTable(tag: 'post', bytes: postOverride ?? buildSyntheticPost()),
    // 除了 cmap / post 之外的覆盖项由具体测试自己拼，这里不预置多余表。
  ];
  final int numTables = numTablesOverride ?? tables.length;
  final int directoryLength = 12 + tables.length * 16;
  int cursor = directoryLength;
  final List<int> offsets = <int>[];
  for (final _SfntTable table in tables) {
    offsets.add(cursor);
    // 表之间按 4 字节对齐，和真实字体的布局一致。
    cursor += (table.bytes.length + 3) & ~3;
  }
  final int total = truncateTo ?? cursor;
  final Uint8List file = Uint8List(total);
  final ByteData data = ByteData.sublistView(file);
  data.setUint32(0, 0x00010000);
  data.setUint16(4, numTables);
  data.setUint16(6, 0);
  data.setUint16(8, 0);
  data.setUint16(10, 0);
  for (int index = 0; index < tables.length; index++) {
    final _SfntTable table = tables[index];
    final int record = 12 + index * 16;
    if (record + 16 > total) {
      break;
    }
    for (int byte = 0; byte < 4; byte++) {
      data.setUint8(record + byte, table.tag.codeUnitAt(byte));
    }
    data.setUint32(record + 4, checksums == null ? 0 : checksums[index]);
    data.setUint32(record + 8, offsets[index]);
    data.setUint32(record + 12, table.bytes.length);
    final int writable = offsets[index] + table.bytes.length <= total
        ? table.bytes.length
        : total - offsets[index];
    if (writable <= 0) {
      continue;
    }
    file.setRange(
      offsets[index],
      offsets[index] + writable,
      table.bytes.sublist(0, writable),
    );
  }

  return file;
}

/// Builds a `cmap` table with one subtable, plus any [additional] subtables.
///
/// [format] picks the subtable shape: `0` (256 bytes), `4` (segments), `6` (trimmed) or `12`
/// (groups).
Uint8List buildSyntheticCmap({
  Map<int, int> codes = const <int, int>{},
  int format = 4,
  int platformId = 3,
  int encodingId = 1,
  bool useDeltaForm = false,
  List<({int platformId, int encodingId, Uint8List subtable})> additional =
      const <({int platformId, int encodingId, Uint8List subtable})>[],
}) {
  final Uint8List first = buildSyntheticSubtable(
    format: format,
    codes: codes,
    useDeltaForm: useDeltaForm,
  );
  final List<({int platformId, int encodingId, Uint8List subtable})> subtables =
      <({int platformId, int encodingId, Uint8List subtable})>[
        (platformId: platformId, encodingId: encodingId, subtable: first),
        ...additional,
      ];
  final int headerLength = 4 + subtables.length * 8;
  int cursor = headerLength;
  final List<int> offsets = <int>[];
  for (final ({int platformId, int encodingId, Uint8List subtable}) subtable
      in subtables) {
    offsets.add(cursor);
    cursor += subtable.subtable.length;
  }
  final Uint8List table = Uint8List(cursor);
  final ByteData data = ByteData.sublistView(table);
  data.setUint16(0, 0);
  data.setUint16(2, subtables.length);
  for (int index = 0; index < subtables.length; index++) {
    final int record = 4 + index * 8;
    data.setUint16(record, subtables[index].platformId);
    data.setUint16(record + 2, subtables[index].encodingId);
    data.setUint32(record + 4, offsets[index]);
    table.setRange(
      offsets[index],
      offsets[index] + subtables[index].subtable.length,
      subtables[index].subtable,
    );
  }

  return table;
}

/// Builds one `cmap` subtable on its own, for tests that need a strange one next to a good one.
Uint8List buildSyntheticSubtable({
  required int format,
  Map<int, int> codes = const <int, int>{},
  bool useDeltaForm = false,
}) => switch (format) {
  0 => _format0(codes),
  6 => _format6(codes),
  12 => _format12(codes),
  _ => _format4(codes, useDeltaForm: useDeltaForm),
};

/// Builds a `post` format 2.0 table carrying [names], or a format 3.0 header when [version3].
///
/// Glyph ids without a name get index `0` (`.notdef`), which is how a font says "no name".
Uint8List buildSyntheticPost({
  int numGlyphs = 3,
  Map<int, String> names = const <int, String>{},
  bool version3 = false,
}) {
  if (version3) {
    return _postHeader(0x00030000);
  }
  final List<String> custom = <String>[];
  final List<int> indices = List<int>.filled(numGlyphs, 0);
  for (final MapEntry<int, String> entry in names.entries) {
    if (entry.key >= numGlyphs) {
      continue;
    }
    final int existing = custom.indexOf(entry.value);
    final int customIndex = existing >= 0 ? existing : custom.length;
    if (existing < 0) {
      custom.add(entry.value);
    }
    indices[entry.key] = 258 + customIndex;
  }
  final int stringsLength = custom.fold<int>(
    0,
    (int sum, String name) => sum + 1 + name.length,
  );
  final Uint8List table = Uint8List(34 + numGlyphs * 2 + stringsLength);
  final ByteData data = ByteData.sublistView(table);
  table.setRange(0, 32, _postHeader(0x00020000));
  data.setUint16(32, numGlyphs);
  int cursor = 34 + numGlyphs * 2;
  for (int glyph = 0; glyph < numGlyphs; glyph++) {
    data.setUint16(34 + glyph * 2, indices[glyph]);
  }
  for (final String name in custom) {
    data.setUint8(cursor, name.length);
    table.setRange(cursor + 1, cursor + 1 + name.length, name.codeUnits);
    cursor += 1 + name.length;
  }

  return table;
}

/// The 32-byte `post` header carrying [version].
Uint8List _postHeader(int version) {
  final Uint8List header = Uint8List(32);
  ByteData.sublistView(header).setUint32(0, version);

  return header;
}

// 一段 [min, max] 的 format 4 子表：glyphIdArray 形态（任意映射）或 delta 形态（等距映射）。
Uint8List _format4(Map<int, int> codes, {required bool useDeltaForm}) {
  final List<int> sorted = codes.keys.toList()..sort();
  final bool hasCodes = sorted.isNotEmpty;
  final int segCount = hasCodes ? 2 : 1;
  final int min = hasCodes ? sorted.first : 0xFFFF;
  final int max = hasCodes ? sorted.last : 0xFFFF;
  final int glyphCount = hasCodes && !useDeltaForm ? max - min + 1 : 0;
  final int length = 14 + segCount * 8 + 2 + glyphCount * 2;
  final Uint8List table = Uint8List(length);
  final ByteData data = ByteData.sublistView(table);
  data.setUint16(0, 4);
  data.setUint16(2, length);
  data.setUint16(6, segCount * 2);
  const int endBase = 14;
  final int startBase = endBase + segCount * 2 + 2;
  final int deltaBase = startBase + segCount * 2;
  final int rangeBase = deltaBase + segCount * 2;
  final int terminator = segCount - 1;
  data.setUint16(endBase + terminator * 2, 0xFFFF);
  data.setUint16(startBase + terminator * 2, 0xFFFF);
  data.setInt16(deltaBase + terminator * 2, 1);
  data.setUint16(rangeBase + terminator * 2, 0);
  if (hasCodes) {
    data.setUint16(endBase, max);
    data.setUint16(startBase, min);
    data.setInt16(deltaBase, useDeltaForm ? (codes[min] ?? 0) - min : 0);
    data.setUint16(rangeBase, useDeltaForm ? 0 : segCount * 2);
    for (int index = 0; index < glyphCount; index++) {
      data.setUint16(
        rangeBase + segCount * 2 + index * 2,
        codes[min + index] ?? 0,
      );
    }
  }

  return table;
}

// format 12：一个码位一组，最直白也最容易核对。
Uint8List _format12(Map<int, int> codes) {
  final List<int> sorted = codes.keys.toList()..sort();
  final int length = 16 + sorted.length * 12;
  final Uint8List table = Uint8List(length);
  final ByteData data = ByteData.sublistView(table);
  data.setUint16(0, 12);
  data.setUint32(4, length);
  data.setUint32(12, sorted.length);
  for (int index = 0; index < sorted.length; index++) {
    final int code = sorted[index];
    data.setUint32(16 + index * 12, code);
    data.setUint32(20 + index * 12, code);
    data.setUint32(24 + index * 12, codes[code] ?? 0);
  }

  return table;
}

// format 6：一段连续码位。
Uint8List _format6(Map<int, int> codes) {
  final List<int> sorted = codes.keys.toList()..sort();
  final int first = sorted.isEmpty ? 0 : sorted.first;
  final int count = sorted.isEmpty ? 0 : sorted.last - first + 1;
  final Uint8List table = Uint8List(10 + count * 2);
  final ByteData data = ByteData.sublistView(table);
  data.setUint16(0, 6);
  data.setUint16(2, table.length);
  data.setUint16(6, first);
  data.setUint16(8, count);
  for (int index = 0; index < count; index++) {
    data.setUint16(10 + index * 2, codes[first + index] ?? 0);
  }

  return table;
}

// format 0：256 个单字节字形。
Uint8List _format0(Map<int, int> codes) {
  final Uint8List table = Uint8List(6 + 256);
  final ByteData data = ByteData.sublistView(table);
  data.setUint16(0, 0);
  data.setUint16(2, table.length);
  for (final MapEntry<int, int> entry in codes.entries) {
    if (entry.key >= 0 && entry.key < 256) {
      data.setUint8(6 + entry.key, entry.value & 0xFF);
    }
  }

  return table;
}
