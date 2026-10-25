import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_settings_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/local_backup_store.dart';
import 'package:flutter_reader/features/backup/domain/usecases/create_backup.dart';

/// Produces one archive and writes it to the configured backup location
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/2).
///
/// The automatic backup, the safety copy before an overwrite restore and the page's
/// 「保存到备份位置」 are the same three steps — collect, encode (with the password if one is stored),
/// write, prune — so they live here instead of being spelled three times.
final class SaveBackup {
  /// Creates the use case.
  const SaveBackup({
    required this._repository,
    required this._settings,
    required this._localStore,
    required this._clock,
    required this._appVersion,
  });

  final BackupRepository _repository;
  final BackupSettingsRepository _settings;
  final LocalBackupStore _localStore;
  final Clock _clock;
  final String _appVersion;

  /// Writes one archive into [location] (default: the configured one) and prunes afterwards.
  ///
  /// [isSafetyCopy] switches the file name to the timestamped `backup-before-restore-…` form, which
  /// never overwrites an existing archive. Pruning still applies, so safety copies cannot pile up.
  Future<ParseResult<StoredBackup>> execute({
    BackupLocation? location,
    bool isSafetyCopy = false,
    int? keep,
    String? passwordOverride,
  }) async {
    final BackupSettings settings = await _settings.load();
    final String? password = passwordOverride ?? await _settings.readPassword();
    final DateTime now = _clock.now();
    final CreateBackup create = CreateBackup(
      repository: _repository,
      clock: _clock,
      appVersion: _appVersion,
    );
    final BackupArchive archive = await create.execute(password: password);
    final String name = isSafetyCopy
        ? safetyBackupNameFor(now, isEncrypted: password != null)
        : backupNameFor(now, isEncrypted: password != null);

    try {
      final StoredBackup written = await _localStore.write(
        location: location ?? settings.location,
        name: name,
        bytes: archive.bytes,
      );
      await _localStore.prune(
        location: location ?? settings.location,
        keep: keep ?? settings.retention,
      );

      return ParseSuccess<StoredBackup>(written);
    } on Exception {
      // 文件系统失败（只读介质、权限、磁盘满）：给带位置的失败，而不是让异常冒到 UI。
      return failureAt<StoredBackup>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'backup.write',
      );
    }
  }
}

/// Decodes an archive with the password that applies to it
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 4).
///
/// Kept out of the inspect and restore use cases so both ask the same question in the same order:
/// the password the user typed wins, otherwise the stored one is used, and an encrypted archive with
/// neither answers `backup.read.passwordRequired`.
Future<String?> passwordForArchive({
  required BackupSettingsRepository settings,
  String? typed,
}) async {
  if (typed != null && typed.isNotEmpty) {
    return typed;
  }

  return settings.readPassword();
}
