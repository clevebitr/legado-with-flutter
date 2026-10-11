/// Verbosity of the application logger.
///
/// Mirrors the four methods of the `AppLogger` facade and is mapped onto
/// `package:logger` levels inside that facade, so no other file has to know the
/// underlying library (ADR-0006).
enum LogLevel {
  /// Detailed diagnostics, dropped by default.
  debug,

  /// Normal operational events; the default level.
  info,

  /// Recoverable problems that deserve attention.
  warning,

  /// Failures that need attention.
  error,

  /// Logging is disabled and every record is dropped.
  ///
  /// Lets a build (`--dart-define=LOG_LEVEL=off`) or a future user setting turn
  /// logging off without touching the facade (ADR-0006 §4).
  off;

  /// Parses a `--dart-define=LOG_LEVEL=` value into a [LogLevel].
  ///
  /// Matching ignores case and surrounding whitespace. An unrecognised value
  /// falls back to [LogLevel.info] instead of throwing: a typo in a build flag
  /// must not turn into a crash on a release build.
  static LogLevel parse(String raw) {
    final String normalized = raw.trim().toLowerCase();
    for (final LogLevel level in LogLevel.values) {
      if (level.name == normalized) {
        return level;
      }
    }
    return LogLevel.info;
  }
}
