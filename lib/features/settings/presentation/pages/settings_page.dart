import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_reader/features/settings/presentation/notifiers/settings_notifier.dart';
import 'package:flutter_reader/features/settings/presentation/pages/log_files_page.dart';
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
class SettingsPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

/// State of the page: the in-flight text-scale preview.
class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// The scale while the slider is being dragged; `null` means “show the stored value”.
  ///
  /// 拖动中的值只活在页面上，松手才落盘：每一帧都写 shared_preferences 会让全局主题
  /// 随每像素重建，滑动看起来就是卡顿。
  double? _fontScaleDrag;

  @override
  Widget build(BuildContext context) {
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
      _heading(l10n.settingsSeedColor, tokens),
      _seedColor(ref, settings, tokens, l10n),
      _heading(l10n.settingsBackgroundImage, tokens),
      _backgroundImage(context, ref, settings, tokens, l10n),
      _heading(l10n.settingsFontScale, tokens),
      _fontScale(ref, settings, tokens, l10n),
      _heading(l10n.settingsConcurrency, tokens),
      _concurrency(ref, settings, tokens, l10n),
      _heading(l10n.settingsNetwork, tokens),
      SwitchListTile(
        secondary: const Icon(Icons.http),
        title: Text(l10n.settingsPlainHttp),
        subtitle: Text(l10n.settingsPlainHttpHint),
        value: settings.allowPlainHttp,
        onChanged: (bool allow) => unawaited(
          ref.read(settingsProvider.notifier).setAllowPlainHttp(allow),
        ),
      ),
      _heading(l10n.settingsDiagnostics, tokens),
      _logLevel(ref, settings, tokens, l10n),
      ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(l10n.settingsLogFiles),
        subtitle: Text(l10n.settingsLogFilesBody),
        onTap: () => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const LogFilesPage(),
            ),
          ),
        ),
      ),
      _heading(l10n.settingsCache, tokens),
      ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: Text(l10n.settingsClearCache),
        subtitle: Text(l10n.settingsClearCacheBody),
        onTap: () => unawaited(_clearCache(context, ref, l10n)),
      ),
    ],
  );

  /// Builds the log-level selector (`ADR-0082`): the change applies to the running app at once.
  Widget _logLevel(
    WidgetRef ref,
    AppSettings settings,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => Padding(
    padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownButton<LogLevel>(
          value: settings.logLevel,
          isExpanded: true,
          items: <DropdownMenuItem<LogLevel>>[
            for (final LogLevel level in LogLevel.values)
              DropdownMenuItem<LogLevel>(
                value: level,
                child: Text(logLevelLabel(level, l10n)),
              ),
          ],
          onChanged: (LogLevel? level) {
            if (level != null) {
              unawaited(ref.read(settingsProvider.notifier).setLogLevel(level));
            }
          },
        ),
        Text(
          l10n.settingsLogLevelHint,
          style: tokens.typography.base.bodySmall,
        ),
      ],
    ),
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

  /// Builds the seed-colour swatches plus 「默认」 (`ADR-0075` §决策 1).
  Widget _seedColor(
    WidgetRef ref,
    AppSettings settings,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => Padding(
    padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: <Widget>[
            for (final Color preset in themeSeedPresets())
              _swatch(
                ref,
                key: ValueKey<String>('seedColor-${preset.toARGB32()}'),
                color: preset,
                isSelected: settings.seedColor == preset.toARGB32(),
                tokens: tokens,
                label: l10n.settingsSeedColor,
              ),
            _defaultSwatch(ref, settings, tokens, l10n),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: tokens.spacing.xs),
          child: Text(
            l10n.settingsSeedColorHint,
            style: tokens.typography.base.bodySmall,
          ),
        ),
      ],
    ),
  );

  /// One selectable seed colour.
  Widget _swatch(
    WidgetRef ref, {
    required Key key,
    required Color color,
    required bool isSelected,
    required M3ETheme tokens,
    required String label,
  }) => Semantics(
    button: true,
    selected: isSelected,
    label: label,
    child: InkWell(
      key: key,
      borderRadius: tokens.shapes.round.xs,
      onTap: () => unawaited(
        ref.read(settingsProvider.notifier).setSeedColor(color.toARGB32()),
      ),
      child: Container(
        width: tokens.spacing.xxl,
        height: tokens.spacing.xxl,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: tokens.colors.onSurface, width: 2)
              : null,
        ),
      ),
    ),
  );

  /// The 「默认」 swatch: clears the stored seed.
  Widget _defaultSwatch(
    WidgetRef ref,
    AppSettings settings,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => Tooltip(
    message: l10n.settingsSeedColorDefault,
    child: InkWell(
      key: const ValueKey<String>('seedColor-default'),
      borderRadius: tokens.shapes.round.xs,
      onTap: () =>
          unawaited(ref.read(settingsProvider.notifier).setSeedColor(null)),
      child: Container(
        width: tokens.spacing.xxl,
        height: tokens.spacing.xxl,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.colors.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: settings.seedColor == null
              ? Border.all(color: tokens.colors.onSurface, width: 2)
              : null,
        ),
        child: Icon(Icons.restart_alt, size: tokens.spacing.md),
      ),
    ),
  );

  /// Builds the background-image row: what is stored, and how to change it.
  Widget _backgroundImage(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      ListTile(
        leading: const Icon(Icons.image_outlined),
        title: Text(
          settings.backgroundImageName ?? l10n.settingsBackgroundImageNone,
        ),
        subtitle: Text(l10n.settingsBackgroundImageHint),
      ),
      // 两个动作放在标题下方而不是 trailing：中文标签在窄屏上会把标题挤成一字一行。
      Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
        child: Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.xs,
          alignment: WrapAlignment.end,
          children: <Widget>[
            if (settings.backgroundImageName != null)
              TextButton(
                onPressed: () => unawaited(
                  ref.read(settingsProvider.notifier).removeBackgroundImage(),
                ),
                child: Text(l10n.settingsBackgroundImageRemove),
              ),
            FilledButton.tonal(
              onPressed: () =>
                  unawaited(_pickBackgroundImage(context, ref, l10n)),
              child: Text(l10n.settingsBackgroundImageChoose),
            ),
          ],
        ),
      ),
    ],
  );

  /// Picks an image and reports a failed copy; a cancel stays silent.
  Future<void> _pickBackgroundImage(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final ParseResult<bool> result = await ref
        .read(settingsProvider.notifier)
        .pickBackgroundImage();
    if (!context.mounted || result is! ParseFailure<bool>) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsBackgroundImageFailed)));
  }

  /// Builds the text-scale slider; the current value is spelled as a percentage.
  ///
  /// 拖动中只改本地预览（`_fontScaleDrag`），松手才写设置：写设置会让整个 `MaterialApp`
  /// 按新字号重建一次，每帧写一次就是肉眼可见的卡顿。
  Widget _fontScale(
    WidgetRef ref,
    AppSettings settings,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) {
    final double value = _fontScaleDrag ?? settings.fontScale;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.settingsFontScaleValue((value * 100).round()),
            style: tokens.typography.base.bodyMedium,
          ),
          Slider(
            value: value,
            min: minFontScale,
            max: maxFontScale,
            // 0.1 一档：步进太细会让用户按不出想要的值，太粗又无法微调。
            divisions: 12,
            label: l10n.settingsFontScaleValue((value * 100).round()),
            onChanged: (double next) => setState(() => _fontScaleDrag = next),
            onChangeEnd: (double next) => unawaited(
              ref
                  .read(settingsProvider.notifier)
                  .setFontScale(next)
                  .whenComplete(() {
                    if (mounted) {
                      setState(() => _fontScaleDrag = null);
                    }
                  }),
            ),
          ),
        ],
      ),
    );
  }

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
