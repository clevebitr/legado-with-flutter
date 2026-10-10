import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// Root widget: wires theming, localization and the initial route.
class ReaderApp extends StatelessWidget {
  /// Creates the root widget.
  const ReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context).appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildReaderTheme(lightDynamic ?? fallbackLightColorScheme()),
          darkTheme: buildReaderTheme(darkDynamic ?? fallbackDarkColorScheme()),
          home: const _HomePlaceholder(),
        );
      },
    );
  }
}

/// Landing screen shown until the book source feature is implemented.
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    final M3ETheme tokens = context.m3e;
    return Scaffold(
      backgroundColor: tokens.colors.surface,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.xl),
          child: Text(
            AppLocalizations.of(context).bookSourceListTitle,
            style: tokens.typography.base.titleLarge,
          ),
        ),
      ),
    );
  }
}
