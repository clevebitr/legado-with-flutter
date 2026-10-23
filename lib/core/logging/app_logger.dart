import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/logging/redaction.dart';
import 'package:logger/logger.dart';

/// Application logging facade: the only log entry point for business code.
///
/// Every message is redacted, and every error is reduced to a sanitised form, so
/// a raw exception cannot leak a URL or a token. Page bodies must never be passed.
final class AppLogger {
  /// Creates a logger that drops records below [level].
  ///
  /// [printer] and [output] default to the `logger` defaults.
  AppLogger({
    this.level = LogLevel.info,
    LogPrinter? printer,
    LogOutput? output,
  }) : _logger = Logger(
         level: _toLoggerLevel(level),
         // logger 默认的 DevelopmentFilter 在 release 下不输出，必须显式用 ProductionFilter。
         filter: ProductionFilter(),
         printer: printer,
         output: output,
       );

  /// Effective verbosity; records below it are dropped.
  final LogLevel level;

  final Logger _logger;

  /// Logs a debug record.
  void debug(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.d(
        redactMessage(message),
        error: _sanitizeError(error),
        stackTrace: stackTrace,
      );

  /// Logs an informational record.
  void info(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.i(
        redactMessage(message),
        error: _sanitizeError(error),
        stackTrace: stackTrace,
      );

  /// Logs a warning record.
  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.w(
        redactMessage(message),
        error: _sanitizeError(error),
        stackTrace: stackTrace,
      );

  /// Logs an error record.
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(
        redactMessage(message),
        error: _sanitizeError(error),
        stackTrace: stackTrace,
      );
}

Level _toLoggerLevel(LogLevel level) => switch (level) {
  LogLevel.debug => Level.debug,
  LogLevel.info => Level.info,
  LogLevel.warning => Level.warning,
  LogLevel.error => Level.error,
  LogLevel.off => Level.off,
};

// 在门面内收窄，而不是要求调用方自觉：异常文本常带完整 URL。
Object? _sanitizeError(Object? error) => switch (error) {
  null => null,
  final String text => redactMessage(text),
  _ => describeError(error),
};
