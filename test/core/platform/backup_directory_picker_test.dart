import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_directory_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_directory_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// A plain [Exception] stand-in (the adapter catches `Exception`, not `Error`).
final class _DialogFailure implements Exception {
  const _DialogFailure();
}

void main() {
  group('UnsupportedBackupDirectoryPicker', () {
    test('pick_givenNoDialog_answersNothingPicked', () async {
      expect(
        (await const UnsupportedBackupDirectoryPicker().pick()).dataOrNull,
        isNull,
      );
    });
  });

  group('FileSelectorBackupDirectoryPicker', () {
    test('pick_givenAChosenFolder_answersItsPath', () async {
      final BackupDirectoryPicker picker = FileSelectorBackupDirectoryPicker(
        open: () async => '/storage/backups',
      );

      expect((await picker.pick()).dataOrNull, '/storage/backups');
    });

    test('pick_givenACancelledDialog_answersNull', () async {
      final BackupDirectoryPicker picker = FileSelectorBackupDirectoryPicker(
        open: () async => null,
      );

      expect((await picker.pick()).dataOrNull, isNull);
    });

    test('pick_givenADialogFailure_answersThePickMarker', () async {
      final BackupDirectoryPicker picker = FileSelectorBackupDirectoryPicker(
        open: () async => throw const _DialogFailure(),
      );

      final ParseResult<String?> result = await picker.pick();

      expect(result, isA<ParseFailure<String?>>());
      expect(
        (result as ParseFailure<String?>).rulePath,
        'backup.directory.pick',
      );
    });
  });
}
