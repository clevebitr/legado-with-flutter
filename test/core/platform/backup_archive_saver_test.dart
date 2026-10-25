import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_saver.dart';
import 'package:flutter_test/flutter_test.dart';

/// A plain [Exception] stand-in (the adapter catches `Exception`, not `Error`).
final class _WriteFailure implements Exception {
  const _WriteFailure();
}

void main() {
  group('UnsupportedBackupArchiveSaver', () {
    test('save_givenNoDialog_answersNotSaved', () async {
      // platform.md §2：没有保存对话框的平台 = 用户取消，不是失败。
      final ParseResult<bool> saved =
          await const UnsupportedBackupArchiveSaver().save(
            suggestedName: 'backup2026-10-25.zip',
            bytes: <int>[1, 2, 3],
          );

      expect((saved as ParseSuccess<bool>).data, isFalse);
    });
  });

  group('FileSelectorBackupArchiveSaver', () {
    test('save_givenAChosenPath_answersSaved', () async {
      String? writtenName;
      List<int>? writtenBytes;
      final BackupArchiveSaver saver = FileSelectorBackupArchiveSaver(
        write:
            ({required String suggestedName, required List<int> bytes}) async {
              writtenName = suggestedName;
              writtenBytes = bytes;

              return '/tmp/$suggestedName';
            },
      );

      final ParseResult<bool> saved = await saver.save(
        suggestedName: 'backup2026-10-25.zip',
        bytes: <int>[80, 75, 3, 4],
      );

      expect((saved as ParseSuccess<bool>).data, isTrue);
      expect(writtenName, 'backup2026-10-25.zip');
      expect(writtenBytes, <int>[80, 75, 3, 4]);
    });

    test('save_givenACancelledDialog_answersNotSaved', () async {
      final BackupArchiveSaver saver = FileSelectorBackupArchiveSaver(
        write: ({
          required String suggestedName,
          required List<int> bytes,
        }) async => null,
      );

      final ParseResult<bool> saved = await saver.save(
        suggestedName: 'backup2026-10-25.zip',
        bytes: <int>[1],
      );

      expect((saved as ParseSuccess<bool>).data, isFalse);
    });

    test('save_givenAWriteFailure_answersTheBackupWriteMarker', () async {
      final BackupArchiveSaver saver = FileSelectorBackupArchiveSaver(
        write: ({
          required String suggestedName,
          required List<int> bytes,
        }) async => throw const _WriteFailure(),
      );

      final ParseResult<bool> saved = await saver.save(
        suggestedName: 'backup2026-10-25.zip',
        bytes: <int>[1],
      );

      expect(saved, isA<ParseFailure<bool>>());
      expect((saved as ParseFailure<bool>).rulePath, 'backup.write');
    });
  });
}
