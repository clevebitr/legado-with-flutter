import 'package:flutter_reader/core/error/parse_result.dart';

/// Asks the platform for a folder the backups are written to
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1).
///
/// A cancel answers `ParseSuccess(null)` — the caller keeps its current location. There is no default
/// implementation that guesses a folder: an unsupported platform answers “nothing picked”, and the
/// backup falls back to the app's private directory.
abstract interface class BackupDirectoryPicker {
  /// Lets the user pick one folder and answers its path, or `null` when nothing was picked.
  Future<ParseResult<String?>> pick();
}

/// The fallback for a platform with no directory dialog.
final class UnsupportedBackupDirectoryPicker implements BackupDirectoryPicker {
  /// Creates the fallback.
  const UnsupportedBackupDirectoryPicker();

  @override
  Future<ParseResult<String?>> pick() async =>
      const ParseSuccess<String?>(null);
}

/// Opens the platform's folder dialog and answers the chosen path (`null` when cancelled).
typedef DirectoryOpener = Future<String?> Function();
