import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a picker whose dialog answers [selection] (or nothing, when it is `null`).
FileSelectorBackupArchivePicker _pickerReturning(
  BackupArchiveSelection? selection,
) => FileSelectorBackupArchivePicker(
  opener: ({required int maxBytes}) async => selection,
);

void main() {
  group('UnsupportedBackupArchivePicker', () {
    test('pick_givenAPlatformWithoutADialog_answersNothingPicked', () async {
      // platform.md §2 的契约：不支持的平台返回 null/no-op，禁止抛异常。
      final ParseResult<PickedBackupArchive?> result =
          await const UnsupportedBackupArchivePicker().pick(maxBytes: 1024);

      expect(result.dataOrNull, isNull);
    });
  });

  group('FileSelectorBackupArchivePicker', () {
    test('pick_givenACancelledDialog_answersNothingPicked', () async {
      final ParseResult<PickedBackupArchive?> result = await _pickerReturning(
        null,
      ).pick(maxBytes: 1024);

      expect(result.dataOrNull, isNull);
    });

    test('pick_givenAnArchiveWithinTheCap_returnsIt', () async {
      final ParseResult<PickedBackupArchive?> result = await _pickerReturning(
        const PickedBackupArchive(
          name: 'backup2026-10-25.zip',
          bytes: <int>[80, 75],
        ),
      ).pick(maxBytes: 1024);

      expect(result.dataOrNull?.name, 'backup2026-10-25.zip');
      expect(result.dataOrNull?.bytes, <int>[80, 75]);
    });

    test('pick_givenAnOversizedArchive_answersTheSizeLimitMarker', () async {
      // 超限不是取消：用户要知道为什么文件没被读（对话框在读取前就拒了它）。
      final ParseResult<PickedBackupArchive?> result = await _pickerReturning(
        const OversizedBackupArchive(name: 'huge.zip', length: 2048),
      ).pick(maxBytes: 1024);

      expect(result, isA<ParseFailure<PickedBackupArchive?>>());
      expect(
        (result as ParseFailure<PickedBackupArchive?>).rulePath,
        'backup.read.sizeLimit',
      );
    });
  });
}
