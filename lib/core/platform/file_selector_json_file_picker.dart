import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/file_selector_dialog.dart';
import 'package:flutter_reader/core/platform/json_file_picker.dart';

/// [JsonFilePicker] backed by `file_selector`.
///
/// The dialog call is injected through `opener`, so reading, the size cap and BOM handling are
/// ordinary testable Dart.
final class FileSelectorJsonFilePicker implements JsonFilePicker {
  /// Creates the picker; `opener` defaults to the real dialog.
  const FileSelectorJsonFilePicker({this._opener = fileSelectorOpenJsonFile});

  final JsonFileOpener _opener;

  @override
  Future<ParseResult<String?>> pick({required int maxBytes}) async {
    final PickedJsonFile? file = await _opener();
    if (file == null) {
      // 用户取消：不是失败，也不该被当成「读了空文件」去解析。
      return const ParseSuccess<String?>(null);
    }

    if (file.bytes.length > maxBytes) {
      return failureAt<String?>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'import.sizeLimit',
      );
    }

    return ParseSuccess<String?>(_decode(file.bytes));
  }

  // 按 UTF-8 解码并去掉 BOM，否则 jsonDecode 会把带 BOM 的文件判为格式错误。
  String _decode(List<int> bytes) {
    final String text = utf8.decode(bytes, allowMalformed: true);

    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  }
}
