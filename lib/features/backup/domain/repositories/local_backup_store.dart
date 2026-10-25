import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';

/// The local side of the backup: one folder, one file per archive
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/2).
///
/// Implementations resolve a [BackupLocation] to an absolute directory, create it when missing, and
/// fall back to the app's private directory when a user folder is gone — a backup must always find a
/// place to land, and the fallback is reported rather than swallowed.
abstract interface class LocalBackupStore {
  /// The absolute directory [location] resolves to, creating it when needed.
  Future<String> directoryOf(BackupLocation location);

  /// Writes [bytes] as [name] into [location] and answers the file that was created.
  Future<StoredBackup> write({
    required BackupLocation location,
    required String name,
    required List<int> bytes,
  });

  /// Every `backup*.zip[.enc]` file in [location], newest first.
  Future<List<StoredBackup>> list(BackupLocation location);

  /// The bytes of [backup].
  Future<List<int>> read(StoredBackup backup);

  /// Removes [backup].
  Future<void> delete(StoredBackup backup);

  /// Keeps the newest [keep] archives in [location] and deletes the rest of ours.
  ///
  /// Answers how many files were deleted. Files that do not match [backupFilePattern] are never
  /// touched: the folder may be shared with the user's own documents.
  Future<int> prune({required BackupLocation location, required int keep});
}
