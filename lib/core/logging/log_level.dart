/// Verbosity of the application logger.
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
  off;

  /// Parses a `LOG_LEVEL` value, ignoring case and surrounding whitespace.
  ///
  /// An unrecognised value falls back to [LogLevel.info] instead of throwing.
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
