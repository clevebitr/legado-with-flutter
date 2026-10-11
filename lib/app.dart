import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Root widget: wires theming, localization and the initial route.
///
/// Dynamic color is resolved through `core/platform/`, so this file never talks
/// to `dynamic_color` nor asks which platform it runs on (C-PLT-1, C-PLT-2).
class ReaderApp extends ConsumerWidget {
  /// Creates the root widget.
  const ReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DynamicColorProvider? dynamicColor = ref.watch(
      platformDynamicColorProvider,
    );

    // 平台没有动态取色（Windows/iOS/测试）时直接走种子色 fallback（C-PLT-3/4）。
    return dynamicColor?.resolve(_buildApp) ?? _buildApp(null, null);
  }

  /// Builds the [MaterialApp] from the resolved platform schemes.
  ///
  /// A `null` scheme means "the platform has none", which is the normal fallback
  /// branch and never an error (C-TYPE-2, ADR-0004 §6).
  Widget _buildApp(ColorScheme? lightDynamic, ColorScheme? darkDynamic) =>
      MaterialApp(
        onGenerateTitle: (BuildContext context) =>
            AppLocalizations.of(context).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(lightDynamic ?? fallbackLightColorScheme()),
        darkTheme: buildReaderTheme(darkDynamic ?? fallbackDarkColorScheme()),
        home: const _HomePlaceholder(),
      );
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
