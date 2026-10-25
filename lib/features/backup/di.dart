import 'package:flutter_reader/core/app_version.dart';
import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/features/backup/data/backup_repository_impl.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/restore_completion_hook.dart';
import 'package:flutter_reader/features/backup/domain/usecases/create_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/inspect_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/restore_backup.dart';
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

/// Provides the export use case (`ADR-0073` §决策 2).
@Riverpod(keepAlive: true)
Future<CreateBackup> createBackup(Ref ref) async => CreateBackup(
  repository: await ref.watch(backupRepositoryProvider.future),
  clock: ref.watch(clockProvider),
  appVersion: appVersion,
);

/// Provides the preview use case.
@Riverpod(keepAlive: true)
InspectBackup inspectBackup(Ref ref) => const InspectBackup();

/// Provides the restore use case (`ADR-0073` §决策 3).
@Riverpod(keepAlive: true)
Future<RestoreBackup> restoreBackup(Ref ref) async => RestoreBackup(
  repository: await ref.watch(backupRepositoryProvider.future),
  completionHook: ref.watch(restoreCompletionHookProvider),
);

/// Provides the post-restore notification, **unbound** by default.
///
/// The composition root overrides it to invalidate `Settings` and the reader's style provider
/// (`ADR-0073` §决策 3). The default only warns, so a forgotten binding costs a stale theme, not a
/// broken restore.
@Riverpod(keepAlive: true)
RestoreCompletionHook restoreCompletionHook(Ref ref) =>
    UnboundRestoreCompletionHook(logger: ref.watch(appLoggerProvider));
