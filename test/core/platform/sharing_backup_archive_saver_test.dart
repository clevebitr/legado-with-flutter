import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/file_sharer.dart';
import 'package:flutter_reader/core/platform/sharing_backup_archive_saver.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [FileSharer] that records what the saver handed over.
final class _RecordingFileSharer implements FileSharer {
  _RecordingFileSharer({this.isSupported = true, this.failure});

  @override
  final bool isSupported;

  final ParseFailure<bool>? failure;

  final List<ShareableFile> shared = <ShareableFile>[];
  bool called = false;

  @override
  Future<ParseResult<bool>> share(
    List<ShareableFile> files, {
    String? subject,
  }) async {
    called = true;
    shared.addAll(files);
    final ParseFailure<bool>? error = failure;
    if (error != null) {
      return error;
    }

    return const ParseSuccess<bool>(true);
  }
}

void main() {
  test('save_givenASupportedSharer_handsTheZipWithItsName', () async {
    final _RecordingFileSharer sharer = _RecordingFileSharer();
    final SharingBackupArchiveSaver saver = SharingBackupArchiveSaver(
      sharer: sharer,
    );

    final ParseResult<bool> saved = await saver.save(
      suggestedName: 'backup2026-10-27.zip',
      bytes: <int>[80, 75, 3, 4],
    );

    expect((saved as ParseSuccess<bool>).data, isTrue);
    expect(sharer.called, isTrue);
    final ShareableFile file = sharer.shared.single;
    expect(file.name, 'backup2026-10-27.zip');
    expect(file.mimeType, 'application/zip');
    expect(file.bytes, <int>[80, 75, 3, 4]);
  });

  test('save_givenNoShareSheet_answersNotSavedWithoutCallingIt', () async {
    final _RecordingFileSharer sharer = _RecordingFileSharer(
      isSupported: false,
    );
    final SharingBackupArchiveSaver saver = SharingBackupArchiveSaver(
      sharer: sharer,
    );

    final ParseResult<bool> saved = await saver.save(
      suggestedName: 'backup.zip',
      bytes: <int>[1],
    );

    expect((saved as ParseSuccess<bool>).data, isFalse);
    expect(sharer.called, isFalse);
  });

  test('save_givenTheSharerFails_returnsItsFailure', () async {
    const ParseFailure<bool> failure = ParseFailure<bool>(
      kind: ParseFailureKind.parseFailed,
      rulePath: 'share',
    );
    final SharingBackupArchiveSaver saver = SharingBackupArchiveSaver(
      sharer: _RecordingFileSharer(failure: failure),
    );

    final ParseResult<bool> saved = await saver.save(
      suggestedName: 'backup.zip',
      bytes: <int>[1],
    );

    expect(saved, failure);
  });
}
