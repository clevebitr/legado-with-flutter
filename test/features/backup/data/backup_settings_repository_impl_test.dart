import 'package:flutter_reader/core/platform/secret_store.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/backup/data/backup_settings_repository_impl.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory key store.
final class _MemorySecrets implements SecretStore {
  _MemorySecrets({this.isAvailable = true});

  final bool isAvailable;
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<bool> write(String key, String value) async {
    if (!isAvailable) {
      return false;
    }
    values[key] = value;

    return true;
  }

  @override
  Future<bool> delete(String key) async {
    values.remove(key);

    return true;
  }
}

void main() {
  late _MemorySecrets secrets;
  late BackupSettingsRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    secrets = _MemorySecrets();
    repository = BackupSettingsRepositoryImpl(
      preferences: PreferenceStore(await SharedPreferences.getInstance()),
      secrets: secrets,
    );
  });

  test('load_givenNothingStored_answersTheDefaults', () async {
    final BackupSettings settings = await repository.load();

    expect(settings.isAutoEnabled, isFalse);
    expect(settings.retention, defaultBackupRetention);
    expect(settings.location, isA<AppPrivateBackupLocation>());
    expect(settings.hasPassword, isFalse);
    expect(settings.webDavUrl, isEmpty);
    expect(settings.lastAutoBackupAt, isNull);
  });

  test('save_givenAFolderLocation_roundTripsIt', () async {
    await repository.save(
      BackupSettings(
        isAutoEnabled: true,
        retention: 10,
        location: const FolderBackupLocation('/usb/backups'),
        webDavUrl: 'https://dav.test/b',
        webDavUsername: 'u',
        lastAutoBackupAt: DateTime.utc(2026, 10, 25),
      ),
    );

    final BackupSettings settings = await repository.load();
    expect(settings.isAutoEnabled, isTrue);
    expect(settings.retention, 10);
    expect((settings.location as FolderBackupLocation).path, '/usb/backups');
    expect(settings.webDavUrl, 'https://dav.test/b');
    expect(settings.webDavUsername, 'u');
    expect(settings.lastAutoBackupAt, DateTime.utc(2026, 10, 25));
    expect(await repository.loadLocation(), isA<FolderBackupLocation>());
  });

  test('save_givenThePrivateLocation_dropsTheStoredFolder', () async {
    await repository.save(
      BackupSettings(location: const FolderBackupLocation('/usb')),
    );
    await repository.save(
      BackupSettings(location: const AppPrivateBackupLocation()),
    );

    expect(await repository.loadLocation(), isA<AppPrivateBackupLocation>());
  });

  test('save_givenNoLastBackup_clearsTheStoredInstant', () async {
    await repository.save(BackupSettings(lastAutoBackupAt: DateTime.utc(2026)));
    await repository.save(BackupSettings());

    expect((await repository.load()).lastAutoBackupAt, isNull);
  });

  test('writePassword_givenAKeyStore_storesItAndFlipsTheFlag', () async {
    expect(await repository.writePassword('secret'), isTrue);

    expect(secrets.values[backupPasswordSecretKey], 'secret');
    expect((await repository.load()).hasPassword, isTrue);
  });

  test('writePassword_givenNull_removesIt', () async {
    await repository.writePassword('secret');
    await repository.writePassword(null);

    expect(secrets.values, isEmpty);
    expect((await repository.load()).hasPassword, isFalse);
  });

  test('writePassword_givenAnUnavailableKeyStore_answersFalse', () async {
    secrets = _MemorySecrets(isAvailable: false);
    repository = BackupSettingsRepositoryImpl(
      preferences: PreferenceStore(await SharedPreferences.getInstance()),
      secrets: secrets,
    );

    expect(await repository.writePassword('secret'), isFalse);
    expect((await repository.load()).hasPassword, isFalse);
  });

  test('WebDavPassword_roundTripsThroughTheKeyStore', () async {
    expect(await repository.writeWebDavPassword('dav-secret'), isTrue);

    expect(secrets.values[webDavPasswordSecretKey], 'dav-secret');
    expect(await repository.readWebDavPassword(), 'dav-secret');
    expect((await repository.load()).hasWebDavPassword, isTrue);
  });
}
