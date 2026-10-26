import 'package:flutter_reader/core/font/ttf_font.dart';

/// The fonts one JS job asked for, keyed by the handle its sandbox object carries.
///
/// A font never crosses into the script: `java.queryTTF` / `java.queryBase64TTF` answer an opaque
/// `{__ttf: true, id}` object and `java.replaceFont` hands the handle back, so a chapter with a
/// 200 KB font costs one small envelope instead of a JSON copy of every glyph
/// (`docs/dev/book-source.md` §6, ADR-0068 §决策 9).
///
/// Handles are scoped to the job that asked for them: the worker clears the registry when a job
/// starts, and ids are never reused (`nextId` keeps climbing), so a script that stored a handle in
/// `globalThis` gets "unknown font" instead of silently reading another source's font.
final class JsFontRegistry {
  /// Creates a registry holding at most [maxFonts] fonts (a chapter needs two).
  JsFontRegistry({this.maxFonts = 8});

  /// How many fonts stay resolved at once; the oldest is dropped first.
  final int maxFonts;

  // 插入顺序即「谁最老」：Dart 的 Map 字面量保留插入顺序。
  final Map<int, TtfFont> _fonts = <int, TtfFont>{};
  int _nextId = 1;

  /// How many fonts are currently resolved.
  int get length => _fonts.length;

  /// Registers [font] and answers the handle id the sandbox will carry.
  int add(TtfFont font) {
    while (_fonts.length >= maxFonts) {
      _fonts.remove(_fonts.keys.first);
    }
    final int id = _nextId++;
    _fonts[id] = font;

    return id;
  }

  /// The font a handle refers to, or `null` when it is not a live handle.
  TtfFont? resolve(Object? handle) => handle is int ? _fonts[handle] : null;

  /// Forgets every font; called when a job starts.
  void clear() => _fonts.clear();
}
