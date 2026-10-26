/// One image the user picked as the theme background (`docs/dev/roadmap.md` M22, ADR-0075).
final class PickedBackgroundImage {
  /// Creates the picked image.
  const PickedBackgroundImage({required this.name, required this.bytes});

  /// The file's name, used only to keep a sensible extension.
  final String name;

  /// The image bytes.
  final List<int> bytes;
}

/// Asks the platform for one image file to use as the background.
///
/// A cancel answers `null`; a platform without a dialog answers `null` too, and the settings page
/// simply keeps the current background.
abstract interface class BackgroundImagePicker {
  /// Lets the user pick one image, or answers `null` when nothing was picked.
  Future<PickedBackgroundImage?> pick();
}

/// The fallback for a platform without an image dialog.
final class UnsupportedBackgroundImagePicker implements BackgroundImagePicker {
  /// Creates the fallback.
  const UnsupportedBackgroundImagePicker();

  @override
  Future<PickedBackgroundImage?> pick() async => null;
}
