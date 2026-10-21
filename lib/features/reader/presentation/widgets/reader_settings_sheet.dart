import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// The reader's settings sheet (`docs/dev/roadmap.md` 5.3, ADR-0044 §决策 1).
///
/// Four axes, all of them the **reader's own**: body size, line spacing, background and page mode.
/// The app-wide text scale stays on the settings page — this sheet says so in its labels so the
/// two knobs do not look like duplicates of each other.
///
/// It is a stateless view: every change is handed straight back through [onChanged], which is what
/// lets the reader apply it without closing the sheet.
class ReaderSettingsSheet extends StatelessWidget {
  /// Creates the sheet.
  const ReaderSettingsSheet({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  /// The settings the sheet starts with.
  final ReaderSettings settings;

  /// Called with the new settings on every change.
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.readerSettingsAction,
              style: tokens.typography.base.titleMedium,
            ),
            SizedBox(height: tokens.spacing.md),
            _slider(
              context,
              label: l10n.readerFontSize,
              value: settings.fontScale,
              min: minReaderFontScale,
              max: maxReaderFontScale,
              divisions: 12,
              onChanged: (double value) =>
                  onChanged(settings.copyWith(fontScale: value)),
            ),
            _slider(
              context,
              label: l10n.readerLineHeight,
              value: settings.lineHeight,
              min: minReaderLineHeight,
              max: maxReaderLineHeight,
              divisions: 12,
              onChanged: (double value) =>
                  onChanged(settings.copyWith(lineHeight: value)),
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(
              l10n.readerBackground,
              style: tokens.typography.base.labelLarge,
            ),
            SizedBox(height: tokens.spacing.sm),
            Wrap(
              spacing: tokens.spacing.sm,
              children: <Widget>[
                for (final ReaderBackground background
                    in ReaderBackground.values)
                  ChoiceChip(
                    label: Text(_backgroundLabel(l10n, background)),
                    selected: settings.background == background,
                    onSelected: (_) =>
                        onChanged(settings.copyWith(background: background)),
                  ),
              ],
            ),
            SizedBox(height: tokens.spacing.md),
            Text(l10n.readerPageMode, style: tokens.typography.base.labelLarge),
            SizedBox(height: tokens.spacing.sm),
            SegmentedButton<ReaderPageMode>(
              segments: <ButtonSegment<ReaderPageMode>>[
                ButtonSegment<ReaderPageMode>(
                  value: ReaderPageMode.scroll,
                  label: Text(l10n.readerPageModeScroll),
                ),
                ButtonSegment<ReaderPageMode>(
                  value: ReaderPageMode.paged,
                  label: Text(l10n.readerPageModePaged),
                ),
              ],
              selected: <ReaderPageMode>{settings.pageMode},
              onSelectionChanged: (Set<ReaderPageMode> selection) =>
                  onChanged(settings.copyWith(pageMode: selection.single)),
            ),
          ],
        ),
      ),
    );
  }

  /// One labelled slider row.
  Widget _slider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final M3ETheme tokens = context.m3e;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: tokens.typography.base.labelLarge),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// The ARB label of [background].
  String _backgroundLabel(AppLocalizations l10n, ReaderBackground background) =>
      switch (background) {
        ReaderBackground.system => l10n.readerBackgroundSystem,
        ReaderBackground.paper => l10n.readerBackgroundPaper,
        ReaderBackground.sepia => l10n.readerBackgroundSepia,
        ReaderBackground.dark => l10n.readerBackgroundDark,
      };
}
