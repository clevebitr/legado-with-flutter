// coverage:ignore-file
import 'package:file_selector/file_selector.dart';
import 'package:flutter_reader/core/platform/book_source_file_picker.dart';

/// The one place that talks to the `file_selector` plugin (`PLAN.md` 5.8's file import).
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
