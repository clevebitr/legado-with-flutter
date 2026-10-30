import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/file_sharer.dart';
import 'package:flutter_reader/core/platform/sharing_json_file_saver.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [FileSharer] that records what the saver handed over.
final class _RecordingFileSharer implements FileSharer {
  _RecordingFileSharer({this.isSupported = true, this.failure});

  @override
  final bool isSupported;

  final ParseFailure<bool>? failure;

  final List<ShareableFile> shared = <ShareableFile>[];
  String? subject;
  bool called = false;

  @override
  Future<ParseResult<bool>> share(
    List<ShareableFile> files, {
    String? subject,
  }) async {
    called = true;
    this.subject = subject;
    shared.addAll(files);
    final ParseFailure<bool>? error = failure;
    if (error != null) {
      return error;
    }

    return const ParseSuccess<bool>(true);
  }
}

void main() {
  test('save_givenASupportedSharer_handsUtf8JsonWithItsName', () async {
    final _RecordingFileSharer sharer = _RecordingFileSharer();
    final SharingJsonFileSaver saver = SharingJsonFileSaver(sharer: sharer);

    final ParseResult<bool> saved = await saver.save(
      suggestedName: 'sources.json',
      contents: '{"name":"剑来"}',
    );

    expect((saved as ParseSuccess<bool>).data, isTrue);
    expect(sharer.called, isTrue);
    expect(sharer.shared, hasLength(1));
    final ShareableFile file = sharer.shared.single;
    expect(file.name, 'sources.json');
    expect(file.mimeType, 'application/json');
    expect(file.path, isNull);
    expect(file.bytes, utf8.encode('{"name":"剑来"}'));
  });

  test('save_givenNoShareSheet_answersNotSavedWithoutCallingIt', () async {
    final _RecordingFileSharer sharer = _RecordingFileSharer(
      isSupported: false,
    );
    final SharingJsonFileSaver saver = SharingJsonFileSaver(sharer: sharer);

    final ParseResult<bool> saved = await saver.save(
      suggestedName: 'sources.json',
      contents: '{}',
    );

    expect((saved as ParseSuccess<bool>).data, isFalse);
    expect(sharer.called, isFalse);
  });

  test('save_givenTheSharerFails_returnsItsFailure', () async {
    const ParseFailure<bool> failure = ParseFailure<bool>(
      kind: ParseFailureKind.parseFailed,
      rulePath: 'share',
    );
    final SharingJsonFileSaver saver = SharingJsonFileSaver(
      sharer: _RecordingFileSharer(failure: failure),
    );

    final ParseResult<bool> saved = await saver.save(
      suggestedName: 'sources.json',
      contents: '{}',
    );

    expect(saved, failure);
  });
}
