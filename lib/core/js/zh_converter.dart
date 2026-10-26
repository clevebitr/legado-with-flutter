/// Simplified↔traditional conversion for `java.t2s` / `java.s2t` (M25/S3b).
///
/// Upstream calls a third-party Java library whose dictionary has **no licence file** (`NOTICE.md` §5),
/// so this repository ships its own tables generated from OpenCC (Apache-2.0) — see `assets/zh/README.md`
/// for provenance, the generation rule and the hashes. The converter itself is deliberately tiny:
/// a `key=value` table plus longest-match replacement, which is what the tables are shaped for.
library;

/// One conversion direction: the parsed table plus the longest key it holds.
///
/// Parsing keeps the whole table in memory (33 KB for `t2s`, 842 KB for `s2t`) and remembers the
/// longest key so [convert] can try lengths from longest to shortest — OpenCC's phrase entries
/// (`一目瞭然=一目了然`) must win over its single-character entries (`瞭=了`).
final class ZhConverter {
  /// Parses a table of `key=value` lines; blank lines and `#` comments are skipped.
  ///
  /// A malformed line (no `=`, empty key or empty value) is skipped rather than failing the whole
  /// table: one bad row must not cost a source its conversion.
  factory ZhConverter.parse(String table) {
    final Map<String, String> entries = <String, String>{};
    int longest = 1;
    for (final String raw in table.split('\n')) {
      // 仓库里的表用 LF；Windows 检出时可能带 CR，逐行剔掉，避免键尾多一个字符永远匹配不上。
      final String line = raw.endsWith('\r')
          ? raw.substring(0, raw.length - 1)
          : raw;
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final int separator = line.indexOf('=');
      if (separator <= 0 || separator == line.length - 1) {
        continue;
      }
      final String key = line.substring(0, separator);
      entries[key] = line.substring(separator + 1);
      if (key.length > longest) {
        longest = key.length;
      }
    }

    return ZhConverter._(entries, longest);
  }

  const ZhConverter._(this._entries, this._longestKey);

  final Map<String, String> _entries;
  final int _longestKey;

  /// How many entries the table holds.
  int get length => _entries.length;

  /// The longest key in the table, in code units (phrase keys are the long ones).
  int get longestKey => _longestKey;

  /// Converts [text] by longest match: phrases first, then single characters, else copy through.
  String convert(String text) {
    if (_entries.isEmpty || text.isEmpty) {
      return text;
    }
    final StringBuffer buffer = StringBuffer();
    int index = 0;
    while (index < text.length) {
      final int remaining = text.length - index;
      final int longest = remaining < _longestKey ? remaining : _longestKey;
      String? replacement;
      int matched = 0;
      for (int length = longest; length > 0; length--) {
        final String candidate = text.substring(index, index + length);
        final String? value = _entries[candidate];
        if (value != null) {
          replacement = value;
          matched = length;
          break;
        }
      }
      if (replacement == null) {
        buffer.writeCharCode(text.codeUnitAt(index));
        index += 1;
      } else {
        buffer.write(replacement);
        index += matched;
      }
    }

    return buffer.toString();
  }
}
