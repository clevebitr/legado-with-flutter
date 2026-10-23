import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_reader/features/settings/presentation/notifiers/settings_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The user-facing settings (`docs/dev/roadmap.md` 5.6).
///
/// Every control writes through [Settings] and then renders the **stored** value, so a clamped
/// budget shows the number that is actually in effect (a `0` concurrency budget is impossible by
/// construction, see [AppSettings]).
///
/// The 「关于」 entry is deliberately absent: it belongs to 5.9's legal-notice page, and a menu
/// row that opens nothing would be a dead end (C-BAN-2). The roadmap registers that split.
class SettingsPage extends ConsumerWidget {
  /// Creates the page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<AppSettings> settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: switch (settings) {
        AsyncData<AppSettings>(:final AppSettings value) => _body(
          context,
          ref,
          value,
          tokens,
          l10n,
        ),
        AsyncError<AppSettings>() => StateMessage(
          message: l10n.settingsLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Builds the settings list for [settings].
  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => ListView(
    padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
    children: <Widget>[
      _heading(l10n.settingsThemeMode, tokens),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
        child: SegmentedButton<AppThemeMode>(
          segments: <ButtonSegment<AppThemeMode>>[
            ButtonSegment<AppThemeMode>(
              value: AppThemeMode.system,
              label: Text(l10n.settingsThemeSystem),
            ),
            ButtonSegment<AppThemeMode>(
              value: AppThemeMode.light,
              label: Text(l10n.settingsThemeLight),
            ),
            ButtonSegment<AppThemeMode>(
              value: AppThemeMode.dark,
              label: Text(l10n.settingsThemeDark),
            ),
          ],
          selected: <AppThemeMode>{settings.themeMode},
          onSelectionChanged: (Set<AppThemeMode> selection) => unawaited(
            ref.read(settingsProvider.notifier).setThemeMode(selection.first),
          ),
        ),
      ),
      _heading(l10n.settingsFontScale, tokens),
      _fontScale(ref, settings, tokens, l10n),
      _heading(l10n.settingsConcurrency, tokens),
      _concurrency(ref, settings, tokens, l10n),
      _heading(l10n.settingsCache, tokens),
      ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: Text(l10n.settingsClearCache),
        subtitle: Text(l10n.settingsClearCacheBody),
        onTap: () => unawaited(_clearCache(context, ref, l10n)),
      ),
    ],
  );

  /// Builds a section heading.
  Widget _heading(String title, M3ETheme tokens) => Padding(
    padding: EdgeInsets.fromLTRB(
      tokens.spacing.lg,
      tokens.spacing.lg,
      tokens.spacing.lg,
      tokens.spacing.sm,
    ),
    child: Text(title, style: tokens.typography.base.titleMedium),
  );

  /// Builds the text-scale slider; the current value is spelled as a percentage.
  Widget _fontScale(
    WidgetRef ref,
    AppSettings settings,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => Padding(
    padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.settingsFontScaleValue((settings.fontScale * 100).round()),
          style: tokens.typography.base.bodyMedium,
        ),
        Slider(
          value: settings.fontScale,
          min: minFontScale,
          max: maxFontScale,
          // 0.1 一档：步进太细会让用户按不出想要的值，太粗又无法微调。
          divisions: 12,
          onChanged: (double value) => unawaited(
            ref.read(settingsProvider.notifier).setFontScale(value),
          ),
        ),
      ],
    ),
  );

  /// Builds the per-source concurrency control.
  ///
  /// A stepper rather than a slider: the value is a small integer, and every step must be a
  /// value `RequestLimiter` accepts ([minConcurrentBudget]..[maxConcurrentBudget]).
  Widget _concurrency(
    WidgetRef ref,
    AppSettings settings,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => ListTile(
    leading: const Icon(Icons.speed_outlined),
    title: Text('${settings.maxConcurrentPerSource}'),
    subtitle: Text(l10n.settingsConcurrencyHint),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.remove),
          tooltip: l10n.actionDecrease,
          onPressed: settings.maxConcurrentPerSource > minConcurrentBudget
              ? () => unawaited(
                  ref
                      .read(settingsProvider.notifier)
                      .setMaxConcurrentPerSource(
                        settings.maxConcurrentPerSource - 1,
                      ),
                )
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.actionIncrease,
          onPressed: settings.maxConcurrentPerSource < maxConcurrentBudget
              ? () => unawaited(
                  ref
                      .read(settingsProvider.notifier)
                      .setMaxConcurrentPerSource(
                        settings.maxConcurrentPerSource + 1,
                      ),
                )
              : null,
        ),
      ],
    ),
  );

  /// Asks, empties the cache, and reports how many entries went away.
  Future<void> _clearCache(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final bool confirmed = await _confirm(
      context,
      title: l10n.settingsClearCacheTitle,
      body: l10n.settingsClearCacheBody,
      l10n: l10n,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final ParseResult<int> result = await ref
        .read(settingsProvider.notifier)
        .clearCache();
    if (!context.mounted) {
      return;
    }

    final String message = switch (result) {
      ParseSuccess<int>(:final int data) => l10n.settingsCacheCleared(data),
      ParseFailure<int>(:final ParseFailureKind kind) => resolveFailureMessage(
        l10n,
        kind,
      ),
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Asks a yes / no question.
  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required AppLocalizations l10n,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }
}
