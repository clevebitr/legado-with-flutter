import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/presentation/notifiers/backup_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Export one zip, or merge one zip back (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// Two actions and one preview: the page never writes during [Backup.chooseToRestore] — a restore has
/// to be confirmed after the user sees what the archive holds (ADR-0073 §决策 3).
class BackupPage extends ConsumerWidget {
  /// Creates the page.
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final BackupState state = ref.watch(backupProvider);
    final bool isBusy = state is BackupWorking;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.backupTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.md),
        children: <Widget>[
          _ActionTile(
            icon: Icons.archive_outlined,
            title: l10n.backupExportTitle,
            body: l10n.backupExportBody,
            hint: l10n.backupIncludeSecretsHint,
            isEnabled: !isBusy,
            onTap: () => unawaited(ref.read(backupProvider.notifier).export()),
          ),
          _ActionTile(
            icon: Icons.unarchive_outlined,
            title: l10n.backupRestoreTitle,
            body: l10n.backupRestoreBody,
            hint: l10n.backupMergeHint,
            isEnabled: !isBusy,
            onTap: () =>
                unawaited(ref.read(backupProvider.notifier).chooseToRestore()),
          ),
          if (state is BackupWorking)
            _progress(context, state.action, l10n, tokens),
          if (state is BackupFailed)
            Padding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: FailureMessage(kind: state.kind),
            ),
          if (state is BackupExported)
            _outcome(
              context,
              l10n.backupExported(state.fileName, state.totalRows),
              tokens,
            ),
          if (state is BackupRestored)
            _outcome(
              context,
              l10n.backupRestored(
                state.report.changedRows,
                state.report.preferencesWritten,
              ),
              tokens,
            ),
          if (state is BackupPreviewReady)
            _preview(context, ref, state, l10n, tokens),
        ],
      ),
    );
  }

  /// The name of the running step, so a slow export does not look frozen.
  Widget _progress(
    BuildContext context,
    BackupAction action,
    AppLocalizations l10n,
    M3ETheme tokens,
  ) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: tokens.spacing.lg,
      vertical: tokens.spacing.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LinearProgressIndicator(
          color: tokens.colors.primary,
          backgroundColor: tokens.colors.surfaceContainerHighest,
        ),
        SizedBox(height: tokens.spacing.sm),
        Text(switch (action) {
          BackupAction.exporting => l10n.backupWorkingExporting,
          BackupAction.reading => l10n.backupWorkingReading,
          BackupAction.restoring => l10n.backupWorkingRestoring,
        }, style: tokens.typography.base.bodyMedium),
      ],
    ),
  );

  /// One line that reports what just happened, for the export and restore outcomes.
  Widget _outcome(BuildContext context, String message, M3ETheme tokens) =>
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.lg,
          vertical: tokens.spacing.md,
        ),
        child: Text(message, style: tokens.typography.base.bodyMedium),
      );

  /// What the picked archive holds, plus the two buttons that decide whether it is written.
  Widget _preview(
    BuildContext context,
    WidgetRef ref,
    BackupPreviewReady state,
    AppLocalizations l10n,
    M3ETheme tokens,
  ) {
    final BackupPreview preview = state.preview;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.md,
      ),
      color: tokens.colors.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.backupPreviewTitle,
              style: tokens.typography.base.titleSmall,
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(
              l10n.backupPreviewMeta(
                _formatInstant(preview.createdAt),
                preview.appVersion,
              ),
              style: tokens.typography.base.bodySmall,
            ),
            SizedBox(height: tokens.spacing.md),
            if (preview.totalRows == 0 && preview.preferenceCount == 0)
              Text(
                l10n.backupPreviewEmpty,
                style: tokens.typography.base.bodyMedium,
              )
            else
              for (final BackupTable table in BackupTable.values)
                if (preview.counts[table] case final int count when count > 0)
                  _previewRow(_tableLabel(l10n, table), count, tokens),
            if (preview.preferenceCount > 0)
              Padding(
                padding: EdgeInsets.only(top: tokens.spacing.xs),
                child: Text(
                  l10n.backupPreviewPreferences(preview.preferenceCount),
                  style: tokens.typography.base.bodySmall,
                ),
              ),
            SizedBox(height: tokens.spacing.md),
            Text(l10n.backupMergeHint, style: tokens.typography.base.bodySmall),
            SizedBox(height: tokens.spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () =>
                      ref.read(backupProvider.notifier).cancelPreview(),
                  child: Text(l10n.actionCancel),
                ),
                SizedBox(width: tokens.spacing.sm),
                FilledButton(
                  onPressed: () => unawaited(
                    ref.read(backupProvider.notifier).confirmRestore(),
                  ),
                  child: Text(l10n.backupConfirmRestore),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One line of the preview: a table label and how many rows it carries.
  Widget _previewRow(String label, int count, M3ETheme tokens) => Padding(
    padding: EdgeInsets.only(bottom: tokens.spacing.xs),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label, style: tokens.typography.base.bodyMedium)),
        Text('$count', style: tokens.typography.base.bodyMedium),
      ],
    ),
  );

  /// The localized name of one backed-up table.
  String _tableLabel(AppLocalizations l10n, BackupTable table) =>
      switch (table) {
        BackupTable.bookSources => l10n.backupTableBookSources,
        BackupTable.books => l10n.backupTableBooks,
        BackupTable.readingProgress => l10n.backupTableReadingProgress,
        BackupTable.bookGroups => l10n.backupTableBookGroups,
        BackupTable.bookmarks => l10n.backupTableBookmarks,
        BackupTable.readRecords => l10n.backupTableReadRecords,
        BackupTable.rules => l10n.backupTableRules,
      };

  /// `yyyy-MM-dd HH:mm` in local time; `intl` would be a dependency for one line.
  String _formatInstant(DateTime instant) {
    final DateTime local = instant.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');

    return '${local.year}-$month-$day $hour:$minute';
  }
}

/// One of the two actions: title, what it does, and the caveat it carries.
class _ActionTile extends StatelessWidget {
  /// Creates the tile.
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.hint,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String hint;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final M3ETheme tokens = context.m3e;

    return ListTile(
      enabled: isEnabled,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(body),
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.xs),
            child: Text(
              hint,
              style: tokens.typography.base.bodySmall?.copyWith(
                color: tokens.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: isEnabled ? onTap : null,
    );
  }
}
