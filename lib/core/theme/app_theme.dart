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
ColorScheme fallbackLightColorScheme() =>
    ColorScheme.fromSeed(seedColor: defaultSeedColor);

/// Returns the dark color scheme used when dynamic color is unavailable.
ColorScheme fallbackDarkColorScheme() => ColorScheme.fromSeed(
  seedColor: defaultSeedColor,
  brightness: Brightness.dark,
);
