/// One image the user picked for a book cover: its bytes and a display name.
final class PickedCoverFile {
  /// Creates the picked image.
  const PickedCoverFile({required this.name, required this.bytes});

  /// The file's name, used to keep its extension.
  final String name;

  /// The image bytes.
  final List<int> bytes;
}

/// Asks the platform for one image file.
abstract interface class CoverFilePicker {
  /// Lets the user pick one image, or answers `null` when nothing was picked.
  Future<PickedCoverFile?> pick();
}

/// The fallback for a platform without a picker: “nothing picked”.
final class UnsupportedCoverFilePicker implements CoverFilePicker {
  /// Creates the fallback.
  const UnsupportedCoverFilePicker();

  @override
  Future<PickedCoverFile?> pick() async => null;
}
