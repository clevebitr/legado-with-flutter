import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_restore_report.dart';

/// Reads every backed-up table out of the database and writes one back
/// (`docs/dev/roadmap.md` M22, ADR-0073 §决策 3).
///
/// The merge rules — natural keys, “existing rows keep their local state”, “never delete” — belong
/// to the implementation; a caller only sees [BackupContents] and a per-table [BackupRestoreReport].
///
/// No `ParseResult` here: the only failures are database errors, which the notifier's boundary turns
/// into a failure state (C-ERR-2's presentation fallback, the same shape as the book-source import).
abstract interface class BackupRepository {
  /// Collects every table and the preferences into one snapshot.
  Future<BackupContents> collect();

  /// Merges [contents] into the database in one transaction, answering what changed.
  Future<BackupRestoreReport> restore(BackupContents contents);
}
