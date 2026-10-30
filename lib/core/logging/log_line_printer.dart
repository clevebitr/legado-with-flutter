import 'package:logger/logger.dart';

/// Prints one record per line: `2026-10-28 10:45:22.276 INFO  message`.
///
/// Why this exists instead of the `logger` default (`PrettyPrinter`) — ADR-0084:
///
/// * the **file** log has to be greppable: `PrettyPrinter` draws an ANSI-coloured box, so one
///   record became five physical lines and the log file ended up full of escape sequences
///   (`\x1b[38;5;12m┌───…`) instead of records;
/// * the **same lines** go to the console (`_FileOutput` prints and appends), so the colours would
///   also land in `flutter run` / `adb logcat` output where they only help if a human reads it live.
///
/// A stack trace is multi-line by nature, so it is emitted as **indented continuation lines**: the
/// record itself is one line, and the trace stays attached to it (and still reaches `grep`).
final class LineLogPrinter extends LogPrinter {
  /// Creates the printer. It has no options on purpose: a log line should have exactly one shape.
  LineLogPrinter();

  @override
  List<String> log(LogEvent event) {
    final StringBuffer header = StringBuffer()
      ..write(_timestamp(event.time))
      ..write(' ')
      ..write(_levelTag(event.level))
      ..write(' ')
      // 一条记录一行：消息与异常里的换行都压成 ` | `，否则一条记录会把整份日志切成两段。
      ..write(_oneLine(_textOf(event.message)));
    final Object? error = event.error;
    if (error != null) {
      header
        ..write('  error=')
        ..write(_oneLine(_textOf(error)));
    }

    final StackTrace? stackTrace = event.stackTrace;
    return <String>[
      header.toString(),
      if (stackTrace != null && stackTrace.toString().trim().isNotEmpty)
        for (final String line in stackTrace.toString().trim().split('\n'))
          '  ${line.trim()}',
    ];
  }
}

/// `yyyy-MM-dd HH:mm:ss.SSS` in local time — the format the log file's name already implies.
String _timestamp(DateTime time) {
  final String date =
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';
  final String clock =
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}.'
      '${time.millisecond.toString().padLeft(3, '0')}';

  return '$date $clock';
}

/// A fixed-width level tag, so the message column starts at the same offset on every line.
///

String _levelTag(Level level) => switch (level) {
  Level.trace => 'TRACE',
  Level.debug => 'DEBUG',
  Level.info => 'INFO ',
  Level.warning => 'WARN ',
  Level.error => 'ERROR',
  Level.fatal => 'FATAL',
  // `all` / `off` / `nothing` / 已废弃的 `verbose` 只作过滤阈值，`LogEvent` 构造器本身就会
  // 拒绝其中的 `all` / `off`；真有人传了也给一个定宽标签，而不是把 `null` 打进日志。
  _ => 'LEVEL',
};

/// `logger` types `message` / `error` as `Object?`; whatever arrives is stringified once, here.
String _textOf(Object? value) => switch (value) {
  null => '',
  final String text => text,
  _ => value.toString(),
};

/// Collapses every newline (and the indentation that follows it) into one separator.
String _oneLine(String text) =>
    text.replaceAll(RegExp(r'\s*\r?\n\s*'), ' | ').trim();
