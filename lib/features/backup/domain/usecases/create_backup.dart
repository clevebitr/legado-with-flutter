import 'dart:isolate';

import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/backup/domain/backup_archive_codec.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_repository.dart';

/// Builds one backup archive from the database (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// Reading the tables and compressing them are separate concerns: the repository owns the rows, this
/// use case owns the file (name, format, counts). Compression runs in its own isolate (C-PERF-4): a
/// shelf with thousands of rows is not a 16 ms computation.
final class CreateBackup {
  /// Creates the use case.
  ///
  /// [_appVersion] is injected so tests do not depend on the real build's version string.
  const CreateBackup({
    required this._repository,
    required this._clock,
    required this._appVersion,
  });

  final BackupRepository _repository;
  final Clock _clock;
  final String _appVersion;

  /// Collects everything and answers the archive to hand to the save dialog.
  Future<BackupArchive> execute() async {
    final BackupContents contents = await _repository.collect();
    final DateTime now = _clock.now();
    // 只捕获原语：`Isolate.run` 的闭包不能带上 `this`（里面有仓储与数据库句柄）。
    final String version = _appVersion;
    final List<int> bytes = await Isolate.run(
      () => encodeBackupArchive(contents, createdAt: now, appVersion: version),
    );

    return BackupArchive(
      suggestedName: backupFileNameFor(now),
      bytes: bytes,
      createdAt: now.toUtc(),
      counts: <BackupTable, int>{
        for (final BackupTable table in BackupTable.values)
          table: contents.countOf(table),
      },
    );
  }
}

/// The file name a backup written at [instant] is suggested as: `backup<yyyy-MM-dd>.zip`.
///
/// Local time, because the user reads it: an archive written at 23:30 local should not be named with
/// the next day in UTC (ADR-0073 §决策 2).
String backupFileNameFor(DateTime instant) {
  final DateTime local = instant.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');

  return 'backup${local.year}-$month-$day.zip';
}
