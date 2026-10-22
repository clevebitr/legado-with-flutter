// coverage:ignore-file
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_reader/core/platform/book_source_file_picker.dart';

/// The one place that talks to the `file_selector` plugin (`docs/dev/roadmap.md` 5.8's file import).
///
/// 本文件按 ADR-0019 登记在 `tool/coverage_allowlist.txt` 中豁免：它只在真实平台上可达
/// （Windows / Android / iOS 的原生对话框），宿主 VM 里没有可用的平台通道，交互本身也无法自动化。
/// 读字节、体积上限与 BOM 处理都在 `FileSelectorBookSourceFilePicker` 里，那一份由单测覆盖；
/// 本文件由设备级构建与双端探针验证「能编译、能链接、应用能起来」（ADR-0039）。
///
/// A picker that returns `null` means the user cancelled (or the platform answered nothing), which
/// the port turns into `ParseSuccess(null)`.
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
///
/// The companion of [fileSelectorOpenJsonFile], with the same exemption (ADR-0019 second category):
/// only a real platform has a save dialog. Everything that can be decided without one — which bytes
/// are written, what happens on cancel, what the failure looks like — lives in the port's adapter.
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
