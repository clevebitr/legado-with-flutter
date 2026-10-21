import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/long_running_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_log_printer.dart';

/// The calls the mock platform side received.
final List<String> _calls = <String>[];

/// Installs a mock handler for the channel, answering [throwOn] with that error.
void _mockChannel({Exception? throwOn}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel(longRunningTaskChannelName),
        (MethodCall call) async {
          _calls.add(call.method);
          if (throwOn != null) {
            throw throwOn;
          }

          return null;
        },
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnsupportedLongRunningTask', () {
    test('acquire_whenThePlatformHasNone_isANoOp', () async {
      // platform.md §2 的契约：不支持的平台 no-op，禁止抛异常。
      const LongRunningTask task = UnsupportedLongRunningTask();

      await task.acquire();
      await task.release();

      expect(task.isSupported, isFalse);
    });
  });

  group('MethodChannelLongRunningTask', () {
    late FakeLogPrinter printer;
    late MethodChannelLongRunningTask task;

    setUp(() {
      _calls.clear();
      _mockChannel();
      printer = FakeLogPrinter();
      task = MethodChannelLongRunningTask(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(longRunningTaskChannelName),
            null,
          );
    });

    test('acquireAndRelease_whenCalled_reachThePlatformInOrder', () async {
      await task.acquire();
      await task.release();

      expect(task.isSupported, isTrue);
      expect(_calls, <String>['acquire', 'release']);
    });

    test('acquire_givenAMissingPlugin_degradesWithoutThrowing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(longRunningTaskChannelName),
            null,
          );

      await task.acquire();

      expect(task.isSupported, isFalse);
      // 降级后不再打通道：第二次调用连 mock 都不会被问到。
      await task.acquire();
      expect(
        printer.events.single.message.toString(),
        contains('not implemented'),
      );
    });

    test('acquire_givenAPlatformError_degradesAndLogsAWarning', () async {
      _mockChannel(
        throwOn: PlatformException(code: 'unavailable', message: 'no power'),
      );

      await task.acquire();

      expect(task.isSupported, isFalse);
      expect(printer.events.last.level, Level.warning);
      expect(
        printer.events.last.message.toString(),
        contains('LongRunningTask.acquire failed'),
      );
    });
  });
}
