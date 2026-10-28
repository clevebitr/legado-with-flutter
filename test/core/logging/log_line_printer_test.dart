import 'package:flutter_reader/core/logging/log_line_printer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

/// One event as the facade would hand it to a printer.
LogEvent _event({
  Object? message = 'app start: platform=windows',
  Level level = Level.info,
  Object? error,
  StackTrace? stackTrace,
}) => LogEvent(
  level,
  message,
  error: error,
  stackTrace: stackTrace,
  // 固定时间：格式断言的基准（ADR-0084 的行格式）。
  time: DateTime(2026, 10, 28, 10, 45, 22, 276),
);

void main() {
  group('LineLogPrinter', () {
    test('log_givenInfoEvent_answersOnePlainLine', () {
      final List<String> lines = LineLogPrinter().log(_event());

      expect(lines, hasLength(1));
      expect(
        lines.single,
        '2026-10-28 10:45:22.276 INFO  app start: platform=windows',
      );
    });

    test('log_givenAnyLevel_neverWritesAnsiOrBoxCharacters', () {
      // 这两类是旧输出（`logger` 的 PrettyPrinter）留在控制台与日志文件里的东西：
      // ANSI 转义让 `grep` 失效，盒线把一条记录切成五行（ADR-0084）。
      for (final Level level in <Level>[
        Level.trace,
        Level.debug,
        Level.info,
        Level.warning,
        Level.error,
        Level.fatal,
      ]) {
        final String line = LineLogPrinter()
            .log(_event(level: level, message: 'something happened'))
            .first;

        expect(line, isNot(contains('\u001b')), reason: '${level.name} 带 ANSI');
        for (final String box in <String>['┌', '│', '├', '└', '┄']) {
          expect(line, isNot(contains(box)), reason: '${level.name} 带盒线 $box');
        }
      }
    });

    test('log_givenMultilineMessage_keepsTheRecordOnOneLine', () {
      final List<String> lines = LineLogPrinter().log(
        _event(message: 'first line\nsecond    line\n\nthird'),
      );

      expect(lines, hasLength(1));
      // 换行是结构（压成 ` | `），行内空格不动：那可能是对齐过的内容（header 表、字段列表）。
      expect(lines.single, endsWith('first line | second    line | third'));
    });

    test('log_givenError_reportsItOnTheSameLine', () {
      final List<String> lines = LineLogPrinter().log(
        _event(
          level: Level.error,
          message: 'content failed',
          error: '<FormatException: bad body>',
        ),
      );

      expect(lines, hasLength(1));
      expect(lines.single, contains('ERROR content failed'));
      expect(lines.single, contains('error=<FormatException: bad body>'));
    });

    test('log_givenStackTrace_appendsIndentedContinuationLines', () {
      final List<String> lines = LineLogPrinter().log(
        _event(
          level: Level.error,
          message: 'CRASH flutter: boom',
          stackTrace: StackTrace.fromString(
            '#0      main (package:flutter_reader/main.dart:49:10)\n'
            '#1      _startIsolate.<anonymous closure> (dart:isolate-patch:1:1)',
          ),
        ),
      );

      expect(lines, hasLength(3));
      // 记录本身仍是一行，`grep CRASH` 与按行读取都不会被栈打断。
      expect(lines.first, contains('CRASH flutter: boom'));
      expect(lines.first, isNot(contains('#0')));
      expect(lines[1], startsWith('  #0      main'));
      expect(lines[2], startsWith('  #1      _startIsolate'));
    });

    test('log_givenEmptyStackTrace_staysOnOneLine', () {
      final List<String> lines = LineLogPrinter().log(
        _event(stackTrace: StackTrace.fromString('   ')),
      );

      expect(lines, hasLength(1));
    });
  });
}
