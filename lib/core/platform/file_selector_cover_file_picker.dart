// coverage:ignore-file
import 'package:file_selector/file_selector.dart';
import 'package:flutter_reader/core/platform/background_image_picker.dart';
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

/// Opens the same image dialog for the theme background (ADR-0075 §决策 1).
///
/// One dialog for both: the accepted types are identical, and a second copy of them would be a second
/// answer to「哪些图片能选」.
Future<PickedBackgroundImage?> fileSelectorOpenBackgroundImage() async {
  final PickedCoverFile? file = await fileSelectorOpenCoverImage();

  return file == null
      ? null
      : PickedBackgroundImage(name: file.name, bytes: file.bytes);
}
