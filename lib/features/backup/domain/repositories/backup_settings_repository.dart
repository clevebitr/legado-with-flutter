import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';

/// Reads and writes the backup feature's settings and its two secrets
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/5).
///
/// Non-secret values live in `shared_preferences`, passwords in the platform key store. Splitting the
/// port this way keeps every caller from deciding where a password goes.
abstract interface class BackupSettingsRepository {
  /// Reads the stored settings, falling back to [BackupSettings.defaults] per field.
  Future<BackupSettings> load();

  /// Writes every non-secret field of [settings].
  Future<void> save(BackupSettings settings);

  /// The backup password, or `null` when none is stored (⇒ archives are not encrypted).
  Future<String?> readPassword();

  /// Stores the backup password, or removes it when [value] is `null`.
  ///
  /// Answers whether the store accepted it; a platform without a key store answers `false` and the
  /// page then warns that backups stay unencrypted.
  Future<bool> writePassword(String? value);

  /// The WebDAV password, or `null` when none is stored.
  Future<String?> readWebDavPassword();

  /// Stores the WebDAV password, or removes it when [value] is `null`.
  Future<bool> writeWebDavPassword(String? value);

  /// The location the automatic backup and the safety copies use, resolving the stored folder or
  /// falling back to [AppPrivateBackupLocation].
  Future<BackupLocation> loadLocation();
}
