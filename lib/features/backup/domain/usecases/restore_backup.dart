import 'dart:isolate';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/domain/backup_archive_codec.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_restore_report.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/restore_mode.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_settings_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/restore_completion_hook.dart';
import 'package:flutter_reader/features/backup/domain/usecases/save_backup.dart';

/// Merges or overwrites the database from one archive
/// (`docs/dev/roadmap.md` M22, ADR-0073 §决策 3 / ADR-0074 §决策 3).
///
/// The archive is decoded and validated **before** anything is written, and an overwrite restore
/// writes a safety copy first — if that copy fails the restore does not start. The merge itself is one
/// transaction inside the repository, so a failure halfway through leaves nothing behind.
final class RestoreBackup {
  /// Creates the use case.
  const RestoreBackup({
    required this._repository,
    required this._completionHook,
    required this._settings,
    required this._saveBackup,
  });

  final BackupRepository _repository;
  final RestoreCompletionHook _completionHook;
  final BackupSettingsRepository _settings;
  final SaveBackup _saveBackup;

  /// Decodes [bytes], optionally clears the tables, merges, and notifies the composition root.
  ///
  /// [password] is the one the user typed for an encrypted archive; when it is `null` the stored
  /// password is used, and an encrypted archive with neither answers `backup.read.passwordRequired`.
  /// The safety copy written for an overwrite goes to the configured backup location.
  Future<ParseResult<RestoreOutcome>> execute({
    required List<int> bytes,
    RestoreMode mode = RestoreMode.merge,
    String? password,
  }) async {
    final String? effectivePassword = await passwordForArchive(
      settings: _settings,
      typed: password,
    );
    final List<int> archive = bytes;
    final ParseResult<BackupSnapshot> decoded = await Isolate.run(
      () => decodeBackupArchive(archive, password: effectivePassword),
    );

    final BackupSnapshot snapshot;
    switch (decoded) {
      case ParseFailure<BackupSnapshot>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<RestoreOutcome>(kind: kind, rulePath: rulePath);
      case ParseSuccess<BackupSnapshot>(:final BackupSnapshot data):
        snapshot = data;
    }

    StoredBackup? safetyCopy;
    if (mode == RestoreMode.overwrite) {
      // 覆盖不可逆：先把现在的库存一份；写不出来就不覆盖（ADR-0074 §决策 3）。
      final ParseResult<StoredBackup> saved = await _saveBackup.execute(
        isSafetyCopy: true,
      );
      switch (saved) {
        case ParseSuccess<StoredBackup>(:final StoredBackup data):
          safetyCopy = data;
        case ParseFailure<StoredBackup>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ):
          return failureAt<RestoreOutcome>(kind: kind, rulePath: rulePath);
      }
    }

    final BackupRestoreReport report = await _repository.restore(
      snapshot.contents,
      mode: mode,
    );
    // 恢复写完设置后必须让界面重读：`Settings` 与阅读设置是 keepAlive，不会自己失效。
    _completionHook.onRestored();

    return ParseSuccess<RestoreOutcome>(
      RestoreOutcome(report: report, safetyCopy: safetyCopy),
    );
  }
}

/// What one restore did: the per-table report plus the safety copy, when one was written.
final class RestoreOutcome {
  /// Creates the outcome.
  const RestoreOutcome({required this.report, this.safetyCopy});

  /// The merge report (inserted / updated / skipped per table).
  final BackupRestoreReport report;

  /// The file written before an overwrite restore, `null` for a merge.
  final StoredBackup? safetyCopy;
}
