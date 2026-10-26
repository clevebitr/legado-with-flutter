import 'package:flutter_reader/core/app_version.dart';
import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/di/web_dav_provider.dart';
import 'package:flutter_reader/features/backup/data/backup_repository_impl.dart';
import 'package:flutter_reader/features/backup/data/backup_settings_repository_impl.dart';
import 'package:flutter_reader/features/backup/data/file_system_local_backup_store.dart';
import 'package:flutter_reader/features/backup/data/web_dav_remote_backup_store.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_settings_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/local_backup_store.dart';
import 'package:flutter_reader/features/backup/domain/repositories/remote_backup_store.dart';
import 'package:flutter_reader/features/backup/domain/repositories/restore_completion_hook.dart';
import 'package:flutter_reader/features/backup/domain/usecases/auto_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/create_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/inspect_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/restore_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/save_backup.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides the backup repository over every table it carries (`ADR-0073` §决策 4).
@Riverpod(keepAlive: true)
Future<BackupRepository> backupRepository(Ref ref) async =>
    BackupRepositoryImpl(
      database: ref.watch(readerDatabaseProvider),
      sources: ref.watch(bookSourceDaoProvider),
      books: ref.watch(bookshelfDaoProvider),
      groups: ref.watch(shelfGroupDaoProvider),
      bookmarks: ref.watch(bookmarkDaoProvider),
      records: ref.watch(readRecordDaoProvider),
      rules: ref.watch(ruleDaoProvider),
      preferences: await ref.watch(preferenceStoreProvider.future),
    );

/// Provides the backup settings and the two key-store secrets (`ADR-0074` §决策 1/5).
@Riverpod(keepAlive: true)
Future<BackupSettingsRepository> backupSettingsRepository(Ref ref) async =>
    BackupSettingsRepositoryImpl(
      preferences: await ref.watch(preferenceStoreProvider.future),
      secrets: ref.watch(secretStoreProvider),
    );

/// Provides the local archive store (`ADR-0074` §决策 1/2).
@Riverpod(keepAlive: true)
LocalBackupStore localBackupStore(Ref ref) =>
    const FileSystemLocalBackupStore();

/// Provides the WebDAV side of the backup (`ADR-0074` §决策 6).
@Riverpod(keepAlive: true)
Future<RemoteBackupStore> remoteBackupStore(Ref ref) async =>
    WebDavRemoteBackupStore(
      client: ref.watch(webDavClientProvider),
      settings: await ref.watch(backupSettingsRepositoryProvider.future),
      // 明文 http 只有用户显式打开 allowPlainHttp 才允许（C-SEC-2 的同一个开关）。
      allowPlainHttp: ref.watch(plainHttpSettingProvider),
    );

/// Provides the export use case (`ADR-0073` §决策 2).
@Riverpod(keepAlive: true)
Future<CreateBackup> createBackup(Ref ref) async => CreateBackup(
  repository: await ref.watch(backupRepositoryProvider.future),
  clock: ref.watch(clockProvider),
  appVersion: appVersion,
);

/// Provides the "encode and write to the backup location" use case (`ADR-0074` §决策 1/2).
@Riverpod(keepAlive: true)
Future<SaveBackup> saveBackup(Ref ref) async => SaveBackup(
  repository: await ref.watch(backupRepositoryProvider.future),
  settings: await ref.watch(backupSettingsRepositoryProvider.future),
  localStore: ref.watch(localBackupStoreProvider),
  clock: ref.watch(clockProvider),
  appVersion: appVersion,
);

/// Provides the daily automatic backup (`ADR-0074` §决策 2).
@Riverpod(keepAlive: true)
Future<AutoBackup> autoBackup(Ref ref) async => AutoBackup(
  settings: await ref.watch(backupSettingsRepositoryProvider.future),
  saveBackup: await ref.watch(saveBackupProvider.future),
  clock: ref.watch(clockProvider),
);

/// Provides the preview use case.
@Riverpod(keepAlive: true)
InspectBackup inspectBackup(Ref ref) => const InspectBackup();

/// Provides the restore use case (`ADR-0073` §决策 3 / `ADR-0074` §决策 3).
@Riverpod(keepAlive: true)
Future<RestoreBackup> restoreBackup(Ref ref) async => RestoreBackup(
  repository: await ref.watch(backupRepositoryProvider.future),
  completionHook: ref.watch(restoreCompletionHookProvider),
  settings: await ref.watch(backupSettingsRepositoryProvider.future),
  saveBackup: await ref.watch(saveBackupProvider.future),
);

/// Provides the post-restore notification, **unbound** by default.
///
/// The composition root overrides it to invalidate `Settings` and the reader's style provider
/// (`ADR-0073` §决策 3). The default only warns, so a forgotten binding costs a stale theme, not a
/// broken restore.
@Riverpod(keepAlive: true)
RestoreCompletionHook restoreCompletionHook(Ref ref) =>
    UnboundRestoreCompletionHook(logger: ref.watch(appLoggerProvider));

/// The archives already in the configured location, newest first (`ADR-0074` §决策 2).
@Riverpod(keepAlive: true)
Future<List<StoredBackup>> localBackups(Ref ref) async {
  final BackupSettingsRepository settings = await ref.watch(
    backupSettingsRepositoryProvider.future,
  );

  return ref
      .watch(localBackupStoreProvider)
      .list(await settings.loadLocation());
}
