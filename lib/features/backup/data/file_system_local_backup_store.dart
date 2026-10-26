import 'dart:io';

import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/repositories/local_backup_store.dart';
import 'package:path_provider/path_provider.dart';

/// Resolves the app's own backup directory (the default location).
typedef PrivateBackupDirectory = Future<Directory> Function();

/// [LocalBackupStore] on the file system (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/2).
///
/// Two behaviours are worth knowing:
///
/// * a user folder that no longer exists **falls back** to the private directory, and the archive's
///   reported [StoredBackup.directory] tells the page where it really landed;
/// * [prune] only ever deletes files matching [backupFilePattern], so a user's own `report.zip` in
///   the same folder survives.
final class FileSystemLocalBackupStore implements LocalBackupStore {
  /// Creates the store; [privateDirectory] defaults to `<app support>/backups`.
  const FileSystemLocalBackupStore({PrivateBackupDirectory? privateDirectory})
    : _privateDirectory = privateDirectory ?? _defaultPrivateDirectory;

  final PrivateBackupDirectory _privateDirectory;

  @override
  Future<String> directoryOf(BackupLocation location) async {
    final Directory directory = await _resolve(location);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    return directory.path;
  }

  @override
  Future<StoredBackup> write({
    required BackupLocation location,
    required String name,
    required List<int> bytes,
  }) async {
    final Directory directory = await _resolve(location);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final File file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);

    return StoredBackup(
      name: name,
      directory: directory.path,
      sizeBytes: bytes.length,
      modifiedAt: file.lastModifiedSync().toLocal(),
    );
  }

  @override
  Future<List<StoredBackup>> list(BackupLocation location) async {
    final Directory directory = await _resolve(location);
    if (!directory.existsSync()) {
      return const <StoredBackup>[];
    }

    final List<StoredBackup> backups = <StoredBackup>[];
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final String name = entity.uri.pathSegments.last;
      if (!backupFilePattern.hasMatch(name)) {
        continue;
      }
      backups.add(
        StoredBackup(
          name: name,
          directory: directory.path,
          sizeBytes: entity.lengthSync(),
          modifiedAt: entity.lastModifiedSync().toLocal(),
        ),
      );
    }
    backups.sort(_newestFirst);

    return backups;
  }

  @override
  Future<List<int>> read(StoredBackup backup) =>
      File(backup.path).readAsBytes();

  @override
  Future<void> delete(StoredBackup backup) async {
    final File file = File(backup.path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  @override
  Future<int> prune({
    required BackupLocation location,
    required int keep,
  }) async {
    final List<StoredBackup> backups = await list(location);
    final int retained = keep < 0 ? 0 : keep;
    if (backups.length <= retained) {
      return 0;
    }

    var removed = 0;
    for (final StoredBackup backup in backups.skip(retained)) {
      await delete(backup);
      removed += 1;
    }

    return removed;
  }

  Future<Directory> _resolve(BackupLocation location) async {
    switch (location) {
      case AppPrivateBackupLocation():
        return _privateDirectory();
      case FolderBackupLocation(:final String path):
        final Directory folder = Directory(path);
        // 文件夹可能被删、被移动或权限变了：备份必须总有落点（ADR-0074 §决策 1）。
        return folder.existsSync() ? folder : _privateDirectory();
    }
  }

  /// Newest first; the name breaks ties so the order is stable within one day.
  static int _newestFirst(StoredBackup a, StoredBackup b) {
    final int byTime = b.modifiedAt.compareTo(a.modifiedAt);

    return byTime != 0 ? byTime : b.name.compareTo(a.name);
  }
}

/// `<application support>/backups`.
Future<Directory> _defaultPrivateDirectory() async {
  final Directory support = await getApplicationSupportDirectory();

  return Directory('${support.path}${Platform.pathSeparator}backups');
}
