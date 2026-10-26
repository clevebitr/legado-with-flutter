import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_archive_picker.dart';
import 'package:flutter_reader/features/backup/di.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_manifest.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/restore_mode.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/repositories/remote_backup_store.dart';
import 'package:flutter_reader/features/backup/domain/usecases/create_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/restore_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/save_backup.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_notifier.freezed.dart';
part 'backup_notifier.g.dart';

/// What the page is busy with, so the progress line can name it.
enum BackupAction {
  /// Writing a new archive into the backup location.
  exporting,

  /// Asking the platform where to save a copy.
  savingAs,

  /// Opening and validating an archive.
  reading,

  /// Merging (or overwriting) a validated archive into the database.
  restoring,

  /// Sending the archive to the WebDAV collection.
  uploading,

  /// Listing the WebDAV collection.
  listingRemote,

  /// Fetching one archive from the WebDAV collection.
  downloading,
}

/// What the backup page shows (`docs/dev/roadmap.md` M22, ADR-0073 / ADR-0074).
@freezed
sealed class BackupState with _$BackupState {
  /// Nothing is happening; every action is available.
  const factory BackupState.idle() = BackupIdle;

  /// One action is running; the actions are disabled.
  const factory BackupState.working(BackupAction action) = BackupWorking;

  /// An archive was read and is waiting for confirmation.
  const factory BackupState.previewReady({
    required BackupPreview preview,
    required List<int> bytes,
    @Default(false) bool isRemote,
  }) = BackupPreviewReady;

  /// An encrypted archive needs its password before it can be read.
  const factory BackupState.passwordNeeded({
    required List<int> bytes,
    @Default(false) bool isRetry,
    @Default(false) bool isRemote,
  }) = BackupPasswordNeeded;

  /// An archive was written and saved.
  const factory BackupState.exported({
    required String fileName,
    required int totalRows,
    required String path,
  }) = BackupExported;

  /// A restore committed.
  const factory BackupState.restored(RestoreOutcome outcome) = BackupRestored;

  /// The remote collection was listed.
  const factory BackupState.remoteListed(List<RemoteBackup> backups) =
      BackupRemoteListed;

  /// The last action failed; the UI maps [kind] to text (C-ERR-7).
  const factory BackupState.failed(ParseFailureKind kind) = BackupFailed;
}

/// Drives every backup action (`docs/dev/roadmap.md` M22, ADR-0073 / ADR-0074).
///
/// Three orders are owned here because they *are* the feature:
///
/// * an archive is decoded and validated completely before a single row is written;
/// * an overwrite restore writes a safety copy first and aborts when that copy fails;
/// * an encrypted archive asks for its password only after the codec said it needs one.
@riverpod
class Backup extends _$Backup {
  @override
  BackupState build() => const BackupState.idle();

  /// Writes one archive into the configured backup location and prunes it.
  Future<void> saveToLocation() async {
    state = const BackupState.working(BackupAction.exporting);

    try {
      final SaveBackup useCase = await ref.read(saveBackupProvider.future);
      final ParseResult<StoredBackup> saved = await useCase.execute();
      if (!ref.mounted) {
        return;
      }

      state = switch (saved) {
        ParseSuccess<StoredBackup>(:final StoredBackup data) =>
          BackupState.exported(
            fileName: data.name,
            totalRows: 0,
            path: data.path,
          ),
        ParseFailure<StoredBackup>(:final ParseFailureKind kind) =>
          BackupState.failed(kind),
      };
    } on Exception catch (error, stackTrace) {
      _failed('Backup export failed', error, stackTrace);
    }
  }

