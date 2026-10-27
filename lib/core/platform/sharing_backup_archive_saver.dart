import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/file_sharer.dart';

// 私有字段不能做具名初始化形参（Dart 限制）。
// ignore_for_file: prefer_initializing_formals

/// [BackupArchiveSaver] that hands the archive to the system share sheet.
///
/// The mobile counterpart of `FileSelectorBackupArchiveSaver`: the save dialog is unavailable on
/// Android and iOS, while a share still lets the user store the zip outside the app (`ADR-0083`
/// §决策 1).
final class SharingBackupArchiveSaver implements BackupArchiveSaver {
  /// Creates the saver on top of [sharer].
  const SharingBackupArchiveSaver({required FileSharer sharer})
    : _sharer = sharer;

  final FileSharer _sharer;

  @override
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required List<int> bytes,
  }) {
    if (!_sharer.isSupported) {
      return Future<ParseResult<bool>>.value(const ParseSuccess<bool>(false));
    }

    return _sharer.share(<ShareableFile>[
      ShareableFile.inMemory(
        name: suggestedName,
        mimeType: 'application/zip',
        bytes: bytes,
      ),
    ]);
  }
}
