import 'dart:io';

import 'package:flutter_reader/features/backup/data/file_system_local_backup_store.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory privateDirectory;
  late FileSystemLocalBackupStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup_store_test');
    privateDirectory = Directory('${root.path}/private');
    await privateDirectory.create();
    store = FileSystemLocalBackupStore(
      privateDirectory: () async => privateDirectory,
    );
  });

  tearDown(() => root.delete(recursive: true));

  const BackupLocation private = AppPrivateBackupLocation();

  test('directoryOf_givenThePrivateLocation_createsAndAnswersIt', () async {
    final String directory = await store.directoryOf(private);

    expect(directory, privateDirectory.path);
    expect(Directory(directory).existsSync(), isTrue);
  });

  test('write_givenBytes_createsTheFileAndReportsIt', () async {
    final StoredBackup backup = await store.write(
      location: private,
      name: 'backup2026-10-25.zip',
      bytes: <int>[1, 2, 3],
    );

    expect(File(backup.path).existsSync(), isTrue);
    expect(backup.sizeBytes, 3);
    expect(backup.isEncrypted, isFalse);
    expect(await store.read(backup), <int>[1, 2, 3]);
  });

  test('write_givenAUserFolder_writesThere', () async {
    final Directory folder = Directory('${root.path}/usb');
    await folder.create();

    final StoredBackup backup = await store.write(
      location: FolderBackupLocation(folder.path),
      name: 'backup2026-10-25.zip',
      bytes: <int>[1],
    );

    expect(backup.directory, folder.path);
  });

  test('write_givenAMissingUserFolder_fallsBackToThePrivateOne', () async {
    // 文件夹被删/被移走时备份必须仍有落点（ADR-0074 §决策 1）。
    final StoredBackup backup = await store.write(
      location: const FolderBackupLocation('/definitely/not/here'),
      name: 'backup2026-10-25.zip',
      bytes: <int>[1],
    );

    expect(backup.directory, privateDirectory.path);
  });

  test('list_givenFilesInTheFolder_answersOnlyOursNewestFirst', () async {
    await store.write(
      location: private,
      name: 'backup2026-10-24.zip',
      bytes: <int>[1],
    );
    await store.write(
      location: private,
      name: 'backup2026-10-25.zip.enc',
      bytes: <int>[2],
    );
    // 用户自己的文件：既不算备份，也不能被清理（ADR-0074 §决策 2）。
    await File('${privateDirectory.path}/report.zip').writeAsBytes(<int>[3]);

    final List<StoredBackup> backups = await store.list(private);

    expect(
      backups.map((StoredBackup backup) => backup.name),
      containsAll(<String>['backup2026-10-25.zip.enc', 'backup2026-10-24.zip']),
    );
    expect(
      backups.where((StoredBackup backup) => backup.name == 'report.zip'),
      isEmpty,
    );
  });

  test('list_givenNoFolder_answersAnEmptyList', () async {
    expect(await store.list(const FolderBackupLocation('/nope')), isEmpty);
  });

  test('prune_givenMoreFilesThanTheRetention_deletesTheOldestOurs', () async {
    for (final String name in <String>[
      'backup2026-10-22.zip',
      'backup2026-10-23.zip',
      'backup2026-10-24.zip',
      'backup2026-10-25.zip',
    ]) {
      await store.write(location: private, name: name, bytes: <int>[1]);
    }
    await File('${privateDirectory.path}/report.zip').writeAsBytes(<int>[3]);

    final int removed = await store.prune(location: private, keep: 2);

    final List<String> left = <String>[
      for (final FileSystemEntity entity in privateDirectory.listSync())
        entity.uri.pathSegments.last,
    ]..sort();
    expect(removed, 2);
    expect(left, contains('report.zip'));
    expect(
      left.where((String name) => name.startsWith('backup')),
      hasLength(2),
    );
  });

  test('prune_givenFewerFilesThanTheRetention_deletesNothing', () async {
    await store.write(
      location: private,
      name: 'backup2026-10-25.zip',
      bytes: <int>[1],
    );

    expect(await store.prune(location: private, keep: 5), 0);
  });

  test('prune_givenANegativeKeep_deletesAllOurs', () async {
    await store.write(
      location: private,
      name: 'backup2026-10-25.zip',
      bytes: <int>[1],
    );

    expect(await store.prune(location: private, keep: -1), 1);
  });

  test('delete_givenAFile_removesIt', () async {
    final StoredBackup backup = await store.write(
      location: private,
      name: 'backup2026-10-25.zip',
      bytes: <int>[1],
    );

    await store.delete(backup);

    expect(File(backup.path).existsSync(), isFalse);
  });
}
