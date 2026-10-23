import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/book_source_file_saver.dart';
import 'package:flutter_reader/core/platform/file_selector_dialog.dart';

/// [BookSourceFileSaver] backed by the `file_selector` plugin.
///
/// A cancelled dialog answers `false`; a write failure travels as a [ParseFailure] of kind
/// [ParseFailureKind.invalidBookSource].
final class FileSelectorBookSourceFileSaver implements BookSourceFileSaver {
  /// Creates the saver; [write] defaults to the real save dialog.
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
