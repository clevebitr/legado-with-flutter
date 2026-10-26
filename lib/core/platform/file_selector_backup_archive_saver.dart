import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/file_selector_dialog.dart';

/// [BackupArchiveSaver] backed by the `file_selector` plugin.
///
/// A cancelled dialog answers `false`; a write failure travels as a [ParseFailure] with
/// `rulePath: 'backup.write'`.
final class FileSelectorBackupArchiveSaver implements BackupArchiveSaver {
  /// Creates the saver; [write] defaults to the real save dialog.
  const FileSelectorBackupArchiveSaver({BackupArchiveWriter? write})
    : _write = write ?? fileSelectorSaveBackupArchive;

  final BackupArchiveWriter _write;

  @override
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    try {
      final String? path = await _write(
        suggestedName: suggestedName,
        bytes: bytes,
      );

      return ParseSuccess<bool>(path != null);
    } on Exception {
      return failureAt<bool>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'backup.write',
      );
    }
  }
}
