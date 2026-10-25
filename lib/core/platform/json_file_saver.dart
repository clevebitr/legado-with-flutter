import 'package:flutter_reader/core/error/parse_result.dart';

/// Writes a JSON document to a file the user chooses.
///
/// One port for both exports (book sources and 替换净化 rules, ADR-0071 §决策 3): the two differ in
/// what they write, never in how the user picks a place to write it.
///
/// Cancelling answers `ParseSuccess(false)`, not a failure.
abstract interface class JsonFileSaver {
  /// Asks the user where to save [contents] and writes it, answering whether it happened.
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required String contents,
  });
}

/// The fallback for a platform with no save dialog: it answers “not saved”.
final class UnsupportedJsonFileSaver implements JsonFileSaver {
  /// Creates the fallback.
  const UnsupportedJsonFileSaver();

  @override
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required String contents,
  }) async => const ParseSuccess<bool>(false);
}

/// Opens the platform's save dialog and writes [contents] (`null` when the user cancelled).
typedef JsonFileWriter = Future<String?> Function({
  required String suggestedName,
  required String contents,
});
