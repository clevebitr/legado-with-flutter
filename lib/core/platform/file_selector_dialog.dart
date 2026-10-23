// coverage:ignore-file
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_reader/core/platform/book_source_file_picker.dart';

/// Opens the platform's JSON file dialog, or answers `null` when the user cancelled.
Future<PickedBookSourceFile?> fileSelectorOpenJsonFile() async {
  final XFile? file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[
      const XTypeGroup(
        label: 'Book source JSON',
        extensions: <String>['json'],
        // Android 的文档选择器靠 MIME 过滤；只给扩展名会让部分机型把 .json 变成不可选。
        mimeTypes: <String>['application/json'],
      ),
    ],
  );
  if (file == null) {
    return null;
  }

  return PickedBookSourceFile(name: file.name, bytes: await file.readAsBytes());
}

/// Asks the user where to save [contents] and writes it, or returns `null` when they cancelled.
Future<String?> fileSelectorSaveJsonFile({
  required String suggestedName,
  required String contents,
}) async {
  final FileSaveLocation? location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: <XTypeGroup>[
      const XTypeGroup(
        label: 'Book source JSON',
        extensions: <String>['json'],
        mimeTypes: <String>['application/json'],
      ),
    ],
  );
  if (location == null) {
    return null;
  }

  await File(location.path).writeAsString(contents);

  return location.path;
}
