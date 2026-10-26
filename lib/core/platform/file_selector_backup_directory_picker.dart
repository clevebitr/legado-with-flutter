import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_directory_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_dialog.dart';

/// [BackupDirectoryPicker] backed by `file_selector`.
///
/// A cancelled dialog answers `null`; a dialog failure travels as a [ParseFailure] with
/// `rulePath: 'backup.directory.pick'`.
final class FileSelectorBackupDirectoryPicker implements BackupDirectoryPicker {
  /// Creates the picker; [open] defaults to the real dialog.
  const FileSelectorBackupDirectoryPicker({DirectoryOpener? open})
    : _open = open ?? fileSelectorPickDirectory;

  final DirectoryOpener _open;

  @override
  Future<ParseResult<String?>> pick() async {
    try {
      return ParseSuccess<String?>(await _open());
    } on Exception {
      return failureAt<String?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'backup.directory.pick',
      );
    }
  }
}
