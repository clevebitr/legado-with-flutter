import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_restore_report.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_repository.dart';

/// In-memory [BackupRepository] for the backup use-case tests.
final class FakeBackupRepository implements BackupRepository {
  /// Creates the fake; [contents] is what [collect] answers and [report] what [restore] answers.
  FakeBackupRepository({required this.contents, BackupRestoreReport? report})
    : report = report ?? emptyReport;

  /// What [collect] answers.
  final BackupContents contents;

  /// What [restore] answers.
  final BackupRestoreReport report;

  /// The contents [restore] was called with, or `null` when it was not called.
  BackupContents? restoredContents;

  /// How often [collect] ran.
  int collectCount = 0;

  /// An empty [BackupContents], for tests that do not care about the rows.
  static const BackupContents emptyContents = BackupContents(
    tables: <BackupTable, List<Map<String, Object?>>>{},
    preferences: <String, Object?>{},
  );

  /// A report where nothing changed.
  static const BackupRestoreReport emptyReport = BackupRestoreReport(
    outcomes: <BackupTable, BackupTableOutcome>{},
    preferencesWritten: 0,
  );

  @override
  Future<BackupContents> collect() async {
    collectCount += 1;

    return contents;
  }

  @override
  Future<BackupRestoreReport> restore(BackupContents contents) async {
    restoredContents = contents;

    return report;
  }
}
