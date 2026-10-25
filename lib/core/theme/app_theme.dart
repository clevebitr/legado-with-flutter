import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

/// Seed color used when the platform provides no dynamic color scheme.
///
/// This is the only color literal allowed in the project; everything else must
/// come from the design tokens.
const Color defaultSeedColor = Color(0xFF6750A4);

/// Builds a Material 3 Expressive theme from [scheme].
///
/// Installs the `M3ETheme` extension, readable as `context.m3e`.
ThemeData buildReaderTheme(ColorScheme scheme) => scheme.toM3EThemeData();

/// Returns the light color scheme used when dynamic color is unavailable.
///
/// [seedColor] is the colour the user picked in the settings (`ADR-0075` §决策 1); `null` keeps the
/// project default. Dynamic color still wins over this: the page only offers a seed because not every
/// platform reports a system scheme.
ColorScheme fallbackLightColorScheme({Color? seedColor}) =>
    ColorScheme.fromSeed(seedColor: seedColor ?? defaultSeedColor);

/// Returns the dark color scheme used when dynamic color is unavailable.
ColorScheme fallbackDarkColorScheme({Color? seedColor}) => ColorScheme.fromSeed(
  seedColor: seedColor ?? defaultSeedColor,
  brightness: Brightness.dark,
);

/// The seed colours the settings page offers.
///
/// Derived from [defaultSeedColor] by rotating the hue instead of listing colour literals: C-UI-1
/// allows exactly one literal in this file, and a palette is not a reason to add six more.
List<Color> themeSeedPresets() {
  final HSVColor base = HSVColor.fromColor(defaultSeedColor);

  return <Color>[
    for (final double hue in const <double>[0, 40, 75, 120, 200, 280])
      base.withHue(hue).toColor(),
  ];
}
