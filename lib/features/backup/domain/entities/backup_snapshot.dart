import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_manifest.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';

/// One decoded archive: what it says about itself and what it holds
/// (`docs/dev/roadmap.md` M22, ADR-0073).
final class BackupSnapshot {
  /// Creates the snapshot.
  const BackupSnapshot({required this.manifest, required this.contents});

  /// The archive's `manifest.json`.
  final BackupManifest manifest;

  /// The rows and preferences it carries.
  final BackupContents contents;
}

/// One finished export, ready for the save dialog (`docs/dev/roadmap.md` M22, ADR-0073).
final class BackupArchive {
  /// Creates the archive.
  const BackupArchive({
    required this.suggestedName,
    required this.bytes,
    required this.createdAt,
    required this.counts,
  });

  /// The file name to suggest, `backup<yyyy-MM-dd>.zip` in local time.
  final String suggestedName;

  /// The archive itself.
  final List<int> bytes;

  /// When it was written, in UTC.
  final DateTime createdAt;

  /// How many rows each table contributed, for the page's summary.
  final Map<BackupTable, int> counts;
}

/// What the restore preview shows before anything is written (`docs/dev/roadmap.md` M22).
final class BackupPreview {
  /// Creates the preview.
  const BackupPreview({
    required this.createdAt,
    required this.appVersion,
    required this.counts,
    required this.preferenceCount,
  });

  /// When the archive was written, in UTC.
  final DateTime createdAt;

  /// The app version that wrote it.
  final String appVersion;

  /// How many rows each table carries.
  final Map<BackupTable, int> counts;

  /// How many setting keys the archive carries.
  final int preferenceCount;

  /// How many rows the whole archive carries.
  int get totalRows =>
      counts.values.fold(0, (int sum, int count) => sum + count);
}
