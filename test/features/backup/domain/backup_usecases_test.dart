import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/backup/domain/backup_archive_codec.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_restore_report.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/domain/entities/restore_mode.dart';
import 'package:flutter_reader/features/backup/domain/repositories/restore_completion_hook.dart';
import 'package:flutter_reader/features/backup/domain/usecases/create_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/inspect_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/restore_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/save_backup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_backup_repository.dart';
import '../../../support/fake_backup_stores.dart';
import '../../../support/fake_clock.dart';
import '../../../support/fake_log_printer.dart';

const BackupContents _contents = BackupContents(
  tables: <BackupTable, List<Map<String, Object?>>>{
    BackupTable.bookSources: <Map<String, Object?>>[
      <String, Object?>{'url': 'https://a.example', 'fingerprint': 'abc'},
    ],
    BackupTable.books: <Map<String, Object?>>[
      <String, Object?>{'sourceUrl': 'https://a.example', 'bookUrl': 'b'},
      <String, Object?>{'sourceUrl': 'https://a.example', 'bookUrl': 'c'},
    ],
  },
  preferences: <String, Object?>{'settings.themeMode': 0},
);

final class _RecordingHook implements RestoreCompletionHook {
  int calls = 0;

  @override
  void onRestored() => calls += 1;
}

void main() {
  group('CreateBackup', () {
    test('execute_givenStoredRows_answersAnArchiveThatDecodesBack', () async {
      final FakeBackupRepository repository = FakeBackupRepository(
        contents: _contents,
      );
      final DateTime now = DateTime.utc(2026, 10, 25, 12, 30);

      final BackupArchive archive = await CreateBackup(
        repository: repository,
        clock: FakeClock(start: now),
        appVersion: '9.9.9',
      ).execute();

      final ParseResult<BackupSnapshot> decoded = decodeBackupArchive(
        archive.bytes,
      );
      final BackupSnapshot snapshot =
          (decoded as ParseSuccess<BackupSnapshot>).data;
      expect(snapshot.manifest.appVersion, '9.9.9');
      expect(snapshot.manifest.createdAt, DateTime.utc(2026, 10, 25, 12, 30));
      // decode 会把备份里的每一张表都填上（空表也是空数组），所以逐表比对携带的行。
      expect(
        snapshot.contents.tables[BackupTable.books],
        _contents.tables[BackupTable.books],
      );
      expect(
        snapshot.contents.tables[BackupTable.bookSources],
        _contents.tables[BackupTable.bookSources],
      );
      expect(snapshot.contents.tables[BackupTable.rules], isEmpty);
      expect(snapshot.contents.preferences, _contents.preferences);
    });

    test('execute_givenAStoredTable_reportsItsRowCounts', () async {
      final BackupArchive archive = await CreateBackup(
        repository: FakeBackupRepository(contents: _contents),
        clock: FakeClock(start: DateTime.utc(2026, 10, 25)),
        appVersion: '1',
      ).execute();

      expect(archive.counts[BackupTable.books], 2);
      expect(archive.counts[BackupTable.bookSources], 1);
      expect(archive.counts[BackupTable.rules], 0);
      expect(archive.createdAt, DateTime.utc(2026, 10, 25));
    });
  });

  group('backupFileNameFor', () {
    test('backupFileNameFor_givenAOneDigitMonthAndDay_padsBoth', () {
      expect(
        backupFileNameFor(DateTime(2026, 1, 5, 23, 30)),
        'backup2026-01-05.zip',
      );
    });

    test('backupFileNameFor_givenAUtcInstant_usesLocalTime', () {
      // 用本地时区构造再转 UTC：文件名必须按用户看到的日期，而不是 UTC 的日期。
      final DateTime local = DateTime(2026, 12, 31, 23, 30);

      expect(backupFileNameFor(local.toUtc()), 'backup2026-12-31.zip');
    });
  });

  group('InspectBackup', () {
    test('execute_givenAValidArchive_answersItsManifestAndCounts', () async {
      final BackupArchive archive = await CreateBackup(
        repository: FakeBackupRepository(contents: _contents),
        clock: FakeClock(start: DateTime.utc(2026, 10, 25)),
        appVersion: '9.9.9',
      ).execute();

      final ParseResult<BackupPreview> preview = await const InspectBackup()
          .execute(bytes: archive.bytes);

      final BackupPreview data = (preview as ParseSuccess<BackupPreview>).data;
      expect(data.createdAt, DateTime.utc(2026, 10, 25));
      expect(data.appVersion, '9.9.9');
      expect(data.counts[BackupTable.books], 2);
      expect(data.preferenceCount, 1);
      expect(data.totalRows, 3);
    });

    test('execute_givenGarbage_answersTheDecodersFailure', () async {
      final ParseResult<BackupPreview> preview = await const InspectBackup()
          .execute(bytes: <int>[1, 2, 3]);

      final ParseFailure<BackupPreview> failure =
          preview as ParseFailure<BackupPreview>;
      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'backup.read.manifest');
    });
  });

  group('RestoreBackup', () {
    /// Builds the use case over fakes; [settings] carries the password the restore should try.
    RestoreBackup restoreBackup({
      required FakeBackupRepository repository,
      required _RecordingHook hook,
      FakeBackupSettingsRepository? settings,
      bool failSafetyCopy = false,
    }) {
      final FakeBackupSettingsRepository resolved =
          settings ?? FakeBackupSettingsRepository();
      final FakeLocalBackupStore store = FakeLocalBackupStore()
        ..failWrites = failSafetyCopy;

      return RestoreBackup(
        repository: repository,
        completionHook: hook,
        settings: resolved,
        saveBackup: SaveBackup(
          repository: repository,
          settings: resolved,
          localStore: store,
          clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
          appVersion: '1',
        ),
      );
    }

    Future<List<int>> archiveBytes() async => (await CreateBackup(
      repository: FakeBackupRepository(contents: _contents),
      clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
      appVersion: '1',
    ).execute()).bytes;

    test('execute_givenAValidArchive_mergesItAndNotifiesTheHook', () async {
      final List<int> bytes = await archiveBytes();
      final FakeBackupRepository repository = FakeBackupRepository(
        contents: FakeBackupRepository.emptyContents,
        report: reportWith(changed: 2, preferences: 1),
      );
      final _RecordingHook hook = _RecordingHook();

      final ParseResult<RestoreOutcome> result = await restoreBackup(
        repository: repository,
        hook: hook,
      ).execute(bytes: bytes);

      final RestoreOutcome outcome =
          (result as ParseSuccess<RestoreOutcome>).data;
      expect(outcome.report.changedRows, 2);
      expect(outcome.safetyCopy, isNull);
      expect(repository.restoredMode, RestoreMode.merge);
      expect(
        repository.restoredContents?.tables[BackupTable.books],
        hasLength(2),
      );
      expect(hook.calls, 1);
    });

    test('execute_givenOverwrite_writesASafetyCopyFirst', () async {
      final List<int> bytes = await archiveBytes();
      final FakeBackupRepository repository = FakeBackupRepository(
        contents: FakeBackupRepository.emptyContents,
      );

      final ParseResult<RestoreOutcome> result = await restoreBackup(
        repository: repository,
        hook: _RecordingHook(),
      ).execute(bytes: bytes, mode: RestoreMode.overwrite);

      final RestoreOutcome outcome =
          (result as ParseSuccess<RestoreOutcome>).data;
      expect(outcome.safetyCopy?.name, startsWith('backup-before-restore-'));
      expect(repository.restoredMode, RestoreMode.overwrite);
    });

    test('execute_givenAFailingSafetyCopy_doesNotRestore', () async {
      final List<int> bytes = await archiveBytes();
      final FakeBackupRepository repository = FakeBackupRepository(
        contents: FakeBackupRepository.emptyContents,
      );
      final _RecordingHook hook = _RecordingHook();

      final ParseResult<RestoreOutcome> result = await restoreBackup(
        repository: repository,
        hook: hook,
        failSafetyCopy: true,
      ).execute(bytes: bytes, mode: RestoreMode.overwrite);

      // 覆盖不可逆：安全副本写不出来就不覆盖（ADR-0074 §决策 3）。
      expect((result as ParseFailure<RestoreOutcome>).rulePath, 'backup.write');
      expect(repository.restoredContents, isNull);
      expect(hook.calls, 0);
    });

    test('execute_givenGarbage_doesNotTouchTheDatabaseNorTheHook', () async {
      final FakeBackupRepository repository = FakeBackupRepository(
        contents: FakeBackupRepository.emptyContents,
      );
      final _RecordingHook hook = _RecordingHook();

      final ParseResult<RestoreOutcome> result = await restoreBackup(
        repository: repository,
        hook: hook,
      ).execute(bytes: <int>[1, 2, 3]);

      expect(result, isA<ParseFailure<RestoreOutcome>>());
      expect(repository.restoredContents, isNull);
      expect(hook.calls, 0);
    });

    test(
      'execute_givenAnEncryptedArchiveWithoutAPassword_asksForOne',
      () async {
        final List<int> bytes = (await CreateBackup(
          repository: FakeBackupRepository(contents: _contents),
          clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
          appVersion: '1',
        ).execute(password: 'secret')).bytes;

        final ParseResult<RestoreOutcome> result = await restoreBackup(
          repository: FakeBackupRepository(
            contents: FakeBackupRepository.emptyContents,
          ),
          hook: _RecordingHook(),
        ).execute(bytes: bytes);

        expect(
          (result as ParseFailure<RestoreOutcome>).rulePath,
          'backup.read.passwordRequired',
        );
      },
    );

    test(
      'execute_givenAnEncryptedArchiveWithTheStoredPassword_restores',
      () async {
        final List<int> bytes = (await CreateBackup(
          repository: FakeBackupRepository(contents: _contents),
          clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
          appVersion: '1',
        ).execute(password: 'secret')).bytes;

        final ParseResult<RestoreOutcome> result = await restoreBackup(
          repository: FakeBackupRepository(
            contents: FakeBackupRepository.emptyContents,
          ),
          hook: _RecordingHook(),
          settings: FakeBackupSettingsRepository(password: 'secret'),
        ).execute(bytes: bytes);

        expect(result, isA<ParseSuccess<RestoreOutcome>>());
      },
    );
  });

  group('report entities', () {
    test('BackupTableOutcome_total_sumsEveryBucket', () {
      const BackupTableOutcome outcome = BackupTableOutcome(
        inserted: 1,
        updated: 2,
        skipped: 3,
      );

      expect(outcome.total, 6);
    });

    test('BackupRestoreReport_changedRows_ignoresSkippedRows', () {
      const BackupRestoreReport report = BackupRestoreReport(
        outcomes: <BackupTable, BackupTableOutcome>{
          BackupTable.books: BackupTableOutcome(inserted: 2, skipped: 5),
          BackupTable.rules: BackupTableOutcome(updated: 1),
        },
        preferencesWritten: 4,
      );

      expect(report.changedRows, 3);
    });
  });

  group('UnboundRestoreCompletionHook', () {
    test('onRestored_givenNoBinding_logsAWarning', () {
      final FakeLogPrinter printer = FakeLogPrinter();

      UnboundRestoreCompletionHook(logger: AppLogger(printer: printer))
          .onRestored();

      expect(printer.events.map((event) => event.level.name), <String>[
        'warning',
      ]);
    });
  });
}