  /// Encodes one archive and hands it to the platform save dialog.
  Future<void> saveAs() async {
    state = const BackupState.working(BackupAction.savingAs);

    try {
      final CreateBackup useCase = await ref.read(createBackupProvider.future);
      final BackupArchive archive = await useCase.execute(
        password: await _storedPassword(),
      );
      if (!ref.mounted) {
        return;
      }

      final ParseResult<bool> saved = await ref
          .read(backupArchiveSaverProvider)
          .save(suggestedName: archive.suggestedName, bytes: archive.bytes);
      if (!ref.mounted) {
        return;
      }

      state = switch (saved) {
        ParseSuccess<bool>(data: false) => const BackupState.idle(),
        ParseSuccess<bool>() => BackupState.exported(
          fileName: archive.suggestedName,
          totalRows: archive.counts.values.fold(
            0,
            (int sum, int count) => sum + count,
          ),
          path: '',
        ),
        ParseFailure<bool>(:final ParseFailureKind kind) => BackupState.failed(
          kind,
        ),
      };
    } on Exception catch (error, stackTrace) {
      _failed('Backup export failed', error, stackTrace);
    }
  }

  /// Lets the user pick a local archive and publishes what it holds.
  Future<void> chooseFileToRestore() async {
    state = const BackupState.working(BackupAction.reading);

    try {
      final ParseResult<PickedBackupArchive?> picked = await ref
          .read(backupArchivePickerProvider)
          .pick(maxBytes: maxBackupArchiveBytes);
      if (!ref.mounted) {
        return;
      }

      switch (picked) {
        case ParseFailure<PickedBackupArchive?>(:final ParseFailureKind kind):
          state = BackupState.failed(kind);
        case ParseSuccess<PickedBackupArchive?>(data: null):
          state = const BackupState.idle();
        case ParseSuccess<PickedBackupArchive?>(
          :final PickedBackupArchive data,
        ):
          await _preview(data.bytes);
      }
    } on Exception catch (error, stackTrace) {
      _failed('Backup preview failed', error, stackTrace);
    }
  }

  /// Lists the archives in the configured WebDAV collection.
  Future<void> listRemote() async {
    state = const BackupState.working(BackupAction.listingRemote);

    try {
      final RemoteBackupStore store = await ref.read(
        remoteBackupStoreProvider.future,
      );
      final ParseResult<List<RemoteBackup>> listed = await store.list();
      if (!ref.mounted) {
        return;
      }

      state = switch (listed) {
        ParseSuccess<List<RemoteBackup>>(:final List<RemoteBackup> data) =>
          BackupState.remoteListed(data),
        ParseFailure<List<RemoteBackup>>(:final ParseFailureKind kind) =>
          BackupState.failed(kind),
      };
    } on Exception catch (error, stackTrace) {
      _failed('Listing the remote backups failed', error, stackTrace);
    }
  }

  /// Downloads one remote archive and publishes its preview.
  Future<void> previewRemote(RemoteBackup backup) async {
    state = const BackupState.working(BackupAction.downloading);

    try {
      final RemoteBackupStore store = await ref.read(
        remoteBackupStoreProvider.future,
      );
      final ParseResult<List<int>> downloaded = await store.download(backup);
      if (!ref.mounted) {
        return;
      }

      switch (downloaded) {
        case ParseFailure<List<int>>(:final ParseFailureKind kind):
          state = BackupState.failed(kind);
        case ParseSuccess<List<int>>(:final List<int> data):
          await _preview(data, isRemote: true);
      }
    } on Exception catch (error, stackTrace) {
      _failed('Downloading a remote backup failed', error, stackTrace);
    }
  }

  /// Uploads a fresh archive to the collection and prunes it to the retention.
  Future<void> uploadToCloud() async {
    state = const BackupState.working(BackupAction.uploading);

    try {
      final CreateBackup create = await ref.read(createBackupProvider.future);
      final RemoteBackupStore store = await ref.read(
        remoteBackupStoreProvider.future,
      );
      final BackupArchive archive = await create.execute(
        password: await _storedPassword(),
      );
      if (!ref.mounted) {
        return;
      }

      final ParseResult<void> uploaded = await store.upload(
        name: archive.suggestedName,
        bytes: archive.bytes,
      );
      if (!ref.mounted) {
        return;
      }
      if (uploaded is ParseFailure<void>) {
        state = BackupState.failed(uploaded.kind);

        return;
      }

      // 远端保留份数与本地同一口径；失败只记日志，上传本身已经成功（ADR-0074 §决策 6）。
      final int keep = (await _settings()).retention;
      final ParseResult<int> pruned = await store.prune(keep: keep);
      if (pruned is ParseFailure<int>) {
        ref
            .read(appLoggerProvider)
            .warning('Pruning the remote backups failed: ${pruned.rulePath}');
      }
      if (!ref.mounted) {
        return;
      }

      await listRemote();
    } on Exception catch (error, stackTrace) {
      _failed('Uploading the backup failed', error, stackTrace);
    }
  }

