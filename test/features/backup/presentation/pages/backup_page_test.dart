import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_saver.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/backup/di.dart';
import 'package:flutter_reader/features/backup/domain/backup_archive_codec.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/repositories/restore_completion_hook.dart';
import 'package:flutter_reader/features/backup/domain/usecases/create_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/inspect_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/restore_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/save_backup.dart';
import 'package:flutter_reader/features/backup/presentation/pages/backup_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_backup_repository.dart';
import '../../../../support/fake_backup_stores.dart';
import '../../../../support/fake_clock.dart';

const BackupContents _contents = BackupContents(
  tables: <BackupTable, List<Map<String, Object?>>>{
    BackupTable.bookSources: <Map<String, Object?>>[
      <String, Object?>{'url': 'https://a.example', 'fingerprint': 'fp'},
    ],
    BackupTable.books: <Map<String, Object?>>[
      <String, Object?>{'sourceUrl': 'https://a.example', 'bookUrl': 'b'},
    ],
  },
  preferences: <String, Object?>{'settings.fontScale': 1.2},
);

final class _CountingHook implements RestoreCompletionHook {
  int calls = 0;

  @override
  void onRestored() => calls += 1;
}

/// The fakes one page test works with, so assertions can look at them afterwards.
final class _Harness {
  _Harness({
    BackupSettings settings = BackupSettings.defaults,
    this.password,
    this.selection,
    this.remoteBackups = const <RemoteBackup>[],
  }) : settingsRepository = FakeBackupSettingsRepository(
         settings: settings,
         password: password,
       );

  final String? password;
  final BackupArchiveSelection? selection;
  final List<RemoteBackup> remoteBackups;
  final FakeBackupSettingsRepository settingsRepository;
  final FakeBackupRepository repository = FakeBackupRepository(
    contents: _contents,
  );
  final FakeBackupSettingsRepository saveSettings =
      FakeBackupSettingsRepository();
  final FakeLocalBackupStore localStore = FakeLocalBackupStore();
  final _CountingHook hook = _CountingHook();

  late final FakeRemoteBackupStore remoteStore = FakeRemoteBackupStore(
    backups: remoteBackups,
  );

  /// Overrides that replace every platform dialog and every database access.
  List<Override> get overrides => <Override>[
    appLoggerProvider.overrideWithValue(AppLogger()),
    backupSettingsRepositoryProvider.overrideWith((Ref ref) async {
      // 读数与写口令走同一个 fake：控制器保存后页面立刻能看到新状态。
      return settingsRepository;
    }),
    backupRepositoryProvider.overrideWith((Ref ref) async => repository),
    localBackupStoreProvider.overrideWithValue(localStore),
    remoteBackupStoreProvider.overrideWith((Ref ref) async => remoteStore),
    createBackupProvider.overrideWith(
      (Ref ref) async => CreateBackup(
        repository: repository,
        clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
        appVersion: '9.9.9',
      ),
    ),
    saveBackupProvider.overrideWith(
      (Ref ref) async => SaveBackup(
        repository: repository,
        settings: settingsRepository,
        localStore: localStore,
        clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
        appVersion: '9.9.9',
      ),
    ),
    inspectBackupProvider.overrideWithValue(const InspectBackup()),
    restoreBackupProvider.overrideWith(
      (Ref ref) async => RestoreBackup(
        repository: repository,
        completionHook: hook,
        settings: settingsRepository,
        saveBackup: SaveBackup(
          repository: repository,
          settings: saveSettings,
          localStore: localStore,
          clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
          appVersion: '9.9.9',
        ),
      ),
    ),
    backupArchiveSaverProvider.overrideWithValue(
      FileSelectorBackupArchiveSaver(
        write: ({
          required String suggestedName,
          required List<int> bytes,
        }) async => '/tmp/$suggestedName',
      ),
    ),
    backupArchivePickerProvider.overrideWithValue(
      FileSelectorBackupArchivePicker(
        opener: ({required int maxBytes}) async => selection,
      ),
    ),
  ];

  /// The bytes of an archive written from [_contents].
  List<int> archiveBytes({String? password}) => encodeBackupArchive(
    _contents,
    createdAt: DateTime.utc(2026, 10, 25, 12),
    appVersion: '9.9.9',
    password: password,
  );
}

Future<void> _pump(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: harness.overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const BackupPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(BackupPage)));

/// One archive picked through the file dialog.
BackupArchiveSelection _picked(BackupContents contents, {String? password}) =>
    PickedBackupArchive(
      name: 'backup2026-10-25.zip',
      bytes: encodeBackupArchive(
        contents,
        createdAt: DateTime.utc(2026, 10, 25, 12),
        appVersion: '9.9.9',
        password: password,
      ),
    );

