import 'package:flutter_reader/core/error/parse_result.dart';

/// Writes a binary archive to a file the user chooses (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// A sibling of `JsonFileSaver` rather than a generalization of it: the backup is a zip, and the
/// save dialog has to offer a `.zip` filter instead of `.json`.
///
/// Cancelling answers `ParseSuccess(false)`, not a failure.
abstract interface class BackupArchiveSaver {
  /// Asks the user where to save [bytes] and writes them, answering whether it happened.
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required List<int> bytes,
  });
}

/// The fallback for a platform with no save dialog: it answers “not saved”.
final class UnsupportedBackupArchiveSaver implements BackupArchiveSaver {
  /// Creates the fallback.
  const UnsupportedBackupArchiveSaver();

  @override
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required List<int> bytes,
  }) async => const ParseSuccess<bool>(false);
}

/// Opens the platform's save dialog and writes [bytes] (`null` when the user cancelled).
typedef BackupArchiveWriter = Future<String?> Function({
  required String suggestedName,
  required List<int> bytes,
});
