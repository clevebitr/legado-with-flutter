import 'dart:isolate';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/domain/backup_archive_codec.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_restore_report.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/restore_completion_hook.dart';

/// Merges one archive back into the database (`docs/dev/roadmap.md` M22, ADR-0073 §决策 3).
///
/// The archive is decoded and validated **before** anything is written: a corrupt file leaves the
/// database exactly as it was. Merging itself is one transaction inside the repository, so a failure
/// halfway through a table also leaves nothing behind.
final class RestoreBackup {
  /// Creates the use case.
  const RestoreBackup({
    required this._repository,
    required this._completionHook,
  });

  final BackupRepository _repository;
  final RestoreCompletionHook _completionHook;

  /// Decodes [bytes], merges it, and notifies the composition root.
  Future<ParseResult<BackupRestoreReport>> execute({
    required List<int> bytes,
  }) async {
    final List<int> archive = bytes;
    final ParseResult<BackupSnapshot> decoded = await Isolate.run(
      () => decodeBackupArchive(archive),
    );

    switch (decoded) {
      case ParseFailure<BackupSnapshot>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<BackupRestoreReport>(kind: kind, rulePath: rulePath);
      case ParseSuccess<BackupSnapshot>(:final BackupSnapshot data):
        final BackupRestoreReport report = await _repository.restore(
          data.contents,
        );
        // 恢复写完设置后必须让界面重读：`Settings` 与阅读设置是 keepAlive，不会自己失效。
        _completionHook.onRestored();

        return ParseSuccess<BackupRestoreReport>(report);
    }
  }
}
