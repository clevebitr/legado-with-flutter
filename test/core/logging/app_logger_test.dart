import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

/// 内存收集器：截获 `LogEvent` 本身，因此能断言级别与内容（testing.md §4）。
final class _CapturingPrinter extends LogPrinter {
  final List<LogEvent> events = <LogEvent>[];

  @override
  List<String> log(LogEvent event) {
    events.add(event);
    return const <String>[];
  }
}

void main() {
  group('AppLogger', () {
    test('debug_whenLevelIsDebug_recordsADebugEvent', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.debug,
        printer: printer,
      );

      logger.debug('cache warm');

      expect(printer.events, hasLength(1));
      expect(printer.events.single.level, Level.debug);
      expect(printer.events.single.message, 'cache warm');
    });

    test('info_whenLevelIsInfo_recordsAnInfoEvent', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: printer,
      );

      logger.info('search finished');

      expect(printer.events.single.level, Level.info);
    });

    test('warning_whenLevelIsWarning_recordsAWarningEvent', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.warning,
        printer: printer,
      );

      logger.warning('toc page 3 missing');

      expect(printer.events.single.level, Level.warning);
    });

    test('error_whenLevelIsError_recordsAnErrorEvent', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.error,
        printer: printer,
      );

      logger.error('content failed');

      expect(printer.events.single.level, Level.error);
    });

    test('debug_whenLevelIsInfo_dropsTheRecord', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: printer,
      );

      logger.debug('dropped');
      logger.info('kept');

      expect(printer.events.map((LogEvent event) => event.message), <String>[
        'kept',
      ]);
    });

    test('error_whenLevelIsOff_dropsTheRecord', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(level: LogLevel.off, printer: printer);

      logger.error('never recorded');

      expect(printer.events, isEmpty);
    });

    test('warning_whenStackTraceIsGiven_forwardsIt', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: printer,
      );

      logger.warning('parse failed', null, StackTrace.empty);

      expect(printer.events.single.stackTrace, StackTrace.empty);
      expect(printer.events.single.error, isNull);
    });

    test('error_whenRawExceptionIsPassed_recordsADigestInsteadOfItsText', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: printer,
      );

      logger.error(
        'fetch failed',
        const FormatException('GET https://example.com/a?token=abc failed'),
      );

      final Object? recorded = printer.events.single.error;

      expect(recorded, isA<String>());
      expect(recorded, isNot(contains('example.com')));
      expect(recorded, isNot(contains('abc')));
    });

    test('warning_whenStringErrorCarriesAToken_recordsItScrubbed', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: printer,
      );

      logger.warning(
        'fetch failed',
        'GET https://example.com/a?token=abc failed',
      );

      expect(
        printer.events.single.error,
        'GET https://example.com/a?token=*** failed',
      );
    });

    test('error_whenMessageCarriesAToken_recordsItMasked', () {
      final _CapturingPrinter printer = _CapturingPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: printer,
      );

      logger.error('GET https://example.com/a?token=abc123 failed');

      expect(
        printer.events.single.message,
        'GET https://example.com/a?token=*** failed',
      );
    });
  });
}
