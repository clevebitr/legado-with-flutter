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
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/domain/repositories/restore_completion_hook.dart';
import 'package:flutter_reader/features/backup/domain/usecases/create_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/inspect_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/restore_backup.dart';
import 'package:flutter_reader/features/backup/presentation/pages/backup_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_backup_repository.dart';
import '../../../../support/fake_clock.dart';

/// One row in two tables: enough that the preview has something to count.
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

/// A plugin-free hook for the restore use case.
final class _CountingHook implements RestoreCompletionHook {
  int calls = 0;

  @override
  void onRestored() => calls += 1;
}

/// Pumps the page with a working export path and a picker answering [selection].
Future<void> _pump(
  WidgetTester tester, {
  required bool saved,
  BackupArchiveSelection? selection,
  _CountingHook? hook,
}) async {
  final FakeBackupRepository repository = FakeBackupRepository(
    contents: _contents,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appLoggerProvider.overrideWithValue(AppLogger()),
        createBackupProvider.overrideWith(
          (Ref ref) async => CreateBackup(
            repository: repository,
            clock: FakeClock(start: DateTime.utc(2026, 10, 25, 12)),
            appVersion: '9.9.9',
          ),
        ),
        backupRepositoryProvider.overrideWith((Ref ref) async => repository),
        inspectBackupProvider.overrideWithValue(const InspectBackup()),
        restoreBackupProvider.overrideWith(
          (Ref ref) async => RestoreBackup(
            repository: repository,
            completionHook: hook ?? _CountingHook(),
          ),
        ),
        backupArchiveSaverProvider.overrideWithValue(
          FileSelectorBackupArchiveSaver(
            write: ({
              required String suggestedName,
              required List<int> bytes,
            }) async => saved ? '/tmp/$suggestedName' : null,
          ),
        ),
        backupArchivePickerProvider.overrideWithValue(
          FileSelectorBackupArchivePicker(
            opener: ({required int maxBytes}) async => selection,
          ),
        ),
      ],
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

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(BackupPage)));

/// The archive one export produces, for the restore side of the page.
List<int> _archiveBytes() => encodeBackupArchive(
  _contents,
  createdAt: DateTime.utc(2026, 10, 25, 12),
  appVersion: '9.9.9',
);

/// Taps [label], then waits for the action to finish.
///
/// The use cases compress and decompress **in another isolate** (C-PERF-4), and the fake clock of
/// `pumpAndSettle` cannot deliver that message; `runAsync` is what gives the test real event-loop
/// turns. The loop stops as soon as the progress indicator is gone, so the 50 ms cap is only a guard.
Future<void> _tapAndWait(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
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
  group('BackupPage', () {
    testWidgets('build_givenIdle_showsBothActionsAndThePlaintextHint', (
      WidgetTester tester,
    ) async {
      await _pump(tester, saved: true);
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.backupTitle), findsOneWidget);
      expect(find.text(l10n.backupExportTitle), findsOneWidget);
      expect(find.text(l10n.backupRestoreTitle), findsOneWidget);
      // 备份是明文且含登录信息，这一点必须在动作旁边说清楚（ADR-0073 §决策 1）。
      expect(find.text(l10n.backupIncludeSecretsHint), findsOneWidget);
    });

    testWidgets('export_givenASavedArchive_reportsItsNameAndRowCount', (
      WidgetTester tester,
    ) async {
      await _pump(tester, saved: true);
      final AppLocalizations l10n = _l10n(tester);

      await _tapAndWait(tester, l10n.backupExportTitle);

      expect(
        find.text(l10n.backupExported('backup2026-10-25.zip', 2)),
        findsOneWidget,
      );
    });

    testWidgets('export_givenACancelledDialog_staysSilent', (
      WidgetTester tester,
    ) async {
      await _pump(tester, saved: false);
      final AppLocalizations l10n = _l10n(tester);

      await _tapAndWait(tester, l10n.backupExportTitle);

      // 取消不是失败：既没有回执也没有错误。
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('backup2026'), findsNothing);
    });

    testWidgets('restore_givenACancelledDialog_staysSilent', (
      WidgetTester tester,
    ) async {
      await _pump(tester, saved: true);
      final AppLocalizations l10n = _l10n(tester);

      await _tapAndWait(tester, l10n.backupRestoreTitle);

      expect(find.text(l10n.backupPreviewTitle), findsNothing);
    });

    testWidgets('restore_givenAValidArchive_showsThePreviewThenMerges', (
      WidgetTester tester,
    ) async {
      final _CountingHook hook = _CountingHook();
      await _pump(
        tester,
        saved: true,
        hook: hook,
        selection: PickedBackupArchive(
          name: 'backup2026-10-25.zip',
          bytes: _archiveBytes(),
        ),
      );
      final AppLocalizations l10n = _l10n(tester);

      await _tapAndWait(tester, l10n.backupRestoreTitle);

      expect(find.text(l10n.backupPreviewTitle), findsOneWidget);
      expect(find.text(l10n.backupTableBookSources), findsOneWidget);
      expect(find.text(l10n.backupPreviewPreferences(1)), findsOneWidget);

      await _tapAndWait(tester, l10n.backupConfirmRestore);

      expect(find.text(l10n.backupPreviewTitle), findsNothing);
      expect(find.textContaining('Merged'), findsOneWidget);
      expect(hook.calls, 1);
    });

    testWidgets('restore_givenAnOversizedArchive_reportsTheSizeLimit', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        saved: true,
        // 不用 const：const 构造会在编译期折叠，core 层的构造行就没有执行点（ADR-0019）。
        // ignore: prefer_const_constructors
        selection: OversizedBackupArchive(name: 'huge.zip', length: 1),
      );
      final AppLocalizations l10n = _l10n(tester);

      await _tapAndWait(tester, l10n.backupRestoreTitle);

      expect(find.text(l10n.failureParseFailed), findsOneWidget);
    });

    testWidgets('preview_givenCancelButton_dropsThePreview', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        saved: true,
        selection: PickedBackupArchive(
          name: 'backup2026-10-25.zip',
          bytes: _archiveBytes(),
        ),
      );
      final AppLocalizations l10n = _l10n(tester);

      await _tapAndWait(tester, l10n.backupRestoreTitle);
      await _tapAndWait(tester, l10n.actionCancel);

      expect(find.text(l10n.backupPreviewTitle), findsNothing);
    });
  });
}
