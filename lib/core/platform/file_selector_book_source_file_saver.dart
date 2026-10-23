import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/book_source_file_saver.dart';
import 'package:flutter_reader/core/platform/file_selector_dialog.dart';

/// [BookSourceFileSaver] backed by the `file_selector` plugin.
///
/// It contains no platform channel and no plugin type: the single plugin call stays in
/// [fileSelectorSaveJsonFile], which is the one file ADR-0019 exempts. Cancelling and “saved” are
/// the two answers the port promises, and a write failure travels as a [ParseFailure] of kind
/// [ParseFailureKind.invalidBookSource] — the export's own `rulePath` tells the caller which
/// source it was.
final class FileSelectorBookSourceFileSaver implements BookSourceFileSaver {
  /// Creates the saver.
  ///
  /// [write] defaults to the real `file_selector` dialog; a test injects a fake so the adapter's
  /// own logic (cancel → `false`, write failure → `ParseFailure`) is covered without a platform
  /// channel (`docs/dev/testing.md` §4). The plugin call itself stays in the exempt file.
  const FileSelectorBookSourceFileSaver({BookSourceFileWriter? write})
    : _write = write ?? fileSelectorSaveJsonFile;

  final BookSourceFileWriter _write;

  @override
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required String contents,
  }) async {
    try {
      final String? path = await _write(
        suggestedName: suggestedName,
        contents: contents,
      );

      return ParseSuccess<bool>(path != null);
    } on Exception {
      return failureAt<bool>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'export.write',
      );
    }
  }
}
