// coverage:ignore-file
import 'package:file_selector/file_selector.dart';
import 'package:flutter_reader/core/platform/cover_file_picker.dart';

/// The production [CoverFilePicker]: the plugin call lives in this one file.
final class PlatformCoverFilePicker implements CoverFilePicker {
  /// Creates the picker.
  const PlatformCoverFilePicker();

  @override
  Future<PickedCoverFile?> pick() => fileSelectorOpenCoverImage();
}

/// Opens the platform's image dialog, or answers `null` when the user cancelled.
Future<PickedCoverFile?> fileSelectorOpenCoverImage() async {
  final XFile? file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[
      const XTypeGroup(
        label: 'Cover image',
        extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
        // Android 的文档选择器靠 MIME 过滤；只给扩展名会让部分机型把图片变成不可选。
        mimeTypes: <String>['image/jpeg', 'image/png', 'image/webp'],
      ),
    ],
  );
  if (file == null) {
    return null;
  }

  return PickedCoverFile(name: file.name, bytes: await file.readAsBytes());
}
