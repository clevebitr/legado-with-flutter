import 'package:flutter_reader/core/error/parse_result.dart';

/// Writes one book source's JSON to a file the user chooses.
///
/// Cancelling answers `ParseSuccess(false)`, not a failure.
abstract interface class BookSourceFileSaver {
  /// Asks the user where to save [contents] and writes it, answering whether it happened.
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required String contents,
  });
}

/// The fallback for a platform with no save dialog: it answers “not saved”.
final class UnsupportedBookSourceFileSaver implements BookSourceFileSaver {
  /// Creates the fallback.
  const UnsupportedBookSourceFileSaver();

  @override
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required String contents,
  }) async => const ParseSuccess<bool>(false);
}

/// Opens the platform's save dialog and writes [contents] (`null` when the user cancelled).
typedef BookSourceFileWriter = Future<String?> Function({
  required String suggestedName,
  required String contents,
});
