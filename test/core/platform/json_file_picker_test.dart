import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_picker.dart';
import 'package:flutter_reader/core/platform/json_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a picker whose dialog answers [file] (or nothing, when [file] is `null`).
FileSelectorJsonFilePicker _pickerReturning(PickedJsonFile? file) =>
    FileSelectorJsonFilePicker(opener: () async => file);

void main() {
  group('UnsupportedJsonFilePicker', () {
    test('pick_givenAPlatformWithoutADialog_answersNothingPicked', () async {
      // platform.md §2 的契约：不支持的平台返回 null/no-op，禁止抛异常。
      final ParseResult<String?> result =
          await const UnsupportedJsonFilePicker().pick(maxBytes: 1024);

      expect(result.dataOrNull, isNull);
    });
  });

  group('FileSelectorJsonFilePicker', () {
    test('pick_givenACancelledDialog_answersNothingPicked', () async {
      final ParseResult<String?> result = await _pickerReturning(null)
          .pick(maxBytes: 1024);

      expect(result.dataOrNull, isNull);
    });

    test('pick_givenAFileWithinTheCap_returnsItsText', () async {
      final ParseResult<String?> result = await _pickerReturning(
        PickedJsonFile(
          name: 'sources.json',
          bytes: utf8.encode('[{"bookSourceName":"a"}]'),
        ),
      ).pick(maxBytes: 1024);

      expect(result.dataOrNull, '[{"bookSourceName":"a"}]');
    });

    test('pick_givenAFileOverTheCap_failsBeforeReadingIt', () async {
      // 上限按**文件体积**在读取之前判（C-SEC-5 / C-PERF-5）：超限的文件根本不进内存。
      final ParseResult<String?> result = await _pickerReturning(
        PickedJsonFile(name: 'huge.json', bytes: List<int>.filled(64, 0x20)),
      ).pick(maxBytes: 8);

      expect(result, isA<ParseFailure<String?>>());
      expect(switch (result) {
        ParseFailure<String?>(:final ParseFailureKind kind) => kind,
        ParseSuccess<String?>() => null,
      }, ParseFailureKind.invalidBookSource);
      expect(switch (result) {
        ParseFailure<String?>(:final String rulePath) => rulePath,
        ParseSuccess<String?>() => null,
      }, 'import.sizeLimit');
    });

    test('pick_givenAFileWithAByteOrderMark_stripsIt', () async {
      // 编辑器留下的 BOM 会让 jsonDecode 直接失败，而文件本身是好的。
      final ParseResult<String?> result = await _pickerReturning(
        PickedJsonFile(
          name: 'bom.json',
          bytes: utf8.encode('\uFEFF{"bookSourceName":"a"}'),
        ),
      ).pick(maxBytes: 1024);

      expect(result.dataOrNull, '{"bookSourceName":"a"}');
    });
  });
}
