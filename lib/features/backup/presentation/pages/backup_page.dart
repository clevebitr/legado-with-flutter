import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/domain/entities/restore_mode.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/presentation/notifiers/backup_notifier.dart';
import 'package:flutter_reader/features/backup/presentation/notifiers/backup_settings_controller.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Export one archive, or bring one back (`docs/dev/roadmap.md` M22, ADR-0073 / ADR-0074).
///
/// The page is organised by decision, not by button: 自动备份与保留份数、备份位置与口令、本机备份、
/// 云端备份、最后是「这份备份里有什么」的预览与恢复方式。Nothing here writes without an explicit
/// confirmation, and an overwrite restore says what it will clear before it starts.
class BackupPage extends ConsumerWidget {
  /// Creates the page.
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final BackupState state = ref.watch(backupProvider);
    final BackupSettings settings =
        ref.watch(backupSettingsControllerProvider).value ??
        BackupSettings.defaults;
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
          _section(context, l10n.backupAutoTitle, tokens),
          SwitchListTile(
            value: settings.isAutoEnabled,
            title: Text(l10n.backupAutoTitle),
            subtitle: Text(l10n.backupAutoBody),
            onChanged: (bool value) => unawaited(
              ref
                  .read(backupSettingsControllerProvider.notifier)
                  .setAutoEnabled(value),
            ),
          ),
          ListTile(
            title: Text(l10n.backupRetentionTitle),
            subtitle: Text(l10n.backupRetentionBody),
            trailing: DropdownButton<int>(
              // 恢复的偏好可能带来一个不在下拉项里的值（比如旧版本写下的 7）：
              // `DropdownButton` 碰到这种值会断言失败，直接回落到默认份数。
              value: _retentionChoices.contains(settings.retention)
                  ? settings.retention
                  : defaultBackupRetention,
              onChanged: (int? value) => value == null
                  ? null
                  : unawaited(
                      ref
                          .read(backupSettingsControllerProvider.notifier)
                          .setRetention(value),
                    ),
              items: <DropdownMenuItem<int>>[
                for (final int value in _retentionChoices)
                  DropdownMenuItem<int>(
                    value: value,
                    child: Text(l10n.backupRetentionValue(value)),
                  ),
              ],
            ),
          ),
          _section(context, l10n.backupLocationTitle, tokens),
          ListTile(
            title: Text(
              switch (settings.location) {
                AppPrivateBackupLocation() => l10n.backupLocationPrivate,
                FolderBackupLocation(:final String path) => path,
              },
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(l10n.backupIncludeSecretsHint),
          ),
          // 位置路径可能很长：两个动作放到下一行右对齐，不把标题挤成一字一行。
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.xs,
              children: <Widget>[
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => unawaited(
                          ref
                              .read(backupSettingsControllerProvider.notifier)
                              .resetLocation(),
                        ),
                  child: Text(l10n.backupLocationReset),
                ),
                FilledButton.tonal(
                  onPressed: isBusy
                      ? null
                      : () => unawaited(
                          ref
                              .read(backupSettingsControllerProvider.notifier)
                              .chooseLocation(),
                        ),
                  child: Text(l10n.backupLocationChoose),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(l10n.backupPasswordTitle),
            subtitle: Text(
              settings.hasPassword
                  ? l10n.backupPasswordStored
                  : l10n.backupPasswordMissing,
            ),
            trailing: TextButton(
              onPressed: isBusy
                  ? null
                  : () =>
                        unawaited(_editPassword(context, ref, l10n, settings)),
              child: Text(
                settings.hasPassword
                    ? l10n.backupPasswordChange
                    : l10n.backupPasswordSet,
              ),
            ),
          ),
          _section(context, l10n.backupLocalTitle, tokens),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(l10n.backupSaveToLocation),
            subtitle: Text(l10n.backupIncludeSecretsHint),
            enabled: !isBusy,
            onTap: () =>
                unawaited(ref.read(backupProvider.notifier).saveToLocation()),
          ),
          ListTile(
            leading: const Icon(Icons.save_as_outlined),
            title: Text(l10n.backupSaveAs),
            enabled: !isBusy,
            onTap: () => unawaited(ref.read(backupProvider.notifier).saveAs()),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(l10n.backupRestoreFromFile),
            subtitle: Text(l10n.backupMergeHint),
            enabled: !isBusy,
            onTap: () => unawaited(
              ref.read(backupProvider.notifier).chooseFileToRestore(),
            ),
          ),
          _section(context, l10n.backupWebDavTitle, tokens),
          _webDavSection(context, ref, l10n, tokens, settings, isBusy),
          if (state is BackupWorking)
            _progress(context, state.action, l10n, tokens),
          if (state is BackupFailed)
            Padding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: FailureMessage(kind: state.kind),
            ),
          if (state is BackupExported)
            _outcome(context, l10n.backupSavedTo(state.path), tokens),
          if (state is BackupRestored)
            _restored(context, ref, state, l10n, tokens),
          if (state is BackupPasswordNeeded)
            _passwordPromptCard(context, ref, state, l10n, tokens),
          if (state is BackupPreviewReady)
            _preview(context, ref, state, l10n, tokens),
          if (state is BackupRemoteListed)
            _remoteList(context, ref, state, l10n, tokens, isBusy),
        ],
      ),
    );
  }

  /// A section label; a plain text node so the rows below stay independently reachable.
  Widget _section(BuildContext context, String label, M3ETheme tokens) =>
      Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.xs,
        ),
        child: Text(label, style: tokens.typography.base.titleSmall),
      );

  /// The WebDAV configuration fields plus the two cloud actions.
  Widget _webDavSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    M3ETheme tokens,
    BackupSettings settings,
    bool isBusy,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (!settings.isWebDavConfigured)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
          child: Text(l10n.backupWebDavNotConfigured),
        ),
      ListTile(
        title: Text(
          settings.isWebDavConfigured
              ? settings.webDavUrl
              : l10n.backupWebDavUrl,
        ),
        subtitle: Text(
          settings.hasWebDavPassword
              ? l10n.backupPasswordStored
              : l10n.backupPasswordMissing,
        ),
        trailing: TextButton(
          onPressed: isBusy
              ? null
              : () => unawaited(_editWebDav(context, ref, l10n, settings)),
          child: Text(l10n.backupWebDavSave),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.cloud_upload_outlined),
        title: Text(l10n.backupCloudUpload),
        enabled: !isBusy,
        onTap: () =>
            unawaited(ref.read(backupProvider.notifier).uploadToCloud()),
      ),
      ListTile(
        leading: const Icon(Icons.refresh),
        title: Text(l10n.backupCloudRefresh),
        enabled: !isBusy,
        onTap: () => unawaited(ref.read(backupProvider.notifier).listRemote()),
      ),
    ],
  );

  /// The name of the running step, so a slow action does not look frozen.
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
          BackupAction.savingAs => l10n.backupWorkSavingAs,
          BackupAction.reading => l10n.backupWorkingReading,
          BackupAction.restoring => l10n.backupWorkingRestoring,
          BackupAction.uploading => l10n.backupWorkUploading,
          BackupAction.listingRemote => l10n.backupWorkListingRemote,
          BackupAction.downloading => l10n.backupWorkDownloading,
        }, style: tokens.typography.base.bodyMedium),
      ],
    ),
  );

  /// One line that reports what just happened.
  Widget _outcome(BuildContext context, String message, M3ETheme tokens) =>
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.lg,
          vertical: tokens.spacing.md,
        ),
        child: Text(message, style: tokens.typography.base.bodyMedium),
      );

  /// What the restore wrote, and the safety copy it made first.
  Widget _restored(
    BuildContext context,
    WidgetRef ref,
    BackupRestored state,
    AppLocalizations l10n,
    M3ETheme tokens,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _outcome(
        context,
        l10n.backupRestored(
          state.outcome.report.changedRows,
          state.outcome.report.preferencesWritten,
        ),
        tokens,
      ),
      if (state.outcome.safetyCopy case final StoredBackup copy)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
          child: Text(l10n.backupSafetyCopy(copy.name)),
        ),
    ],
  );

  /// The password field for an encrypted archive.
  Widget _passwordPromptCard(
    BuildContext context,
    WidgetRef ref,
    BackupPasswordNeeded state,
    AppLocalizations l10n,
    M3ETheme tokens,
  ) => Card(
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
            state.isRetry
                ? l10n.backupPasswordWrong
                : l10n.backupPasswordRequired,
            style: tokens.typography.base.bodyMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.backupPasswordPrompt),
            onSubmitted: (String value) => unawaited(
              ref.read(backupProvider.notifier).retryWithPassword(value),
            ),
          ),
        ],
      ),
    ),
  );

  /// What the picked archive holds, plus the mode switch and the two decisions.
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
            _restoreModes(context, ref, l10n, tokens),
          ],
        ),
      ),
    );
  }

  /// 「合并 / 覆盖」 plus the two buttons; overwrite explains itself before it runs.
  Widget _restoreModes(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    M3ETheme tokens,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(l10n.backupMergeHint, style: tokens.typography.base.bodySmall),
      SizedBox(height: tokens.spacing.sm),
      Text(
        l10n.backupOverwriteWarning,
        style: tokens.typography.base.bodySmall,
      ),
      SizedBox(height: tokens.spacing.md),
      Wrap(
        spacing: tokens.spacing.sm,
        alignment: WrapAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed: () => ref.read(backupProvider.notifier).cancelPreview(),
            child: Text(l10n.actionCancel),
          ),
          OutlinedButton(
            onPressed: () => unawaited(
              ref
                  .read(backupProvider.notifier)
                  .confirmRestore(RestoreMode.merge),
            ),
            child: Text(l10n.backupMergeMode),
          ),
          FilledButton(
            onPressed: () => unawaited(_confirmOverwrite(context, ref, l10n)),
            child: Text(l10n.backupOverwriteMode),
          ),
        ],
      ),
    ],
  );

  /// The cloud list: one row per archive with a restore and a delete action.
  Widget _remoteList(
    BuildContext context,
    WidgetRef ref,
    BackupRemoteListed state,
    AppLocalizations l10n,
    M3ETheme tokens,
    bool isBusy,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _section(context, l10n.backupRemoteTitle, tokens),
      if (state.backups.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
          child: Text(l10n.backupRemoteEmpty),
        )
      else
        for (final RemoteBackup backup in state.backups)
          ListTile(
            title: Text(backup.name),
            subtitle: Text(
              '${(backup.sizeBytes / 1024).round()} KiB · '
              '${_formatInstant(backup.modifiedAt)}',
            ),
            trailing: Wrap(
              spacing: tokens.spacing.xs,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.cloud_download_outlined),
                  tooltip: l10n.backupRemoteRestore,
                  onPressed: isBusy
                      ? null
                      : () => unawaited(
                          ref
                              .read(backupProvider.notifier)
                              .previewRemote(backup),
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.backupRemoteDelete,
                  onPressed: isBusy
                      ? null
                      : () => unawaited(
                          ref
                              .read(backupProvider.notifier)
                              .deleteRemote(backup),
                        ),
                ),
              ],
            ),
          ),
    ],
  );

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
    String two(int value) => value.toString().padLeft(2, '0');

    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// Asks for the backup password (or its removal).
  Future<void> _editPassword(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BackupSettings settings,
  ) async {
    final TextEditingController controller = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.backupPasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l10n.backupPasswordBody),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.backupPasswordPrompt),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          if (settings.hasPassword)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: Text(l10n.backupPasswordClear),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.backupWebDavSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) {
      return;
    }

    final bool stored = await ref
        .read(backupSettingsControllerProvider.notifier)
        .setPassword(value);
    if (!context.mounted || stored || value.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.backupPasswordStoreFailed)));
  }

  /// Asks for the WebDAV configuration; the password is optional (kept when blank).
  Future<void> _editWebDav(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BackupSettings settings,
  ) async {
    final TextEditingController url = TextEditingController(
      text: settings.webDavUrl,
    );
    final TextEditingController user = TextEditingController(
      text: settings.webDavUsername,
    );
    final TextEditingController password = TextEditingController();
    final _WebDavInput? input = await showDialog<_WebDavInput>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.backupWebDavTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: url,
              decoration: InputDecoration(labelText: l10n.backupWebDavUrl),
            ),
            TextField(
              controller: user,
              decoration: InputDecoration(labelText: l10n.backupWebDavUsername),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.backupWebDavPassword),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _WebDavInput(
                url: url.text,
                username: user.text,
                password: password.text,
              ),
            ),
            child: Text(l10n.backupWebDavSave),
          ),
        ],
      ),
    );
    url.dispose();
    user.dispose();
    password.dispose();
    if (input == null || !context.mounted) {
      return;
    }

    await ref
        .read(backupSettingsControllerProvider.notifier)
        .setWebDav(
          url: input.url,
          username: input.username,
          password: input.password,
        );
  }

  /// Confirms an overwrite: the only destructive action on this page.
  Future<void> _confirmOverwrite(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.backupOverwriteMode),
        content: Text(l10n.backupOverwriteWarning),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.backupOverwriteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(backupProvider.notifier)
        .confirmRestore(RestoreMode.overwrite);
  }
}

/// The retention values the dropdown offers.
const List<int> _retentionChoices = <int>[1, 3, 5, 10, 20, 30];

/// The three WebDAV fields the dialog collects.
final class _WebDavInput {
  const _WebDavInput({
    required this.url,
    required this.username,
    required this.password,
  });

  final String url;
  final String username;
  final String password;
}
