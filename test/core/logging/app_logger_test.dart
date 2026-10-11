import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_log_printer.dart';

void main() {
  group('AppLogger', () {
    test('debug_whenLevelIsDebug_recordsADebugEvent', () {
      final FakeLogPrinter printer = FakeLogPrinter();
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
      final FakeLogPrinter printer = FakeLogPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: printer,
      );

      logger.info('search finished');

      expect(printer.events.single.level, Level.info);
    });

    test('warning_whenLevelIsWarning_recordsAWarningEvent', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.warning,
        printer: printer,
      );

      logger.warning('toc page 3 missing');

      expect(printer.events.single.level, Level.warning);
    });

    test('error_whenLevelIsError_recordsAnErrorEvent', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.error,
        printer: printer,
      );

      logger.error('content failed');

      expect(printer.events.single.level, Level.error);
    });

    test('debug_whenLevelIsInfo_dropsTheRecord', () {
      final FakeLogPrinter printer = FakeLogPrinter();
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
      final FakeLogPrinter printer = FakeLogPrinter();
      final AppLogger logger = AppLogger(level: LogLevel.off, printer: printer);

      logger.error('never recorded');

      expect(printer.events, isEmpty);
    });

    test('warning_whenStackTraceIsGiven_forwardsIt', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final AppLogger logger = AppLogger(
        level: LogLevel.info,
        printer: printer,
      );

      logger.warning('parse failed', null, StackTrace.empty);

      expect(printer.events.single.stackTrace, StackTrace.empty);
      expect(printer.events.single.error, isNull);
    });

    test('error_whenRawExceptionIsPassed_recordsADigestInsteadOfItsText', () {
      final FakeLogPrinter printer = FakeLogPrinter();
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
      final FakeLogPrinter printer = FakeLogPrinter();
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
      final FakeLogPrinter printer = FakeLogPrinter();
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