/// Scrolls the page down until [finder] is built (the list is lazy).
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();

      return;
    }
    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pumpAndSettle();
  }

  fail('The widget never appeared while scrolling.');
}

/// Taps [finder], then waits for the action to finish.
///
/// The use cases compress and decompress **in another isolate** (C-PERF-4), and `pumpAndSettle`'s
/// fake clock cannot deliver that message; `runAsync` gives the test real event-loop turns.
Future<void> _tapAndWait(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();

  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty) {
      return;
    }
  }

  fail('The action did not finish within the test budget.');
}

void main() {
  testWidgets('build_givenDefaults_showsEverySection', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _Harness());
    final AppLocalizations l10n = _l10n(tester);

    expect(find.text(l10n.backupTitle), findsOneWidget);
    expect(find.text(l10n.backupAutoTitle), findsWidgets);
    expect(find.text(l10n.backupLocationTitle), findsOneWidget);
    expect(find.text(l10n.backupPasswordTitle), findsOneWidget);
    // 备份是明文且含登录信息，这一点必须在动作旁边说清楚（ADR-0073 §决策 1）。
    expect(find.text(l10n.backupIncludeSecretsHint), findsWidgets);

    for (final String label in <String>[
      l10n.backupSaveToLocation,
      l10n.backupRestoreFromFile,
      l10n.backupWebDavTitle,
    ]) {
      final Finder finder = find.text(label);
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
      }
      expect(finder, findsWidgets);
    }
  });

  testWidgets('saveToLocation_givenABackupLocation_reportsThePath', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(
      settings: BackupSettings(location: const AppPrivateBackupLocation()),
    );
    await _pump(tester, harness);
    final AppLocalizations l10n = _l10n(tester);

    await _tapAndWait(tester, find.text(l10n.backupSaveToLocation));

    expect(
      find.text(l10n.backupSavedTo('/tmp/backups/backup2026-10-25.zip')),
      findsOneWidget,
    );
    expect(harness.localStore.files, hasLength(1));
  });

  testWidgets('restore_givenAValidArchive_mergesAfterConfirmation', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(selection: _picked(_contents));
    await _pump(tester, harness);
    final AppLocalizations l10n = _l10n(tester);

    await _tapAndWait(tester, find.text(l10n.backupRestoreFromFile));

    expect(find.text(l10n.backupPreviewTitle), findsOneWidget);
    expect(find.text(l10n.backupTableBooks), findsOneWidget);

    await _tapAndWait(tester, find.text(l10n.backupMergeMode));

    await _reveal(tester, find.textContaining('Merged'));
    expect(find.textContaining('Merged'), findsOneWidget);
    expect(harness.hook.calls, 1);
  });

  testWidgets('restore_givenOverwrite_asksForConfirmationFirst', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _Harness(selection: _picked(_contents)));
    final AppLocalizations l10n = _l10n(tester);

    await _tapAndWait(tester, find.text(l10n.backupRestoreFromFile));
    await _tapAndWait(tester, find.text(l10n.backupOverwriteMode));

    // 覆盖是不可逆动作：先问一次（ADR-0074 §决策 3）。
    expect(find.text(l10n.backupOverwriteWarning), findsWidgets);
    await _tapAndWait(tester, find.text(l10n.backupOverwriteConfirm));

    await _reveal(tester, find.textContaining('Merged'));
    expect(find.textContaining('Merged'), findsOneWidget);
  });

  testWidgets('restore_givenAnEncryptedArchive_asksForThePassword', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _Harness(selection: _picked(_contents, password: 'secret')),
    );
    final AppLocalizations l10n = _l10n(tester);

    await _tapAndWait(tester, find.text(l10n.backupRestoreFromFile));

    expect(find.text(l10n.backupPasswordRequired), findsOneWidget);
    expect(find.text(l10n.backupPasswordPrompt), findsOneWidget);
  });

  testWidgets('remoteList_givenArchives_showsThemForRestore', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _Harness(
        remoteBackups: <RemoteBackup>[
          RemoteBackup(
            name: 'backup2026-10-25.zip',
            sizeBytes: 2048,
            modifiedAt: DateTime.utc(2026, 10, 25),
          ),
        ],
      ),
    );
    final AppLocalizations l10n = _l10n(tester);

    await _tapAndWait(tester, find.text(l10n.backupCloudRefresh));

    await _reveal(tester, find.text('backup2026-10-25.zip'));
    expect(find.text('backup2026-10-25.zip'), findsOneWidget);
    expect(find.byTooltip(l10n.backupRemoteRestore), findsOneWidget);
  });
}
