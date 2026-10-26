import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';

/// The platform channel the Android side implements (`MainActivity.kt`).
const String longRunningTaskChannelName = 'flutter_reader/long_running_task';

/// Keeps the device working while a long task runs.
///
/// Platforms without support answer [isSupported] `false` instead of throwing, and both calls are
/// idempotent.
abstract interface class LongRunningTask {
  /// Whether this platform can actually keep the device awake.
  bool get isSupported;

  /// Asks the platform to keep the device awake; safe to call more than once.
  Future<void> acquire();

  /// Gives the marker back; safe to call more than once.
  Future<void> release();
}

/// The no-op [LongRunningTask] for platforms without one (Windows, iOS, tests).
final class UnsupportedLongRunningTask implements LongRunningTask {
  /// Creates the no-op port.
  const UnsupportedLongRunningTask();

  @override
  bool get isSupported => false;

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

/// Android [LongRunningTask] backed by a `PARTIAL_WAKE_LOCK` in `MainActivity`.
final class MethodChannelLongRunningTask implements LongRunningTask {
  /// Creates the channel-backed port.
  MethodChannelLongRunningTask({required this._logger, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(longRunningTaskChannelName);

  final AppLogger _logger;
  final MethodChannel _channel;

  // 平台一旦表示做不到就置为 false，后续调用直接跳过。
  bool _isSupported = true;

  @override
  bool get isSupported => _isSupported;

  @override
  Future<void> acquire() => _invoke('acquire');

  @override
  Future<void> release() => _invoke('release');

  // 缺失或失败的原生实现降级为 no-op，不让「检查书源」因此崩溃。
  Future<void> _invoke(String method) async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // 通道没接（测试宿主 / 未重新构建的原生工程）：降级为「不支持」，只记一次。
      _isSupported = false;
      _logger.debug('LongRunningTask is not implemented on this platform.');
    } on PlatformException catch (error, stackTrace) {
      _isSupported = false;
      _logger.warning(
        'LongRunningTask.$method failed; the task keeps running without it.',
        error,
        stackTrace,
      );
    }
  }
}
