// coverage:ignore-file
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_reader/core/platform/backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/json_file_picker.dart';

/// Opens the platform's JSON file dialog, or answers `null` when the user cancelled.
Future<PickedJsonFile?> fileSelectorOpenJsonFile() async {
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

  return PickedJsonFile(name: file.name, bytes: await file.readAsBytes());
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

/// Opens the platform's archive dialog and reads the file, or answers `null` when cancelled.
///
/// The size is checked **before** [XFile.readAsBytes], so an oversized pick never enters memory
/// (`ADR-0073` §决策 2 / C-SEC-5). Two MIME types because Windows reports `.zip` as
/// `application/x-zip-compressed` while Android and iOS use `application/zip`.
Future<BackupArchiveSelection?> fileSelectorOpenBackupArchive({
  required int maxBytes,
}) async {
  final XFile? file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[
      // 不写 label：它是用户可见文案，必须来自 l10n（C-UI-5），而这张表在 core/ 里。
      const XTypeGroup(
        extensions: <String>['zip'],
        mimeTypes: <String>['application/zip', 'application/x-zip-compressed'],
      ),
    ],
  );
  if (file == null) {
    return null;
  }

  final int length = await file.length();
  if (length > maxBytes) {
    return OversizedBackupArchive(name: file.name, length: length);
  }

  return PickedBackupArchive(name: file.name, bytes: await file.readAsBytes());
}

/// Opens the platform's folder dialog and answers the chosen path, or `null` when cancelled.
///
/// No type group: a folder is a folder, and `file_selector` filters files only.
Future<String?> fileSelectorPickDirectory() => getDirectoryPath();

/// Asks the user where to save [bytes] and writes them, or answers `null` when they cancelled.
Future<String?> fileSelectorSaveBackupArchive({
  required String suggestedName,
  required List<int> bytes,
}) async {
  final FileSaveLocation? location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: <XTypeGroup>[
      // 不写 label：它是用户可见文案，必须来自 l10n（C-UI-5），而这张表在 core/ 里。
      const XTypeGroup(
        extensions: <String>['zip'],
        mimeTypes: <String>['application/zip', 'application/x-zip-compressed'],
      ),
    ],
  );
  if (location == null) {
    return null;
  }

  await File(location.path).writeAsBytes(bytes);

  return location.path;
}
