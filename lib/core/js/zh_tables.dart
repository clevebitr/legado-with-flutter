/// The two zh conversion tables `java.t2s` / `java.s2t` use (M25/S3b).
///
/// The tables are Flutter **assets** (`assets/zh/`, generated from OpenCC — see that folder's README).
/// The worker isolate cannot read assets on its own (`rootBundle` needs the main isolate), so the bridge
/// hands the raw text over when it spawns the worker and this class parses it **on first use**: reading
/// 875 KB is cheap, building 46 000 map entries is not, and most sources never call these helpers.
library;

import 'package:flutter_reader/core/js/zh_converter.dart';

/// One worker's conversion tables.
final class ZhTables {
  /// Creates the holder around the raw asset texts (`null` = this build has no such table).
  ZhTables({this.t2sText, this.s2tText});

  /// The 繁→简 table text, as shipped.
  final String? t2sText;

  /// The 简→繁 table text, as shipped.
  final String? s2tText;

  ZhConverter? _t2s;
  ZhConverter? _s2t;
  bool _t2sParsed = false;
  bool _s2tParsed = false;

  /// The 繁→简 converter, parsing it now when [needed] and it has not been parsed yet.
  ///
  /// `null` when the table is missing from this build; the sandbox reports that as a readable failure
  /// instead of pretending the text was already simplified.
  ZhConverter? t2s({bool needed = true}) {
    if (!needed || _t2sParsed) {
      return _t2s;
    }
    final String? text = t2sText;
    if (text == null) {
      return null;
    }
    _t2sParsed = true;

    return _t2s = ZhConverter.parse(text);
  }

  /// The 简→繁 converter; same contract as [t2s].
  ZhConverter? s2t({bool needed = true}) {
    if (!needed || _s2tParsed) {
      return _s2t;
    }
    final String? text = s2tText;
    if (text == null) {
      return null;
    }
    _s2tParsed = true;

    return _s2t = ZhConverter.parse(text);
  }

  /// Whether the sandbox spelling of either helper appears in [script] / [library].
  ///
  /// A plain substring test is enough (`java.t2s(...)`); a false positive only costs one parse.
  static ({bool t2s, bool s2t}) needsOf(String script, String? library) {
    final String text = library == null ? script : '$script\n$library';

    return (t2s: text.contains('t2s'), s2t: text.contains('s2t'));
  }
}
