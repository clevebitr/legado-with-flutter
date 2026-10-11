import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/logging/redaction.dart';
import 'package:logger/logger.dart';

/// Application logging facade: the only log entry point for business code
/// (C-ERR-5, ADR-0006).
///
/// Every message passes through [redactMessage] and every `error` is sanitised
/// before it reaches the sink: a `String` error is scrubbed with
/// [redactMessage], any other object is reduced to [describeError]. An
/// exception therefore cannot smuggle a URL, a cookie or a token into the log
/// even when the caller passes it raw (C-SEC-4).
///
/// Structured data must still be redacted by the caller with [redactHeaders],
/// [redactUrl], [describeKeyword] and [describePayload]; a page body must never
/// be handed to this facade at all (C-SEC-4).
final class AppLogger {
  /// Creates a logger that drops records below [level].
  ///
  /// [printer] and [output] default to the `logger` defaults (pretty printer to
  /// the console); tests inject a capturing printer to assert records.
  AppLogger({
    this.level = LogLevel.info,
    LogPrinter? printer,
    LogOutput? output,
  }) : _logger = Logger(
         level: _toLoggerLevel(level),
         // 必须显式用 ProductionFilter：logger 默认的 DevelopmentFilter 只在
         // assert 开启时输出，release 构建下会丢掉全部日志，与 ADR-0006
         // 「release 下默认 info」冲突。
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

/// 把项目自己的 [LogLevel] 映射到 `package:logger` 的 `Level`，保持实现依赖私有。
Level _toLoggerLevel(LogLevel level) => switch (level) {
  LogLevel.debug => Level.debug,
  LogLevel.info => Level.info,
  LogLevel.warning => Level.warning,
  LogLevel.error => Level.error,
  LogLevel.off => Level.off,
};

/// 把 [error] 收窄为已脱敏的形式：字符串走消息脱敏，其他对象只保留类型与摘要。
///
/// 这一步在门面内完成，而不是只写成「调用方必须先脱敏」的文档要求：
/// `DioException` 等异常的 `toString()` 会带上完整 URL，靠自觉挡不住（C-SEC-4）。
Object? _sanitizeError(Object? error) => switch (error) {
  null => null,
  final String text => redactMessage(text),
  _ => describeError(error),
};
