import 'package:flutter_reader/core/error/parse_result.dart';

/// Writes one book source's JSON to a file the user chooses (`docs/dev/roadmap.md` §3.9-S5,
/// ADR-0050 §决策 4).
///
/// It is the export half of the import picker (`BookSourceFilePicker`), and it follows the same two
/// rules: the platform capability lives behind a port in `core/platform/` (C-PLT-1), and "the user
/// cancelled" is `ParseSuccess(false)` rather than a failure (`docs/dev/platform.md` §2).
///
/// The **bytes** written are the stored payload, not a serialised model: ADR-0040 §决策 4 keeps the
/// payload byte-for-byte, so an export re-imports to the same source (ADR-0050 §决策 4).
abstract interface class BookSourceFileSaver {
  /// Asks the user where to save [contents] and writes it, answering whether it happened.
  ///
  /// [suggestedName] is the file name the dialog starts with, e.g. `book-source.json`.
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
///
/// A typedef so the exporter can default to the real dialog while a test passes a fake one; the
/// plugin call stays in the one exemptable file (`file_selector_dialog.dart`, ADR-0019).
typedef BookSourceFileWriter = Future<String?> Function({
  required String suggestedName,
  required String contents,
});
