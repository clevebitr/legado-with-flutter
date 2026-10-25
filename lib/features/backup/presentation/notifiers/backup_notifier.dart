import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_archive_picker.dart';
import 'package:flutter_reader/features/backup/di.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_manifest.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_restore_report.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/usecases/create_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/restore_backup.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_notifier.freezed.dart';
part 'backup_notifier.g.dart';

/// What the page is busy with, so the progress line can name it.
enum BackupAction {
  /// Writing a new archive and asking where to save it.
  exporting,

  /// Opening and validating an archive the user picked.
  reading,

  /// Merging a validated archive into the database.
  restoring,
}

/// What the backup page shows (`docs/dev/roadmap.md` M22, ADR-0073).
@freezed
sealed class BackupState with _$BackupState {
  /// Nothing is happening; both actions are available.
  const factory BackupState.idle() = BackupIdle;

  /// One action is running; both actions are disabled.
  const factory BackupState.working(BackupAction action) = BackupWorking;

  /// An archive was read and is waiting for confirmation.
  const factory BackupState.previewReady({
    required BackupPreview preview,
    required List<int> bytes,
  }) = BackupPreviewReady;

  /// An archive was written and saved.
  const factory BackupState.exported({
    required String fileName,
    required int totalRows,
  }) = BackupExported;

  /// A restore committed.
  const factory BackupState.restored(BackupRestoreReport report) =
      BackupRestored;

  /// The last action failed; the UI maps [kind] to text (C-ERR-7).
  const factory BackupState.failed(ParseFailureKind kind) = BackupFailed;
}

/// Drives export and restore (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// The notifier owns the order the restore needs — read and preview first, write only after the user
/// confirms — because that order *is* the feature: an archive is decoded and validated completely
/// before a single row is written (ADR-0073 §决策 3).
@riverpod
class Backup extends _$Backup {
  @override
  BackupState build() => const BackupState.idle();

  /// Collects the database, writes one archive, and asks the platform where to put it.
  Future<void> export() async {
    state = const BackupState.working(BackupAction.exporting);

    try {
      final CreateBackup useCase = await ref.read(createBackupProvider.future);
      final BackupArchive archive = await useCase.execute();
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
        // 取消不是失败：回到可以再来一次的状态，界面上不报错。
        ParseSuccess<bool>(data: false) => const BackupState.idle(),
        ParseSuccess<bool>() => BackupState.exported(
          fileName: archive.suggestedName,
          totalRows: archive.counts.values.fold(
            0,
            (int sum, int count) => sum + count,
          ),
        ),
        ParseFailure<bool>(:final ParseFailureKind kind) => BackupState.failed(
          kind,
        ),
      };
    } on Exception catch (error, stackTrace) {
      // C-ERR-2 的 presentation 兜底：数据库错误只可能在这里被接住，记一条并给失败态。
      ref
          .read(appLoggerProvider)
          .error('Backup export failed', error, stackTrace);
      if (ref.mounted) {
        state = const BackupState.failed(ParseFailureKind.parseFailed);
      }
    }
  }

  /// Lets the user pick an archive and publishes what it holds; nothing is written yet.
  Future<void> chooseToRestore() async {
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
      ref
          .read(appLoggerProvider)
          .error('Backup preview failed', error, stackTrace);
      if (ref.mounted) {
        state = const BackupState.failed(ParseFailureKind.parseFailed);
      }
    }
  }

  /// Reads [bytes] and publishes the preview.
  Future<void> _preview(List<int> bytes) async {
    final ParseResult<BackupPreview> preview = await ref
        .read(inspectBackupProvider)
        .execute(bytes: bytes);
    if (!ref.mounted) {
      return;
    }

    state = switch (preview) {
      ParseSuccess<BackupPreview>(:final BackupPreview data) =>
        BackupState.previewReady(preview: data, bytes: bytes),
      ParseFailure<BackupPreview>(:final ParseFailureKind kind) =>
        BackupState.failed(kind),
    };
  }

  /// Merges the previewed archive into the database.
  Future<void> confirmRestore() async {
    final BackupState current = state;
    if (current is! BackupPreviewReady) {
      return;
    }
    final List<int> bytes = current.bytes;
    state = const BackupState.working(BackupAction.restoring);

    try {
      final RestoreBackup useCase = await ref.read(
        restoreBackupProvider.future,
      );
      final ParseResult<BackupRestoreReport> result = await useCase.execute(
        bytes: bytes,
      );
      if (!ref.mounted) {
        return;
      }

      state = switch (result) {
        ParseSuccess<BackupRestoreReport>(:final BackupRestoreReport data) =>
          BackupState.restored(data),
        ParseFailure<BackupRestoreReport>(:final ParseFailureKind kind) =>
          BackupState.failed(kind),
      };
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Backup restore failed', error, stackTrace);
      if (ref.mounted) {
        state = const BackupState.failed(ParseFailureKind.parseFailed);
      }
    }
  }

  /// Drops the preview without writing anything.
  void cancelPreview() => state = const BackupState.idle();
}
