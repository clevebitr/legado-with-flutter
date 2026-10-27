import 'package:flutter_reader/core/logging/crash_handlers.dart';
import 'package:flutter_reader/core/logging/error_text.dart';
import 'package:flutter_reader/core/logging/log_file.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:logger/logger.dart';

/// Application logging facade: the only log entry point for business code.
///
/// Messages are logged **as written** — this repository is open source and redacting its own
/// diagnostics only made failures harder to read (`ADR-0082`). Two rules survive as *logging
/// discipline* rather than masking: request headers (`Cookie` / `Authorization`) and page bodies are
/// never handed to the logger in the first place, because neither is needed to locate a rule.
final class AppLogger {
  /// Creates a logger that drops records below [level].
  ///
  /// [printer] and [output] default to the `logger` defaults; passing [file] appends the same
  /// formatted lines to disk (`ADR-0082`). The effective level can be changed at runtime with
  /// [setLevel], which is what the settings page does.
  AppLogger({
    this.level = LogLevel.info,
    LogPrinter? printer,
    LogOutput? output,
    LogFile? file,
  }) : _logger = Logger(
         // 级别由门面自己判（`setLevel` 能在运行时改），这里放全部，别再让 logger 静默丢掉。
         level: Level.all,
         // logger 默认的 DevelopmentFilter 在 release 下不输出，必须显式用 ProductionFilter。
         filter: ProductionFilter(),
         printer: printer,
         output: output ?? (file == null ? null : _FileOutput(file)),
       );

  /// Effective verbosity; records below it are dropped.
  LogLevel level;

  /// Changes the effective level, keeping records below it out of every output.
  ///
  /// Used by the settings page (`ADR-0082`): the level is a user choice, not only a build flag.
  void setLevel(LogLevel level) => this.level = level;

  final Logger _logger;

  /// Whether [level] is at or above the effective level.
  bool isEnabled(LogLevel level) =>
      this.level != LogLevel.off && level.index >= this.level.index;

  /// Logs a debug record.
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (isEnabled(LogLevel.debug)) {
      _logger.d(message, error: _asText(error), stackTrace: stackTrace);
    }
  }

  /// Logs an informational record.
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (isEnabled(LogLevel.info)) {
      _logger.i(message, error: _asText(error), stackTrace: stackTrace);
    }
  }

  /// Logs a warning record.
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (isEnabled(LogLevel.warning)) {
      _logger.w(message, error: _asText(error), stackTrace: stackTrace);
    }
  }

  /// Logs an error record.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (isEnabled(LogLevel.error)) {
      _logger.e(message, error: _asText(error), stackTrace: stackTrace);
    }
  }
}

/// Writes the same formatted lines to the console **and** to [LogFile].
final class _FileOutput extends LogOutput {
  _FileOutput(this._file);

  final LogFile _file;

  @override
  void output(OutputEvent event) {
    // 一行一个事件：`logger` 的 printer 已经把时间 / 级别 / 调用点拼好。
    for (final String line in event.lines) {
      // 控制台照旧（`flutter logs` / `adb logcat` 仍然好用）。
      // ignore: avoid_print
      print(line);
      // 崩溃那几行同步写：崩溃路径上不一定还有下一次事件循环（ADR-0082）。
      if (line.contains('$crashMarker ')) {
        _file.appendSync(line);
      } else {
        _file.append(line);
      }
    }
  }
}

// 异常一律落成「类型 + 原文」：日志不脱敏（ADR-0082），但要能按失败类型 grep。
Object? _asText(Object? error) => switch (error) {
  null => null,
  final String text => text,
  _ => describeError(error),
};
