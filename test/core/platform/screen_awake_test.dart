import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/screen_awake.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_log_printer.dart';

/// The channel calls one test observed.
final List<MethodCall> _calls = <MethodCall>[];

/// Installs a mock handler for the channel, answering with [error] when given.
void _mockChannel({PlatformException? error}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel(screenAwakeChannelName), (
        MethodCall call,
      ) async {
        _calls.add(call);
        if (error != null) {
          throw error;
        }

        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(screenAwakeChannelName),
          null,
        );
  });

  group('UnsupportedScreenAwake', () {
    test('setAwake_givenAPlatformWithoutSupport_doesNothing', () async {
      const UnsupportedScreenAwake port = UnsupportedScreenAwake();

      await port.setAwake(awake: true);

      expect(port.isSupported, isFalse);
    });
  });

  group('MethodChannelScreenAwake', () {
    test('setAwake_givenAFlag_sendsItOnTheChannel', () async {
      _mockChannel();
      final MethodChannelScreenAwake port = MethodChannelScreenAwake(
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      );

      await port.setAwake(awake: true);
      await port.setAwake(awake: false);

      expect(_calls.map((MethodCall call) => call.method), <String>[
        'setAwake',
        'setAwake',
      ]);
      expect(
        _calls.map(
          (MethodCall call) =>
              (call.arguments as Map<Object?, Object?>)['awake'],
        ),
        <Object?>[true, false],
      );
      expect(port.isSupported, isTrue);
    });

    test('setAwake_givenNoNativeHandler_degradesToUnsupported', () async {
      // 通道没接（测试宿主 / 没重新构建原生工程）：只记一次，之后不再调。
      final FakeLogPrinter printer = FakeLogPrinter();
      final MethodChannelScreenAwake port = MethodChannelScreenAwake(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      await port.setAwake(awake: true);
      await port.setAwake(awake: true);

      expect(port.isSupported, isFalse);
    });

    test('setAwake_givenAPlatformError_degradesToUnsupported', () async {
      _mockChannel(
        error: PlatformException(code: 'boom', message: 'no window'),
      );
      final MethodChannelScreenAwake port = MethodChannelScreenAwake(
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      );

      await port.setAwake(awake: true);

      expect(port.isSupported, isFalse);
      expect(_calls, hasLength(1));
    });
  });
}
