import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/log_file.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Lists the on-disk log files and lets the user clear them (`ADR-0082`).
///
/// The page is the "management" half of file logging: without it the only way to reclaim the space
/// would be a file manager. It shows **names, sizes and the folder**, never the content — the log is
/// meant to be pulled off the device by a developer (`adb pull` / Finder), not read on a phone.
final class LogFilesPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const LogFilesPage({super.key});

  @override
  ConsumerState<LogFilesPage> createState() => _LogFilesPageState();
}

class _LogFilesPageState extends ConsumerState<LogFilesPage> {
  late Future<List<LogFileInfo>> _files = _load();

  Future<List<LogFileInfo>> _load() async {
    final LogFile? file = ref.read(logFileProvider);
    if (file == null) {
      return const <LogFileInfo>[];
    }
    // 先等排队中的写入落盘，再看大小，否则刚写的一行会被算漏。
    await file.flush();

    return file.list();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final LogFile? file = ref.watch(logFileProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.logFilesTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: FutureBuilder<List<LogFileInfo>>(
        future: _files,
        builder:
            (BuildContext context, AsyncSnapshot<List<LogFileInfo>> snapshot) {
              final List<LogFileInfo> files =
                  snapshot.data ?? const <LogFileInfo>[];
              return ListView(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
                children: <Widget>[
                  if (file != null)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(file.directoryPath),
                      subtitle: Text(
                        l10n.logFilesTotal(
                          _formatBytes(
                            files.fold<int>(
                              0,
                              (int sum, LogFileInfo info) => sum + info.bytes,
                            ),
                          ),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: l10n.logFilesCopyPath,
                        icon: const Icon(Icons.copy_all_outlined),
                        onPressed: () => unawaited(
                          _copyPath(context, file.directoryPath, l10n),
                        ),
                      ),
                    ),
                  if (snapshot.connectionState == ConnectionState.done &&
                      files.isEmpty &&
                      file != null)
                    StateMessage(message: l10n.logFilesEmpty),
                  for (final LogFileInfo info in files.reversed)
                    ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(_nameOf(info.file)),
                      subtitle: Text(_formatBytes(info.bytes)),
                    ),
                  if (files.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(l10n.logFilesClear),
                      onTap: () => unawaited(_clear(context, l10n)),
                    ),
                ],
              );
            },
      ),
    );
  }

  Future<void> _clear(BuildContext context, AppLocalizations l10n) async {
    final LogFile? file = ref.read(logFileProvider);
    if (file == null) {
      return;
    }
    final int removed = await file.clear();
    if (!context.mounted) {
      return;
    }
    setState(() => _files = _load());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.logFilesCleared(removed))));
  }

  Future<void> _copyPath(
    BuildContext context,
    String path,
    AppLocalizations l10n,
  ) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.logFilesCopied)));
  }

  static String _nameOf(File file) =>
      file.path.split(Platform.pathSeparator).last;

  /// `123 B` / `12.3 KB` / `4.5 MB` — 日志页只需要量级。
  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// The human name of [level] (`debug` / `info` / …), translated for the settings page.
String logLevelLabel(LogLevel level, AppLocalizations l10n) => switch (level) {
  LogLevel.debug => l10n.settingsLogDebug,
  LogLevel.info => l10n.settingsLogInfo,
  LogLevel.warning => l10n.settingsLogWarning,
  LogLevel.error => l10n.settingsLogError,
  LogLevel.off => l10n.settingsLogOff,
};
