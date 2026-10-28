/// The reader's palette and body text style (`docs/dev/roadmap.md` 5.3, ADR-0044 §决策 1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:m3e_design/m3e_design.dart';

/// The surface / text pair one [ReaderBackground] paints.
///
/// It is a **derived** pair, never a hardcoded colour (C-UI-1): `system` is the theme's own
/// surface, the two tints blend a theme colour into it at a low alpha, and `dark` uses the theme's
/// inverse surface — so the reader keeps following the theme and dynamic colour while still
/// offering the four choices a reader expects.
({Color background, Color foreground}) readerPalette(
  M3ETheme tokens,
  ReaderBackground background,
) => switch (background) {
  ReaderBackground.system => (
    background: tokens.colors.surface,
    foreground: tokens.colors.onSurface,
  ),
  ReaderBackground.paper => (
    background: Color.alphaBlend(
      tokens.colors.primary.withValues(alpha: 0.06),
      tokens.colors.surface,
    ),
    foreground: tokens.colors.onSurface,
  ),
  ReaderBackground.sepia => (
    background: Color.alphaBlend(
      tokens.colors.tertiary.withValues(alpha: 0.12),
      tokens.colors.surface,
    ),
    foreground: tokens.colors.onSurface,
  ),
  ReaderBackground.dark => (
    background: tokens.colors.inverseSurface,
    foreground: tokens.colors.onInverseSurface,
  ),
};

/// The warm (blue-light reducing) filter of [strength] percent, or `null` when it is off.
///
/// Upstream blends towards a 2596–5500 K colour temperature (`EyeProtection.kt`); this is the same
/// idea in one colour matrix — red keeps its weight, green loses a little and blue loses most of
/// it, with a small negative offset on both so the tint lands on the paper rather than on the
/// whole screen. It is a **filter over the page**, not a system feature: the display's own
/// brightness is untouched (ADR-0086 §决策 2).
///
/// A pure function on purpose: the strength → filter mapping is the part worth pinning in a test.
ColorFilter? readerEyeProtectionFilter(int strength) {
  final List<double>? matrix = readerEyeProtectionMatrix(strength);

  return matrix == null ? null : ColorFilter.matrix(matrix);
}

/// The colour matrix behind [readerEyeProtectionFilter], or `null` when the filter is off.
///
/// Split out because [ColorFilter] does not expose its numbers: the mapping is what a test can
/// pin, and the widget only needs the wrapped form.
List<double>? readerEyeProtectionMatrix(int strength) {
  final int clamped = strength.clamp(0, maxReaderEyeProtection);
  if (clamped == 0) {
    return null;
  }
  final double k = clamped / maxReaderEyeProtection;

  return <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1 - 0.08 * k,
    0,
    0,
    -4 * k,
    0,
    0,
    1 - 0.30 * k,
    0,
    -12 * k,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// The body text style of the reader.
///
/// [fontScale] multiplies the theme's body size and [lineHeight] sets its line spacing; the
/// platform's own accessibility scale is applied on top by the painter and the widget both, so the
/// two never disagree about what a page is (ADR-0044 §决策 1).
TextStyle readerTextStyle({
  required M3ETheme tokens,
  required double fontScale,
  required double lineHeight,
  required Color foreground,
  ReaderFontFamily family = ReaderFontFamily.theme,
}) {
  // 主题没有 bodyLarge 时用基线的 16 号字：阅读正文永远不能因此变成默认的 14 号。
  final TextStyle base =
      tokens.typography.base.bodyLarge ?? const TextStyle(fontSize: 16);

  return base.copyWith(
    fontSize: (base.fontSize ?? 16) * fontScale,
    height: lineHeight,
    color: foreground,
    // 平台通用族名（ADR-0051 §决策 4）：缺字体时 Flutter 回落到系统字体，不会出现豆腐块。
    fontFamily: readerFontFamilyName(family),
  );
}

/// The newline character the body layout joins paragraphs with.
final String _newline = String.fromCharCode(10);

/// The body text as it should be **laid out**: paragraph spacing and first-line indent applied.
///
/// The transform happens here rather than in the parser because it is presentation: the same
/// chapter is readable with and without it, and the cache stores the source's own text
/// (ADR-0051 §决策 4). Indentation uses the ideographic space, which is exactly one em in a CJK
/// font — the unit the setting is expressed in — and four spaces for a Latin body.
String readerBodyText(String body, ReaderSettings settings) {
  final String indent = _indentUnit(body) * settings.firstLineIndent.round();
  // 段距 0 → 直接换行；0.5 → 一个空行；1 → 两个空行（0–2 个空行的直观刻度）。
  final String separator =
      _newline * (1 + (settings.paragraphSpacing * 2).round());
  final List<String> paragraphs = <String>[
    for (final String line in body.split('\n'))
      // 源站的空行是页面结构，不是段落：丢掉它们，段距由设置决定。
      if (line.trim().isNotEmpty) '$indent${line.trim()}',
  ];

  return paragraphs.join(separator);
}

/// The character one indent step uses: the ideographic space for CJK, four spaces otherwise.
String _indentUnit(String body) =>
    body.runes.any((int rune) => rune > 0x2E80) ? '\u3000' : '    ';

/// The style the sentence being read aloud is painted with (`ADR-0062 §决策 5`).
///
/// Only colours change: the metrics stay exactly those of [style], because the paged body measures
/// its pages with that very style (`readerPageStarts`) and a heavier weight would reflow the page
/// under the reader's eyes.
TextStyle spokenSentenceStyle(BuildContext context, TextStyle style) {
  final M3ETheme tokens = context.m3e;

  return style.copyWith(
    backgroundColor: tokens.colors.primaryContainer,
    color: tokens.colors.onPrimaryContainer,
  );
}

/// [body]`[start, end)` as one span, with [highlight] painted in [highlightStyle].
///
/// The range is **clamped** into the slice: a page shows a window of the body and the engine's
/// sentence may start before or end after it, so the highlight is clipped instead of skipped
/// (ADR-0062 §决策 5). Nothing is highlighted when the two ranges do not overlap at all.
TextSpan readingSpan({
  required String body,
  required TextStyle style,
  required TextStyle highlightStyle,
  required ({int start, int end})? highlight,
  int start = 0,
  int? end,
}) {
  final int stop = (end ?? body.length).clamp(start, body.length);
  if (highlight == null) {
    return TextSpan(text: body.substring(start, stop), style: style);
  }
  final int from = highlight.start.clamp(start, stop);
  final int to = highlight.end.clamp(start, stop);
  if (from >= to) {
    return TextSpan(text: body.substring(start, stop), style: style);
  }

  return TextSpan(
    style: style,
    children: <TextSpan>[
      if (from > start) TextSpan(text: body.substring(start, from)),
      TextSpan(text: body.substring(from, to), style: highlightStyle),
      if (to < stop) TextSpan(text: body.substring(to, stop)),
    ],
  );
}

/// [readingSpan] as a widget: a plain [Text] unless something is highlighted.
///
/// The plain path is not just an optimisation: a `Text.rich` carries its style on the spans, so the
/// body's own [TextStyle] would no longer be readable from the widget tree (and the reader's style
/// tests check exactly that).
Widget readingText({
  required String body,
  required TextStyle style,
  required TextStyle highlightStyle,
  required ({int start, int end})? highlight,
  int start = 0,
  int? end,
}) {
  final TextSpan span = readingSpan(
    body: body,
    style: style,
    highlightStyle: highlightStyle,
    highlight: highlight,
    start: start,
    end: end,
  );

  return span.children == null
      ? Text(span.text ?? '', style: style)
      : Text.rich(span);
}
