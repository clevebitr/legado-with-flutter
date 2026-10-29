import 'package:flutter/foundation.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/crash_handlers.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_log_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('installCrashHandlers', () {
    late FakeLogPrinter printer;
    late AppLogger logger;
    late FlutterExceptionHandler? previous;
    late List<FlutterErrorDetails> chained;

    setUp(() {
      printer = FakeLogPrinter();
      logger = AppLogger(level: LogLevel.debug, printer: printer);
      previous = FlutterError.onError;
      chained = <FlutterErrorDetails>[];
      // 上游 handler 换成记录器：装着 handler 时再报错会绕回来，测试里不能让它失败。
      FlutterError.onError = chained.add;
    });

    tearDown(() {
      uninstallCrashHandlerPorts();
      FlutterError.onError = previous;
    });

    /// The one `CRASH` record the handler wrote.
    LogEvent record() => printer.events.single;

    test('onError_givenAWidgetError_recordsItAndKeepsTheUpstreamHandler', () {
      installCrashHandlers(logger);

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError('A RenderFlex overflowed by 31 pixels.'),
          stack: StackTrace.current,
        ),
      );

      expect(record().level, Level.error);
      expect(record().message, contains(crashMarker));
      expect(record().message, contains('flutter: A RenderFlex'));
      // 上游 handler 仍然被调用：装 handler 不能把别人的日志吞掉。
      expect(chained, hasLength(1));
    });

    test('onError_givenAWidgetChain_namesTheWidgetOnTheSameLine', () {
      installCrashHandlers(logger);

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError('A RenderFlex overflowed by 31 pixels.'),
          informationCollector: () => <DiagnosticsNode>[
            DiagnosticsNode.message('Column ← Padding ← ReaderPageView'),
            // 渲染树转储：几 KB 一条，必须被跳过（一条记录一行）。
            DiagnosticsNode.message('x' * 5000),
          ],
        ),
      );

      // 真机上「溢出 31 像素」重复十几次的日志里没有任何线索；这一项就是那根线索。
      expect(
        record().message,
        contains('where=Column ← Padding ← ReaderPageView'),
      );
      expect(record().message, isNot(contains('xxxx')));
    });

    test('onError_givenOnlyAHugeDump_leavesTheRecordWithoutAWidget', () {
      installCrashHandlers(logger);

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError('boom'),
          informationCollector: () => <DiagnosticsNode>[
            DiagnosticsNode.message('y' * 5000),
          ],
        ),
      );

      expect(record().message, isNot(contains('where=')));
    });

    test('onCrash_givenARecord_receivesTheSameTextAndStack', () {
      final List<String> records = <String>[];
      installCrashHandlers(
        logger,
        onCrash: (String record, Object error, StackTrace stack) =>
            records.add(record),
      );

      FlutterError.reportError(
        FlutterErrorDetails(exception: FlutterError('boom')),
      );

      expect(records.single, startsWith('$crashMarker '));
      expect(records.single, contains('boom'));
    });
  });
}
