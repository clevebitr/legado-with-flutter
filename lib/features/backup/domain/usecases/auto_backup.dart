import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_settings_repository.dart';
import 'package:flutter_reader/features/backup/domain/usecases/save_backup.dart';

/// How long one automatic backup lasts: the same one-day throttle upstream uses
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 2).
const Duration autoBackupInterval = Duration(days: 1);

/// Runs the daily backup when it is due (`docs/dev/roadmap.md` M22, ADR-0074 §决策 2).
///
/// Called once after the app shell's first frame. There is no background scheduler: upstream also
/// backups at start-up, and a真 background job would need a new dependency plus permissions on three
/// platforms (registered in `roadmap.md` §3.7).
final class AutoBackup {
  /// Creates the use case.
  const AutoBackup({
    required this._settings,
    required this._saveBackup,
    required this._clock,
  });

  final BackupSettingsRepository _settings;
  final SaveBackup _saveBackup;
  final Clock _clock;

  /// Writes a backup when the switch is on and the last one is older than one day.
  ///
  /// Answers the file that was written, or `null` when nothing was due — the caller stays silent in
  /// that case. The timestamp is only advanced **after** a successful write, so a failed attempt is
  /// retried on the next start instead of waiting another day.
  Future<ParseResult<StoredBackup?>> execute() async {
    final BackupSettings settings = await _settings.load();
    if (!settings.isAutoEnabled) {
      return const ParseSuccess<StoredBackup?>(null);
    }
    final DateTime now = _clock.now();
    final DateTime? last = settings.lastAutoBackupAt;
    if (last != null && now.difference(last) < autoBackupInterval) {
      return const ParseSuccess<StoredBackup?>(null);
    }

    final ParseResult<StoredBackup> saved = await _saveBackup.execute();
    switch (saved) {
      case ParseSuccess<StoredBackup>(:final StoredBackup data):
        await _settings.save(settings.copyWith(lastAutoBackupAt: now));

        return ParseSuccess<StoredBackup?>(data);
      case ParseFailure<StoredBackup>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<StoredBackup?>(kind: kind, rulePath: rulePath);
    }
  }
}
