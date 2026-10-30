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
      // 七个控件在窄屏或大字号下放不进默认的 9/16 高度：整张面板可滚动。
      child: SingleChildScrollView(
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
            Text(
              l10n.readerFontFamily,
              style: tokens.typography.base.labelLarge,
            ),
            SizedBox(height: tokens.spacing.sm),
            Wrap(
              spacing: tokens.spacing.sm,
              children: <Widget>[
                for (final ReaderFontFamily family in ReaderFontFamily.values)
                  ChoiceChip(
                    label: Text(_familyLabel(l10n, family)),
                    selected: settings.fontFamily == family,
                    onSelected: (_) =>
                        onChanged(settings.copyWith(fontFamily: family)),
                  ),
              ],
            ),
            SizedBox(height: tokens.spacing.md),
            Text(
              l10n.readerParagraphSpacing,
              style: tokens.typography.base.labelLarge,
            ),
            SizedBox(height: tokens.spacing.sm),
            SegmentedButton<double>(
              segments: <ButtonSegment<double>>[
                for (final double step in readerParagraphSpacingSteps)
                  ButtonSegment<double>(
                    value: step,
                    label: Text(_stepLabel(step)),
                  ),
              ],
              selected: <double>{settings.paragraphSpacing},
              onSelectionChanged: (Set<double> selection) => onChanged(
                settings.copyWith(paragraphSpacing: selection.single),
              ),
            ),
            SizedBox(height: tokens.spacing.md),
            Text(
              l10n.readerFirstLineIndent,
              style: tokens.typography.base.labelLarge,
            ),
            SizedBox(height: tokens.spacing.sm),
            SegmentedButton<double>(
              segments: <ButtonSegment<double>>[
                for (final double step in readerFirstLineIndentSteps)
                  ButtonSegment<double>(
                    value: step,
                    label: Text(_stepLabel(step)),
                  ),
              ],
              selected: <double>{settings.firstLineIndent},
              onSelectionChanged: (Set<double> selection) => onChanged(
                settings.copyWith(firstLineIndent: selection.single),
              ),
            ),
            SizedBox(height: tokens.spacing.md),
            Text(
              l10n.readerPagePadding,
              style: tokens.typography.base.labelLarge,
            ),
            SizedBox(height: tokens.spacing.sm),
            Wrap(
              spacing: tokens.spacing.sm,
              children: <Widget>[
                for (final ReaderPagePadding padding
                    in ReaderPagePadding.values)
                  ChoiceChip(
                    label: Text(_paddingLabel(l10n, padding)),
                    selected: settings.pagePadding == padding,
                    onSelected: (_) =>
                        onChanged(settings.copyWith(pagePadding: padding)),
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
            SizedBox(height: tokens.spacing.md),
            // 护眼（ADR-0086 §决策 2）：强度 0 = 关；只压暖正文，不动系统亮度。
            _slider(
              context,
              label: l10n.readerEyeProtection,
              value: settings.eyeProtection.toDouble(),
              min: 0,
              max: maxReaderEyeProtection.toDouble(),
              divisions: 10,
              onChanged: (double value) =>
                  onChanged(settings.copyWith(eyeProtection: value.round())),
            ),
            // 常亮（ADR-0086 §决策 1）：默认开，因为阅读本来就是「很久不碰屏幕」。
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.readerKeepAwake,
                style: tokens.typography.base.labelLarge,
              ),
              value: settings.keepScreenAwake,
              onChanged: (bool value) =>
                  onChanged(settings.copyWith(keepScreenAwake: value)),
            ),
            // 状态栏（ADR-0086 §决策 6）：章节 / 进度 / 时间 / 电量。
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.readerStatusLine,
                style: tokens.typography.base.labelLarge,
              ),
              value: settings.showReaderStatus,
              onChanged: (bool value) =>
                  onChanged(settings.copyWith(showReaderStatus: value)),
            ),
            // 自动翻页间隔（ADR-0093 §决策 1）：开关在工具条上，这里只调快慢。
            _slider(
              context,
              label: l10n.readerAutoPageInterval(settings.autoPageSeconds),
              value: settings.autoPageSeconds.toDouble(),
              min: minReaderAutoPageSeconds.toDouble(),
              max: maxReaderAutoPageSeconds.toDouble(),
              divisions: maxReaderAutoPageSeconds - minReaderAutoPageSeconds,
              onChanged: (double value) =>
                  onChanged(settings.copyWith(autoPageSeconds: value.round())),
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

  /// The ARB label of [family].
  String _familyLabel(AppLocalizations l10n, ReaderFontFamily family) =>
      switch (family) {
        ReaderFontFamily.theme => l10n.readerFontFamilyTheme,
        ReaderFontFamily.serif => l10n.readerFontFamilySerif,
        ReaderFontFamily.sans => l10n.readerFontFamilySans,
        ReaderFontFamily.mono => l10n.readerFontFamilyMono,
      };

  /// The ARB label of [padding].
  String _paddingLabel(AppLocalizations l10n, ReaderPagePadding padding) =>
      switch (padding) {
        ReaderPagePadding.narrow => l10n.readerPaddingNarrow,
        ReaderPagePadding.medium => l10n.readerPaddingMedium,
        ReaderPagePadding.wide => l10n.readerPaddingWide,
      };

  /// A numeric step label ("0", "0.5", "1", "2") — a number, so it needs no ARB entry.
  String _stepLabel(double step) =>
      step == step.roundToDouble() ? '${step.round()}' : '$step';

  /// The ARB label of [background].
  String _backgroundLabel(AppLocalizations l10n, ReaderBackground background) =>
      switch (background) {
        ReaderBackground.system => l10n.readerBackgroundSystem,
        ReaderBackground.paper => l10n.readerBackgroundPaper,
        ReaderBackground.sepia => l10n.readerBackgroundSepia,
        ReaderBackground.dark => l10n.readerBackgroundDark,
      };
}
