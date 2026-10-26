import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/di.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_settings_controller.g.dart';

/// The backup settings and the only place that writes them
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/5).
///
/// Reading and writing go through [BackupSettingsRepository], so this class never touches
/// `shared_preferences` or the key store; it only turns user intents into a saved entity.
@riverpod
class BackupSettingsController extends _$BackupSettingsController {
  @override
  Future<BackupSettings> build() async =>
      (await ref.watch(backupSettingsRepositoryProvider.future)).load();

  /// Turns the daily automatic backup on or off.
  Future<void> setAutoEnabled(bool isEnabled) => _update(
    (BackupSettings current) => current.copyWith(isAutoEnabled: isEnabled),
  );

  /// Sets the retention; the entity clamps it into `1..30`.
  Future<void> setRetention(int retention) => _update(
    (BackupSettings current) => current.copyWith(retention: retention),
  );

  /// Sets the backup location to [location].
  Future<void> setLocation(BackupLocation location) =>
      _update((BackupSettings current) => current.copyWith(location: location));

  /// Asks the platform for a folder and stores it as the backup location.
  ///
  /// Answers the failure so the page can explain a dialog that did not open.
  Future<ParseResult<bool>> chooseLocation() async {
    final ParseResult<String?> picked = await ref
        .read(backupDirectoryPickerProvider)
        .pick();
    switch (picked) {
      case ParseFailure<String?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<bool>(kind: kind, rulePath: rulePath);
      case ParseSuccess<String?>(:final String? data):
        if (data == null) {
          return const ParseSuccess<bool>(false);
        }
        await setLocation(FolderBackupLocation(data));

        return const ParseSuccess<bool>(true);
    }
  }

  /// Goes back to the app's private directory.
  Future<void> resetLocation() => setLocation(const AppPrivateBackupLocation());

  /// Stores (or clears, when [password] is `null`/empty) the backup password.
  ///
  /// Answers whether the key store accepted it; a platform without one answers `false`, and the page
  /// then says the backups stay unencrypted (`ADR-0074` §决策 5).
  Future<bool> setPassword(String? password) async {
    final BackupSettingsRepository repository = await ref.read(
      backupSettingsRepositoryProvider.future,
    );
    final String? value = (password == null || password.isEmpty)
        ? null
        : password;
    final bool stored = await repository.writePassword(value);
    if (ref.mounted) {
      final BackupSettings current = await future;
      state = AsyncData<BackupSettings>(
        current.copyWith(hasPassword: value != null && stored),
      );
    }

    return stored;
  }

  /// Stores the WebDAV configuration; the password goes to the key store.
  Future<bool> setWebDav({
    required String url,
    required String username,
    required String password,
  }) async {
    final BackupSettingsRepository repository = await ref.read(
      backupSettingsRepositoryProvider.future,
    );
    final bool stored = password.isEmpty
        ? await repository.writeWebDavPassword(null)
        : await repository.writeWebDavPassword(password);
    final BackupSettings current = await future;
    final BackupSettings next = current.copyWith(
      webDavUrl: url.trim(),
      webDavUsername: username.trim(),
      hasWebDavPassword: password.isNotEmpty && stored,
    );
    await repository.save(next);
    if (ref.mounted) {
      state = AsyncData<BackupSettings>(next);
    }

    return stored;
  }

  Future<void> _update(
    BackupSettings Function(BackupSettings current) change,
  ) async {
    final BackupSettingsRepository repository = await ref.read(
      backupSettingsRepositoryProvider.future,
    );
    final BackupSettings next = change(await future);
    await repository.save(next);
    if (ref.mounted) {
      state = AsyncData<BackupSettings>(next);
    }
  }
}
