import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';

/// What one table's merge did (`docs/dev/roadmap.md` M22, ADR-0073 §决策 3).
final class BackupTableOutcome {
  /// Creates the outcome.
  const BackupTableOutcome({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
  });

  /// Rows the local database did not have.
  final int inserted;

  /// Rows that already existed and were refreshed.
  final int updated;

  /// Rows that were left alone: an existing row whose merge rule keeps the local one, or an entry
  /// that could not be used (missing identity, wrong type).
  final int skipped;

  /// How many entries the archive carried for this table.
  int get total => inserted + updated + skipped;
}

/// What one restore did, per table plus the preferences (`docs/dev/roadmap.md` M22, ADR-0073).
final class BackupRestoreReport {
  /// Creates the report.
  const BackupRestoreReport({
    required this.outcomes,
    required this.preferencesWritten,
  });

  /// One outcome per table the archive carried.
  final Map<BackupTable, BackupTableOutcome> outcomes;

  /// How many setting keys were written.
  final int preferencesWritten;

  /// How many rows this restore touched (inserted or updated).
  int get changedRows => outcomes.values.fold(
    0,
    (int sum, BackupTableOutcome outcome) =>
        sum + outcome.inserted + outcome.updated,
  );
}
