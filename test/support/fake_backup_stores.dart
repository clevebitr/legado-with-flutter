import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_settings_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/local_backup_store.dart';
import 'package:flutter_reader/features/backup/domain/repositories/remote_backup_store.dart';

/// In-memory [BackupSettingsRepository] that also keeps the two passwords.
final class FakeBackupSettingsRepository implements BackupSettingsRepository {
  /// Creates the fake with optional initial values.
  FakeBackupSettingsRepository({
    this._settings = BackupSettings.defaults,
    this.password,
    this.webDavPassword,
    this.isKeyStoreAvailable = true,
  });

  BackupSettings _settings;

  /// The backup password the fake answers.
  String? password;

  /// The WebDAV password the fake answers.
  String? webDavPassword;

  /// Whether writes to the "key store" succeed.
  final bool isKeyStoreAvailable;

  /// The settings as last saved.
  BackupSettings get settings => _settings;

  @override
  Future<BackupSettings> load() async => _settings;

  @override
  Future<void> save(BackupSettings settings) async => _settings = settings;

  @override
  Future<BackupLocation> loadLocation() async => _settings.location;

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<String?> readWebDavPassword() async => webDavPassword;

  @override
  Future<bool> writePassword(String? value) async {
    if (!isKeyStoreAvailable) {
      return false;
    }
    password = value;

    return true;
  }

  @override
  Future<bool> writeWebDavPassword(String? value) async {
    if (!isKeyStoreAvailable) {
      return false;
    }
    webDavPassword = value;

    return true;
  }
}

/// In-memory [LocalBackupStore].
final class FakeLocalBackupStore implements LocalBackupStore {
  /// Files written so far, newest last.
  final Map<String, StoredBackup> files = <String, StoredBackup>{};

  /// The directory every location resolves to.
  String directory = '/tmp/backups';

  /// How often [prune] ran.
  int pruneCount = 0;

  /// The `keep` value of the last prune.
  int? lastKeep;

  /// When true, [write] throws — a read-only folder or a full disk.
  bool failWrites = false;

  @override
  Future<String> directoryOf(BackupLocation location) async => directory;

  @override
  Future<StoredBackup> write({
    required BackupLocation location,
    required String name,
    required List<int> bytes,
  }) async {
    if (failWrites) {
      throw const _StoreFailure();
    }
    final StoredBackup backup = StoredBackup(
      name: name,
      directory: directory,
      sizeBytes: bytes.length,
      modifiedAt: DateTime.utc(2026, 10, 25),
    );
    files[name] = backup;

    return backup;
  }

  @override
  Future<List<StoredBackup>> list(BackupLocation location) async =>
      files.values.toList();

  @override
  Future<List<int>> read(StoredBackup backup) async => <int>[];

  @override
  Future<void> delete(StoredBackup backup) async => files.remove(backup.name);

  @override
  Future<int> prune({
    required BackupLocation location,
    required int keep,
  }) async {
    pruneCount += 1;
    lastKeep = keep;

    return 0;
  }
}

/// In-memory [RemoteBackupStore].
final class FakeRemoteBackupStore implements RemoteBackupStore {
  /// Creates the fake.
  FakeRemoteBackupStore({
    this.backups = const <RemoteBackup>[],
    this.uploadResult = const ParseSuccess<void>(null),
    this.listResult,
    this.downloadResult,
  });

  /// The archives the fake lists.
  List<RemoteBackup> backups;

  /// The answer of [upload].
  ParseResult<void> uploadResult;

  /// Overrides the answer of [list] when set.
  ParseResult<List<RemoteBackup>>? listResult;

  /// Overrides the answer of [download] when set.
  ParseResult<List<int>>? downloadResult;

  /// The name of the last uploaded archive.
  String? uploadedName;

  /// The names this fake was asked to delete.
  final List<String> deleted = <String>[];

  @override
  Future<bool> isConfigured() async => true;

  @override
  Future<ParseResult<List<RemoteBackup>>> list() async =>
      listResult ?? ParseSuccess<List<RemoteBackup>>(backups);

  @override
  Future<ParseResult<void>> upload({
    required String name,
    required List<int> bytes,
  }) async {
    uploadedName = name;

    return uploadResult;
  }

  @override
  Future<ParseResult<List<int>>> download(RemoteBackup backup) async =>
      downloadResult ?? const ParseSuccess<List<int>>(<int>[]);

  @override
  Future<ParseResult<void>> delete(RemoteBackup backup) async {
    deleted.add(backup.name);

    return const ParseSuccess<void>(null);
  }

  @override
  Future<ParseResult<int>> prune({required int keep}) async =>
      const ParseSuccess<int>(0);
}

/// A plain [Exception] stand-in: the store answers a `ParseFailure`, it does not propagate this.
final class _StoreFailure implements Exception {
  const _StoreFailure();
}
