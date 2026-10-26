import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/auto_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/save_backup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_backup_repository.dart';
import '../../../support/fake_backup_stores.dart';
import '../../../support/fake_clock.dart';

const BackupContents _contents = BackupContents(
  tables: <BackupTable, List<Map<String, Object?>>>{
    BackupTable.books: <Map<String, Object?>>[
      <String, Object?>{'sourceUrl': 's', 'bookUrl': 'b'},
    ],
  },
  preferences: <String, Object?>{},
);

void main() {
  group('BackupSettings', () {
    test('BackupSettings_givenRetentionOutOfRange_clampsIt', () {
      expect(BackupSettings(retention: 0).retention, minBackupRetention);
      expect(BackupSettings(retention: 99).retention, maxBackupRetention);
    });

    test('defaults_whenRead_areOffAndRetainFive', () {
      expect(BackupSettings.defaults.isAutoEnabled, isFalse);
      expect(BackupSettings.defaults.retention, defaultBackupRetention);
      expect(BackupSettings.defaults.location, isA<AppPrivateBackupLocation>());
      expect(BackupSettings.defaults.isWebDavConfigured, isFalse);
    });

    test('copyWith_givenEveryField_replacesThemAll', () {
      final BackupSettings next = BackupSettings.defaults.copyWith(
        isAutoEnabled: true,
        retention: 10,
        location: const FolderBackupLocation('/tmp'),
        hasPassword: true,
        webDavUrl: 'https://dav.test/backups',
        webDavUsername: 'u',
        hasWebDavPassword: true,
        lastAutoBackupAt: DateTime.utc(2026, 10, 25),
      );

      expect(next.isAutoEnabled, isTrue);
      expect(next.retention, 10);
      expect(next.location, const FolderBackupLocation('/tmp'));
      expect(next.hasPassword, isTrue);
      expect(next.isWebDavConfigured, isTrue);
      expect(next.hasWebDavPassword, isTrue);
      expect(next.lastAutoBackupAt, DateTime.utc(2026, 10, 25));
    });

    test('copyWith_givenNoInstant_keepsTheStoredOne', () {
      final BackupSettings next = BackupSettings(
        lastAutoBackupAt: DateTime.utc(2026),
      ).copyWith(retention: 7);

      expect(next.lastAutoBackupAt, DateTime.utc(2026));
      expect(next.retention, 7);
    });

    test('copyWith_givenANewInstant_replacesIt', () {
      final BackupSettings next = BackupSettings(
        lastAutoBackupAt: DateTime.utc(2026),
      ).copyWith(lastAutoBackupAt: DateTime.utc(2027));

      expect(next.lastAutoBackupAt, DateTime.utc(2027));
    });

    test('copyWith_givenClearLastAutoBackupAt_dropsTheInstant', () {
      final BackupSettings next = BackupSettings(
        lastAutoBackupAt: DateTime.utc(2026),
      ).copyWith(clearLastAutoBackupAt: true);

      expect(next.lastAutoBackupAt, isNull);
    });
  });

  group('backup names', () {
    test('backupNameFor_givenAPlainArchive_usesTheLocalDate', () {
      expect(
        backupNameFor(DateTime(2026, 1, 5, 23, 30), isEncrypted: false),
        'backup2026-01-05.zip',
      );
    });

    test('backupNameFor_givenAnEncryptedArchive_appendsTheSuffix', () {
      expect(
        backupNameFor(DateTime(2026, 1, 5), isEncrypted: true),
        'backup2026-01-05.zip.enc',
      );
    });

    test('safetyBackupNameFor_givenAnInstant_stampsSecondsAndSuffix', () {
      expect(
        safetyBackupNameFor(DateTime(2026, 1, 5, 7, 8, 9), isEncrypted: false),
        'backup-before-restore-20260105-070809.zip',
      );
      expect(
        safetyBackupNameFor(DateTime(2026, 1, 5, 7, 8, 9), isEncrypted: true),
        'backup-before-restore-20260105-070809.zip.enc',
      );
    });

    test('backupFilePattern_givenOurNames_matchesOnlyThose', () {
      expect(backupFilePattern.hasMatch('backup2026-10-25.zip'), isTrue);
      expect(backupFilePattern.hasMatch('backup2026-10-25.zip.enc'), isTrue);
      expect(
        backupFilePattern.hasMatch('backup-before-restore-20260105-070809.zip'),
        isTrue,
      );
      expect(backupFilePattern.hasMatch('report.zip'), isFalse);
      expect(backupFilePattern.hasMatch('backup2026-10-25.txt'), isFalse);
    });

    test('StoredBackup_pathAndEncryption_areDerivedFromTheName', () {
      final StoredBackup plain = StoredBackup(
        name: 'backup2026-10-25.zip',
        directory: '/tmp',
        sizeBytes: 3,
        modifiedAt: _epoch,
      );
      final StoredBackup encrypted = StoredBackup(
        name: 'backup2026-10-25.zip.enc',
        directory: '/tmp',
        sizeBytes: 3,
        modifiedAt: _epoch,
      );

      expect(plain.path, '/tmp/backup2026-10-25.zip');
      expect(plain.isEncrypted, isFalse);
      expect(encrypted.isEncrypted, isTrue);
      expect(
        RemoteBackup(
          name: 'backup2026-10-25.zip.enc',
          sizeBytes: 1,
          modifiedAt: _epoch,
        ).isEncrypted,
        isTrue,
      );
    });
  });

  group('SaveBackup', () {
    test('execute_givenAStoredPassword_encryptsAndPrunes', () async {
      final FakeBackupRepository repository = FakeBackupRepository(
        contents: _contents,
      );
      final FakeBackupSettingsRepository settings =
          FakeBackupSettingsRepository(
            password: 'secret',
            settings: BackupSettings(retention: 3),
          );
      final FakeLocalBackupStore store = FakeLocalBackupStore();

      final ParseResult<StoredBackup> saved = await SaveBackup(
        repository: repository,
        settings: settings,
        localStore: store,
        clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
        appVersion: '9.9.9',
      ).execute();

      final StoredBackup backup = (saved as ParseSuccess<StoredBackup>).data;
      expect(backup.name, 'backup2026-10-25.zip.enc');
      expect(store.lastKeep, 3);
      expect(store.pruneCount, 1);
    });

    test('execute_givenASafetyCopy_overridesTheNameAndKeeps', () async {
      final FakeLocalBackupStore store = FakeLocalBackupStore();

      final ParseResult<StoredBackup> saved = await SaveBackup(
        repository: FakeBackupRepository(contents: _contents),
        settings: FakeBackupSettingsRepository(),
        localStore: store,
        clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
        appVersion: '1',
      ).execute(isSafetyCopy: true, keep: 1);

      final StoredBackup backup = (saved as ParseSuccess<StoredBackup>).data;
      expect(backup.name, startsWith('backup-before-restore-'));
      expect(store.lastKeep, 1);
    });

    test('execute_givenAWriteFailure_answersTheWriteMarker', () async {
      final FakeLocalBackupStore store = FakeLocalBackupStore()
        ..failWrites = true;

      final ParseResult<StoredBackup> saved = await SaveBackup(
        repository: FakeBackupRepository(contents: _contents),
        settings: FakeBackupSettingsRepository(),
        localStore: store,
        clock: FakeClock(),
        appVersion: '1',
      ).execute();

      expect((saved as ParseFailure<StoredBackup>).rulePath, 'backup.write');
    });

    test('execute_givenAChosenLocation_writesThere', () async {
      final FakeLocalBackupStore store = FakeLocalBackupStore()
        ..directory = '/usb/backups';

      final ParseResult<StoredBackup> saved = await SaveBackup(
        repository: FakeBackupRepository(contents: _contents),
        settings: FakeBackupSettingsRepository(),
        localStore: store,
        clock: FakeClock(),
        appVersion: '1',
      ).execute(location: const FolderBackupLocation('/usb/backups'));

      expect(
        (saved as ParseSuccess<StoredBackup>).data.directory,
        '/usb/backups',
      );
    });
  });

  group('AutoBackup', () {
    late FakeBackupRepository repository;
    late FakeBackupSettingsRepository settings;
    late FakeLocalBackupStore store;

    SaveBackup saveBackup() => SaveBackup(
      repository: repository,
      settings: settings,
      localStore: store,
      clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
      appVersion: '1',
    );

    setUp(() {
      repository = FakeBackupRepository(contents: _contents);
      settings = FakeBackupSettingsRepository();
      store = FakeLocalBackupStore();
    });

    test('execute_givenTheSwitchOff_doesNothing', () async {
      final ParseResult<StoredBackup?> result = await AutoBackup(
        settings: settings,
        saveBackup: saveBackup(),
        clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
      ).execute();

      expect(result, isA<ParseSuccess<StoredBackup?>>());
      expect(result.dataOrNull, isNull);
      expect(store.files, isEmpty);
    });

    test('execute_givenARecentBackup_skips', () async {
      settings = FakeBackupSettingsRepository(
        settings: BackupSettings(
          isAutoEnabled: true,
          lastAutoBackupAt: DateTime.utc(2026, 10, 25, 1),
        ),
      );

      final ParseResult<StoredBackup?> result = await AutoBackup(
        settings: settings,
        saveBackup: saveBackup(),
        clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
      ).execute();

      expect(result.dataOrNull, isNull);
      expect(store.files, isEmpty);
    });

    test('execute_givenNoRecentBackup_writesOneAndStampsTheTime', () async {
      settings = FakeBackupSettingsRepository(
        settings: BackupSettings(isAutoEnabled: true),
      );

      final ParseResult<StoredBackup?> result = await AutoBackup(
        settings: settings,
        saveBackup: saveBackup(),
        clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
      ).execute();

      expect(result.dataOrNull, isNotNull);
      expect(store.files, hasLength(1));
      expect(
        settings.settings.lastAutoBackupAt,
        DateTime.utc(2026, 10, 25, 12),
      );
    });

    test('execute_givenAFailingWrite_doesNotStampAndReports', () async {
      settings = FakeBackupSettingsRepository(
        settings: BackupSettings(isAutoEnabled: true),
      );
      store.failWrites = true;

      final ParseResult<StoredBackup?> result = await AutoBackup(
        settings: settings,
        saveBackup: saveBackup(),
        clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
      ).execute();

      expect(result, isA<ParseFailure<StoredBackup?>>());
      // 时间戳只在写成功后前进：下次启动会重试，而不是等一整天。
      expect(settings.settings.lastAutoBackupAt, isNull);
    });
  });

  group('passwordForArchive', () {
    test('passwordForArchive_givenATypedPassword_prefersIt', () async {
      expect(
        await passwordForArchive(
          settings: FakeBackupSettingsRepository(password: 'stored'),
          typed: 'typed',
        ),
        'typed',
      );
    });

    test('passwordForArchive_givenNoTypedPassword_usesTheStoredOne', () async {
      expect(
        await passwordForArchive(
          settings: FakeBackupSettingsRepository(password: 'stored'),
        ),
        'stored',
      );
    });

    test(
      'passwordForArchive_givenAnEmptyTypedPassword_usesTheStoredOne',
      () async {
        expect(
          await passwordForArchive(
            settings: FakeBackupSettingsRepository(password: 'stored'),
            typed: '',
          ),
          'stored',
        );
      },
    );
  });
}

final DateTime _epoch = DateTime.utc(1970);
