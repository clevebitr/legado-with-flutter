import 'package:flutter_reader/core/platform/secret_store.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_settings_repository.dart';

/// `shared_preferences` keys of the backup settings.
///
/// Keys are private to this file (the same rule as every other repository: the storage layout is an
/// implementation detail, and a key spelled elsewhere would be a second source for it).
const String _autoEnabledKey = 'backup.isAutoEnabled';
const String _retentionKey = 'backup.retention';
const String _folderKey = 'backup.folder';
const String _webDavUrlKey = 'backup.webdav.url';
const String _webDavUserKey = 'backup.webdav.username';
const String _lastAutoBackupKey = 'backup.lastAutoBackupAt';

/// Key of the backup password **inside the platform key store**.
const String backupPasswordSecretKey = 'backup.password';

/// Key of the WebDAV password inside the platform key store.
const String webDavPasswordSecretKey = 'backup.webdav.password';

/// [BackupSettingsRepository] on top of [PreferenceStore] + [SecretStore]
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/5).
///
/// Non-secret values go to `shared_preferences` (C-NET-9); the two passwords go to the key store, so
/// nothing here has to decide where a secret belongs.
final class BackupSettingsRepositoryImpl implements BackupSettingsRepository {
  /// Creates the repository.
  const BackupSettingsRepositoryImpl({
    required this._preferences,
    required this._secrets,
  });

  final PreferenceStore _preferences;
  final SecretStore _secrets;

  @override
  Future<BackupSettings> load() async {
    final String? folder = _preferences.readString(_folderKey);

    return BackupSettings(
      isAutoEnabled: _preferences.readBool(_autoEnabledKey) ?? false,
      retention: _preferences.readInt(_retentionKey) ?? defaultBackupRetention,
      location: folder == null
          ? const AppPrivateBackupLocation()
          : FolderBackupLocation(folder),
      hasPassword: await _secrets.read(backupPasswordSecretKey) != null,
      webDavUrl: _preferences.readString(_webDavUrlKey) ?? '',
      webDavUsername: _preferences.readString(_webDavUserKey) ?? '',
      hasWebDavPassword: await _secrets.read(webDavPasswordSecretKey) != null,
      lastAutoBackupAt: _readLastAutoBackup(),
    );
  }

  @override
  Future<void> save(BackupSettings settings) async {
    await _preferences.writeBool(_autoEnabledKey, settings.isAutoEnabled);
    // 存的是**钳制后**的值：界面读回来的永远是 UI 能表示的范围，界面与策略不会分叉。
    await _preferences.writeInt(_retentionKey, settings.retention);
    switch (settings.location) {
      case AppPrivateBackupLocation():
        await _preferences.remove(_folderKey);
      case FolderBackupLocation(:final String path):
        await _preferences.writeString(_folderKey, path);
    }
    await _preferences.writeString(_webDavUrlKey, settings.webDavUrl);
    await _preferences.writeString(_webDavUserKey, settings.webDavUsername);
    await _writeLastAutoBackup(settings.lastAutoBackupAt);
  }

  @override
  Future<String?> readPassword() => _secrets.read(backupPasswordSecretKey);

  @override
  Future<bool> writePassword(String? value) =>
      _writeSecret(backupPasswordSecretKey, value);

  @override
  Future<String?> readWebDavPassword() =>
      _secrets.read(webDavPasswordSecretKey);

  @override
  Future<bool> writeWebDavPassword(String? value) =>
      _writeSecret(webDavPasswordSecretKey, value);

  @override
  Future<BackupLocation> loadLocation() async {
    final String? folder = _preferences.readString(_folderKey);

    return folder == null
        ? const AppPrivateBackupLocation()
        : FolderBackupLocation(folder);
  }

  Future<bool> _writeSecret(String key, String? value) =>
      value == null ? _secrets.delete(key) : _secrets.write(key, value);

  DateTime? _readLastAutoBackup() {
    final String? stored = _preferences.readString(_lastAutoBackupKey);

    return stored == null ? null : DateTime.tryParse(stored);
  }

  Future<void> _writeLastAutoBackup(DateTime? instant) => instant == null
      ? _preferences.remove(_lastAutoBackupKey)
      : _preferences.writeString(
          _lastAutoBackupKey,
          instant.toUtc().toIso8601String(),
        );
}
