import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/source_check_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_log_printer.dart';

/// The channel calls one test observed.
final List<MethodCall> _calls = <MethodCall>[];

/// Installs a mock handler for the channel, answering with [error] when given.
void _mockChannel({PlatformException? error}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel(sourceCheckNotificationChannelName),
        (MethodCall call) async {
          _calls.add(call);
          if (error != null) {
            throw error;
          }

          return null;
        },
      );
}

/// The localized text every case shows.
const SourceCheckNotificationText _text = SourceCheckNotificationText(
  channelName: '书源校验',
  title: '正在校验书源',
  progress: _progress,
  finished: _finished,
);

String _progress(String name, int completed, int total) =>
    '$name · $completed/$total';

String _finished(int succeeded, int failed) => '成功 $succeeded，失败 $failed';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(sourceCheckNotificationChannelName),
          null,
        );
  });

  group('MethodChannelSourceCheckNotification', () {
    test('showProgress_givenALocalizedText_sendsTheRenderedLine', () async {
      _mockChannel();
      final MethodChannelSourceCheckNotification notification =
          MethodChannelSourceCheckNotification(
            logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
          );

      await notification.showProgress(
        text: _text,
        sourceName: '书源甲',
        completed: 3,
        total: 10,
      );

      expect(_calls, hasLength(1));
      expect(_calls.single.method, 'progress');
      expect(_calls.single.arguments, <String, Object?>{
        'channelName': '书源校验',
        'title': '正在校验书源',
        'text': '书源甲 · 3/10',
        'completed': 3,
        'total': 10,
      });
    });

    test('showFinished_givenTheVerdicts_sendsTheSummary', () async {
      _mockChannel();
      final MethodChannelSourceCheckNotification notification =
          MethodChannelSourceCheckNotification(
            logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
          );

      await notification.showFinished(text: _text, succeeded: 7, failed: 3);

      expect(_calls.single.method, 'finished');
      expect(_calls.single.arguments, <String, Object?>{
        'channelName': '书源校验',
        'title': '正在校验书源',
        'text': '成功 7，失败 3',
      });
    });

    test('cancel_givenAChannel_asksThePlatformToRemoveIt', () async {
      _mockChannel();
      final MethodChannelSourceCheckNotification notification =
          MethodChannelSourceCheckNotification(
            logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
          );

      await notification.cancel();

      expect(_calls.single.method, 'cancel');
      expect(_calls.single.arguments, isNull);
    });

    test('showProgress_givenAMissingPlugin_stopsWithoutThrowing', () async {
      // 未接通道（测试宿主 / 旧原生工程）：降级为「不支持」，之后不再打桥。
      final FakeLogPrinter printer = FakeLogPrinter();
      final MethodChannelSourceCheckNotification notification =
          MethodChannelSourceCheckNotification(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
          );

      await notification.showProgress(
        text: _text,
        sourceName: '甲',
        completed: 0,
        total: 1,
      );
      await notification.showFinished(text: _text, succeeded: 1, failed: 0);

      expect(_calls, isEmpty);
      expect(
        printer.events.map((LogEvent event) => event.level),
        contains(Level.debug),
      );
    });

    test('showProgress_givenAPlatformError_logsOnceAndStops', () async {
      _mockChannel(
        error: PlatformException(code: 'boom', message: 'no permission'),
      );
      final FakeLogPrinter printer = FakeLogPrinter();
      final MethodChannelSourceCheckNotification notification =
          MethodChannelSourceCheckNotification(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
          );

      await notification.showProgress(
        text: _text,
        sourceName: '甲',
        completed: 0,
        total: 1,
      );
      await notification.cancel();

      expect(_calls, hasLength(1));
      expect(
        printer.events
            .where((LogEvent event) => event.level == Level.warning)
            .map((LogEvent event) => event.message.toString()),
        anyElement(contains('source check notification failed')),
      );
    });
  });

  group('NoopSourceCheckNotification', () {
    test('everyCall_givenTheNoopPort_doesNothing', () async {
      const NoopSourceCheckNotification notification =
          NoopSourceCheckNotification();

      await notification.showProgress(
        text: _text,
        sourceName: '甲',
        completed: 1,
        total: 2,
      );
      await notification.showFinished(text: _text, succeeded: 1, failed: 1);
      await notification.cancel();

      expect(_calls, isEmpty);
    });
  });
}
