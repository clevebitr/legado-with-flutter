import 'dart:isolate';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/domain/backup_archive_codec.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';

/// Reads an archive's manifest and counts without touching the database
/// (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// The restore page shows this before asking for confirmation: 「这份备份里有 N 个书源、M 本书」
/// is the only way a user can tell one archive from another.
final class InspectBackup {
  /// Creates the use case.
  const InspectBackup();

  /// Decodes [bytes] and answers what the archive holds.
  Future<ParseResult<BackupPreview>> execute({required List<int> bytes}) async {
    final List<int> archive = bytes;
    final ParseResult<BackupSnapshot> decoded = await Isolate.run(
      () => decodeBackupArchive(archive),
    );

    return switch (decoded) {
      ParseSuccess<BackupSnapshot>(:final BackupSnapshot data) =>
        ParseSuccess<BackupPreview>(
          BackupPreview(
            createdAt: data.manifest.createdAt,
            appVersion: data.manifest.appVersion,
            counts: <BackupTable, int>{
              for (final BackupTable table in BackupTable.values)
                table: data.contents.countOf(table),
            },
            preferenceCount: data.contents.preferences.length,
          ),
        ),
      ParseFailure<BackupSnapshot>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<BackupPreview>(kind: kind, rulePath: rulePath),
    };
  }
}
