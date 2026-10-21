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
}) => tokens.typography.base.bodyLarge!.copyWith(
  fontSize: (tokens.typography.base.bodyLarge!.fontSize ?? 16) * fontScale,
  height: lineHeight,
  color: foreground,
);
