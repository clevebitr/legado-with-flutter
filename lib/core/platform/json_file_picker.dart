import 'package:flutter_reader/core/error/parse_result.dart';

/// Asks the platform for one book source file and hands back its text.
///
/// A cancel answers `ParseSuccess(null)`; an oversized file answers
/// [ParseFailureKind.invalidBookSource] with `rulePath: 'import.sizeLimit'`.
abstract interface class JsonFilePicker {
  /// Lets the user pick one JSON file and returns its text, or `null` when nothing was picked.
  Future<ParseResult<String?>> pick({required int maxBytes});
}

/// The fallback for a platform with no file dialog: it answers “nothing picked”.
final class UnsupportedJsonFilePicker implements JsonFilePicker {
  /// Creates the fallback.
  const UnsupportedJsonFilePicker();

  @override
  Future<ParseResult<String?>> pick({required int maxBytes}) async =>
      const ParseSuccess<String?>(null);
}

/// Opens the platform's file dialog and answers what the user picked (`null` when they cancelled).
typedef JsonFileOpener = Future<PickedJsonFile?> Function();

/// What a file dialog produced: the bytes and a display name.
final class PickedJsonFile {
  /// Creates the picked file.
  const PickedJsonFile({required this.name, required this.bytes});

  /// The file's name, for logs only.
  final String name;

  /// The file's contents.
  final List<int> bytes;
}
