import 'package:flutter_reader/core/platform/background_image_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_cover_file_picker.dart';

/// [BackgroundImagePicker] backed by `file_selector`.
///
/// Reuses the cover-image dialog: both ask for one image the app will copy into its own directory,
/// and one place decides which extensions and MIME types a user may pick.
final class FileSelectorBackgroundImagePicker implements BackgroundImagePicker {
  /// Creates the picker; [open] defaults to the real dialog.
  const FileSelectorBackgroundImagePicker({BackgroundImageOpener? open})
    : _open = open ?? fileSelectorOpenBackgroundImage;

  final BackgroundImageOpener _open;

  @override
  Future<PickedBackgroundImage?> pick() => _open();
}

/// Opens the platform's image dialog and answers what the user picked.
typedef BackgroundImageOpener = Future<PickedBackgroundImage?> Function();
