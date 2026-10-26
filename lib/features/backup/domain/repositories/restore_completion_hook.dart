import 'package:flutter_reader/core/logging/app_logger.dart';

/// Notifies the composition root that a restore has written to the database
/// (`docs/dev/roadmap.md` M22, ADR-0073 §决策 3).
///
/// The backup feature cannot invalidate `Settings` or the reader's style provider itself (C-ARCH-2:
/// no feature imports another feature's inner files), and both are `keepAlive`, so without this hook
/// the app would keep showing the theme and text scale it had before the restore.
abstract interface class RestoreCompletionHook {
  /// Runs after the restore transaction committed.
  void onRestored();
}

/// The hook used until the composition root binds the real one.
///
/// It warns instead of failing: a forgotten binding costs 「重启后主题才变」, not a broken restore.
final class UnboundRestoreCompletionHook implements RestoreCompletionHook {
  /// Creates the fallback.
  const UnboundRestoreCompletionHook({required this._logger});

  /// The logger the fallback reports the missing binding with.
  final AppLogger _logger;

  @override
  void onRestored() => _logger.warning(
    'No restore completion hook is bound; the settings providers keep their old values.',
  );
}
