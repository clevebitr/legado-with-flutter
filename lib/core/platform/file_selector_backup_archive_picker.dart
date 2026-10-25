import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_dialog.dart';

/// [BackupArchivePicker] backed by `file_selector`.
///
/// The dialog call is injected through `opener`, so the cap handling stays ordinary testable Dart.
final class FileSelectorBackupArchivePicker implements BackupArchivePicker {
  /// Creates the picker; [opener] defaults to the real dialog.
  const FileSelectorBackupArchivePicker({BackupArchiveOpener? opener})
    : _opener = opener ?? fileSelectorOpenBackupArchive;

  final BackupArchiveOpener _opener;

  @override
  Future<ParseResult<PickedBackupArchive?>> pick({
    required int maxBytes,
  }) async {
    final BackupArchiveSelection? selection = await _opener(maxBytes: maxBytes);

    return switch (selection) {
      null => const ParseSuccess<PickedBackupArchive?>(null),
      // 超限不是「取消」：用户需要知道文件为什么没被读。
      OversizedBackupArchive() => failureAt<PickedBackupArchive?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'backup.read.sizeLimit',
      ),
      PickedBackupArchive() => ParseSuccess<PickedBackupArchive?>(selection),
    };
  }
}
