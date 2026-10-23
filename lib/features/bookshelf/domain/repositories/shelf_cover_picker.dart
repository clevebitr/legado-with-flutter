// coverage:ignore-file
import 'package:flutter_reader/core/logging/app_logger.dart';

/// Stores a cover the user picked and answers the path to remember
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 5).
///
/// The port exists for the same reason `BookSourceFilePicker` does (C-PLT-1): the dialog is a
/// platform capability, while «copy the bytes into the app's own directory and answer the absolute
/// path» is ordinary Dart that a test can exercise with a fake opener and a temporary directory.
///
/// A cancelled dialog is `null`, never a failure — “the user closed it” is not an error
/// (`docs/dev/platform.md` §2).
abstract interface class ShelfCoverPicker {
  /// Picks one image, copies it into the cover directory and answers its absolute path.
  Future<String?> pickAndStore();

  /// Deletes the file at [path]; a missing file is not an error.
  Future<void> delete(String path);
}

/// The answer when nothing bound [ShelfCoverPicker]: no cover is picked and one line is logged.
///
/// It is the default of `shelfCoverPickerProvider`, so a forgotten binding shows up as a no-op
/// button plus a log line instead of an exception (ADR-0041 §决策 2's habit).
final class UnboundShelfCoverPicker implements ShelfCoverPicker {
  /// Creates the unbound port; `_logger` receives the warning.
  const UnboundShelfCoverPicker({required this._logger});

  final AppLogger _logger;

  @override
  Future<String?> pickAndStore() async {
    _logger.warning(
      'No ShelfCoverPicker is bound: choosing a cover did nothing.',
    );

    return null;
  }

  @override
  Future<void> delete(String path) async {
    _logger.warning(
      'No ShelfCoverPicker is bound: the old cover file was not deleted.',
    );
  }
}
