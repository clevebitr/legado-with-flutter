import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_saver.dart';
import 'package:flutter_reader/core/platform/json_file_saver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnsupportedJsonFileSaver', () {
    test('save_givenNoDialog_answersNotSaved', () async {
      // platform.md §2：没有保存对话框的平台 = 用户取消，不是失败。
      expect(
        (await const UnsupportedJsonFileSaver().save(
          suggestedName: 'a.json',
          contents: '{}',
        ) as ParseSuccess<bool>).data,
        isFalse,
      );
    });
  });

  group('FileSelectorJsonFileSaver', () {
    test('save_givenAChosenPath_answersSaved', () async {
      String? writtenPath;
      final JsonFileSaver saver = FileSelectorJsonFileSaver(
        write:
            ({required String suggestedName, required String contents}) async {
              writtenPath = '/tmp/$suggestedName:$contents';

              return '/tmp/$suggestedName';
            },
      );

      final ParseResult<bool> saved = await saver.save(
        suggestedName: '剑来.json',
        contents: '{"a":1}',
      );

      expect((saved as ParseSuccess<bool>).data, isTrue);
      expect(writtenPath, '/tmp/剑来.json:{"a":1}');
    });

    test('save_givenACancelledDialog_answersNotSaved', () async {
      final JsonFileSaver saver = FileSelectorJsonFileSaver(
        write: ({
          required String suggestedName,
          required String contents,
        }) async => null,
      );

      expect(
        (await saver.save(
          suggestedName: 'a.json',
          contents: '{}',
        ) as ParseSuccess<bool>).data,
        isFalse,
      );
    });

    test('save_givenAWriteFailure_answersTheExportMarker', () async {
      final JsonFileSaver saver = FileSelectorJsonFileSaver(
        write: ({
          required String suggestedName,
          required String contents,
        }) async => throw const FileSystemExceptionShim(),
      );

      final ParseResult<bool> saved = await saver.save(
        suggestedName: 'a.json',
        contents: '{}',
      );

      expect(saved, isA<ParseFailure<bool>>());
      expect((saved as ParseFailure<bool>).rulePath, 'export.write');
    });
  });
}

/// A plain [Exception] stand-in (the adapter catches `Exception`, not `Error`).
final class FileSystemExceptionShim implements Exception {
  const FileSystemExceptionShim();
}
