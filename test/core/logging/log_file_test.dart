import 'dart:io';

import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/crash_handlers.dart';
import 'package:flutter_reader/core/logging/log_file.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_log_printer.dart';

/// A printer that answers one line per record without printing anything.
///
/// `FakeLogPrinter` records events and returns **no** lines, which is right for the tests that only
/// assert what was logged; a file sink needs the lines, so this one exists for that test.
final class _LinePrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) => <String>[
    '${event.level.name} ${event.message}',
  ];
}

/// Clock a test can move by hand (`docs/dev/testing.md` §4).
final class _MovableClock implements Clock {
  _MovableClock(this._now);

  DateTime _now;

  void set(DateTime moment) => _now = moment;

  @override
  DateTime now() => _now;
}

void main() {
  late Directory directory;
  late _MovableClock clock;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('log_file_test');
    clock = _MovableClock(DateTime(2026, 10, 27, 12));
  });

  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  LogFile buildLog({int maxTotalBytes = 20 * 1024 * 1024}) =>
      LogFile(directory: directory, clock: clock, maxTotalBytes: maxTotalBytes);

  String read(File file) => file.readAsStringSync();

  group('LogFile', () {
    test('append_givenALine_writesItIntoOneFilePerDay', () async {
      final LogFile log = buildLog();

      await log.append('first');
      await log.append('second');

      expect(log.currentFile.path, endsWith('app-2026-10-27.log'));
      expect(read(log.currentFile), 'first\nsecond\n');
    });

    test('append_whenTheDayChanges_startsANewFile', () async {
      final LogFile log = buildLog();
      await log.append('day one');

      clock.set(DateTime(2026, 10, 28, 1));
      await log.append('day two');

      expect(log.currentFile.path, endsWith('app-2026-10-28.log'));
      expect(await log.list(), hasLength(2));
      expect(read(File('${directory.path}/app-2026-10-27.log')), 'day one\n');
    });

    test('appendSync_givenACrashLine_writesBeforeReturning', () {
      final LogFile log = buildLog();

      log.appendSync('CRASH boom');

      expect(read(log.currentFile), 'CRASH boom\n');
    });

    test('prune_givenFilesOlderThanTheRetention_deletesThem', () async {
      final LogFile log = buildLog();
      for (final int day in <int>[1, 2, 20, 27]) {
        File('${directory.path}/app-2026-10-$day.log')
          ..createSync(recursive: true)
          ..writeAsStringSync('x');
      }

      await log.prune();

      expect((await log.list()).map((LogFileInfo info) => info.day.day), <int>[
        20,
        27,
      ]);
    });

    test('prune_givenTooManyBytes_deletesTheOldestFirst', () async {
      final LogFile log = buildLog(maxTotalBytes: 10);
      for (final int day in <int>[25, 26, 27]) {
        File('${directory.path}/app-2026-10-$day.log')
          ..createSync(recursive: true)
          ..writeAsStringSync('123456');
      }

      await log.prune();

      // 每天 6 字节、上限 10 字节：最早两份删掉，最新那份永远留着。
      expect((await log.list()).map((LogFileInfo info) => info.day.day), <int>[
        27,
      ]);
    });

    test('clear_givenFiles_deletesEveryOneOfThem', () async {
      final LogFile log = buildLog();
      await log.append('a');
      clock.set(DateTime(2026, 10, 28, 1));
      await log.append('b');

      expect(await log.clear(), 2);
      expect(await log.list(), isEmpty);
    });

    test('list_givenForeignFiles_ignoresThem', () async {
      File('${directory.path}/notes.txt').writeAsStringSync('x');
      final LogFile log = buildLog();
      await log.append('a');

      expect(await log.list(), hasLength(1));
    });
  });

  group('AppLogger with a LogFile', () {
    test('info_givenAFile_appendsTheFormattedLine', () async {
      final LogFile log = buildLog();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: _LinePrinter(),
        file: log,
      );

      logger.info('hello 日志');

      // `_FileOutput` 的写入是排队的：等队列跑完再读。
      await log.flush();
      expect(read(log.currentFile), contains('hello 日志'));
    });

    test('info_givenTheDefaultPrinter_writesOnePlainLineWithoutAnsi', () async {
      // ADR-0084：文件日志是**一行一条记录**的可 grep 文本。默认打印器（不再用 `logger` 的
      // PrettyPrinter）因此不能带 ANSI 转义，也不能把一条记录拆成盒线多行。
      final LogFile log = buildLog();
      final AppLogger logger = AppLogger(level: LogLevel.info, file: log);

      logger.info('app start: platform=windows');
      logger.error('content failed', '<FormatException: bad body>');

      await log.flush();
      final List<String> lines = read(log.currentFile).trim().split('\n');
      expect(lines, hasLength(2));
      for (final String line in lines) {
        expect(line, isNot(contains('\u001b')), reason: line);
        expect(line, isNot(contains('┌')), reason: line);
        expect(line, isNot(contains('│')), reason: line);
      }
      expect(lines.first, matches(RegExp(r'^\d{4}-\d{2}-\d{2} ')));
      expect(lines.first, contains('INFO  app start: platform=windows'));
      expect(lines.last, contains('ERROR content failed'));
      expect(lines.last, contains('error=<FormatException: bad body>'));
    });

    test('error_givenACrashRecord_writesTheWholeTraceSynchronously', () async {
      // 崩溃行同步落盘，它的栈续行必须跟着同步：崩溃路径上没有下一次事件循环（ADR-0082）。
      final LogFile log = buildLog();
      final AppLogger logger = AppLogger(level: LogLevel.info, file: log);

      logger.error(
        '$crashMarker platform: boom',
        '<StateError: boom>',
        StackTrace.fromString(
          '#0 main (package:flutter_reader/main.dart:49:10)',
        ),
      );

      // 不 flush：同步路径应当已经把整条记录写完了。
      final List<String> lines = read(log.currentFile).trim().split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, contains('$crashMarker platform: boom'));
      expect(lines.last, contains('#0 main'));
    });

    test('setLevel_givenWarning_dropsLowerRecordsAtRuntime', () {
      // 设置页改的就是这条：级别是**运行时**选择，不只是构建参数（ADR-0082）。
      final FakeLogPrinter printer = FakeLogPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: printer,
      );

      logger.debug('seen?');
      logger.setLevel(LogLevel.warning);
      logger.info('dropped');
      logger.warning('kept');

      expect(printer.events.map((LogEvent event) => event.message), <String>[
        'kept',
      ]);
    });

    test('setLevel_givenOff_dropsEverything', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.debug,
        printer: printer,
      );

      logger.setLevel(LogLevel.off);
      logger.error('gone');

      expect(printer.events, isEmpty);
    });
  });
}