  /// Deletes one remote archive.
  Future<void> deleteRemote(RemoteBackup backup) async {
    try {
      final RemoteBackupStore store = await ref.read(
        remoteBackupStoreProvider.future,
      );
      final ParseResult<void> deleted = await store.delete(backup);
      if (!ref.mounted) {
        return;
      }

      state = switch (deleted) {
        ParseSuccess<void>() => const BackupState.idle(),
        ParseFailure<void>(:final ParseFailureKind kind) => BackupState.failed(
          kind,
        ),
      };
      if (deleted is ParseSuccess<void>) {
        await listRemote();
      }
    } on Exception catch (error, stackTrace) {
      _failed('Deleting a remote backup failed', error, stackTrace);
    }
  }

  /// Retries the preview with the password the user typed.
  Future<void> retryWithPassword(String password) async {
    final BackupState current = state;
    if (current is! BackupPasswordNeeded) {
      return;
    }
    state = const BackupState.working(BackupAction.reading);

    await _preview(
      current.bytes,
      password: password,
      isRemote: current.isRemote,
      isRetry: true,
    );
  }

  /// Merges or overwrites with the previewed archive.
  Future<void> confirmRestore(RestoreMode mode, {String? password}) async {
    final BackupState current = state;
    if (current is! BackupPreviewReady) {
      return;
    }
    state = const BackupState.working(BackupAction.restoring);

    try {
      final RestoreBackup useCase = await ref.read(
        restoreBackupProvider.future,
      );
      final ParseResult<RestoreOutcome> result = await useCase.execute(
        bytes: current.bytes,
        mode: mode,
        password: password,
      );
      if (!ref.mounted) {
        return;
      }

      state = switch (result) {
        ParseSuccess<RestoreOutcome>(:final RestoreOutcome data) =>
          BackupState.restored(data),
        ParseFailure<RestoreOutcome>(:final ParseFailureKind kind) =>
          BackupState.failed(kind),
      };
    } on Exception catch (error, stackTrace) {
      _failed('Backup restore failed', error, stackTrace);
    }
  }

  /// Drops the preview without writing anything.
  void cancelPreview() => state = const BackupState.idle();

  /// Reads [bytes] and publishes the preview, or asks for the password.
  Future<void> _preview(
    List<int> bytes, {
    String? password,
    bool isRemote = false,
    bool isRetry = false,
  }) async {
    final String? effective = password ?? await _storedPassword();
    final ParseResult<BackupPreview> preview = await ref
        .read(inspectBackupProvider)
        .execute(bytes: bytes, password: effective);
    if (!ref.mounted) {
      return;
    }

    state = switch (preview) {
      ParseSuccess<BackupPreview>(:final BackupPreview data) =>
        BackupState.previewReady(
          preview: data,
          bytes: bytes,
          isRemote: isRemote,
        ),
      ParseFailure<BackupPreview>(:final String rulePath)
          when rulePath == 'backup.read.passwordRequired' =>
        BackupState.passwordNeeded(
          bytes: bytes,
          isRemote: isRemote,
          isRetry: isRetry,
        ),
      ParseFailure<BackupPreview>(:final ParseFailureKind kind) =>
        BackupState.failed(kind),
    };
  }

  Future<String?> _storedPassword() async =>
      (await ref.read(backupSettingsRepositoryProvider.future)).readPassword();

  Future<BackupSettings> _settings() async =>
      (await ref.read(backupSettingsRepositoryProvider.future)).load();

  void _failed(String message, Exception error, StackTrace stackTrace) {
    // C-ERR-2 的 presentation 兜底：数据库与文件系统错误只可能在这里被接住。
    ref.read(appLoggerProvider).error(message, error, stackTrace);
    if (ref.mounted) {
      state = const BackupState.failed(ParseFailureKind.parseFailed);
    }
  }
}
