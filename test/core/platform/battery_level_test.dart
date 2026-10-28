import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/battery_level.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_log_printer.dart';

/// The channel calls one test observed.
final List<MethodCall> _calls = <MethodCall>[];

/// Installs a mock handler answering [value], or throwing [error] when given.
void _mockChannel({int? value, PlatformException? error}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel(batteryLevelChannelName), (
        MethodCall call,
      ) async {
        _calls.add(call);
        if (error != null) {
          throw error;
        }

        return value;
      });
}

/// The port under test, with a throwaway logger.
MethodChannelBatteryLevel _port() => MethodChannelBatteryLevel(
  logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(batteryLevelChannelName),
          null,
        );
  });

  group('UnsupportedBatteryLevel', () {
    test('read_givenAPlatformWithoutSupport_answersNull', () async {
      const UnsupportedBatteryLevel port = UnsupportedBatteryLevel();

      expect(await port.read(), isNull);
      expect(port.isSupported, isFalse);
    });
  });

  group('MethodChannelBatteryLevel', () {
    test('read_givenALevel_answersIt', () async {
      _mockChannel(value: 42);

      expect(await _port().read(), 42);
      expect(_calls.single.method, 'level');
    });

    test(
      'read_givenNoValueFromThePlatform_answersNullAndStopsAsking',
      () async {
        // 读不到就是读不到：状态栏省掉电量，而不是画一个假数字。
        _mockChannel();
        final MethodChannelBatteryLevel port = _port();

        expect(await port.read(), isNull);
        expect(port.isSupported, isFalse);
        expect(await port.read(), isNull);
        expect(_calls, hasLength(1));
      },
    );

    test('read_givenAnOutOfRangeLevel_clampsIt', () async {
      _mockChannel(value: 150);

      expect(await _port().read(), 100);
    });

    test('read_givenAPlatformError_answersNull', () async {
      _mockChannel(error: PlatformException(code: 'boom'));

      final MethodChannelBatteryLevel port = _port();

      expect(await port.read(), isNull);
      expect(port.isSupported, isFalse);
    });

    test('read_givenNoNativeHandler_answersNull', () async {
      final MethodChannelBatteryLevel port = _port();

      expect(await port.read(), isNull);
      expect(port.isSupported, isFalse);
    });
  });
}
