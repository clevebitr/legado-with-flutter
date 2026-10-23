import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';

/// The platform channel the Android side implements (`MainActivity.kt`).
const String longRunningTaskChannelName = 'flutter_reader/long_running_task';

/// Keeps the device working while a long task runs (`docs/dev/platform.md` §2, ADR-0043 §决策 3).
///
/// A batch book-source check can take minutes and is worthless if the OS suspends it half way, so
/// the batch asks for a "keep working" marker at the start and drops it at the end.
///
/// Contract, the same as every other platform port in `core/platform/`:
///
/// * a platform that cannot do it answers with [isSupported] `false` and no-ops — **it never
///   throws**, and a caller must treat `false` as a normal branch (C-PLT-1, `platform.md` §2);
/// * both calls are **idempotent**, because a batch may stop without ever starting, and a release
///   without an acquire must not be an error.
abstract interface class LongRunningTask {
  /// Whether this platform can actually keep the device awake.
  bool get isSupported;

  /// Asks the platform to keep the device awake; safe to call more than once.
  Future<void> acquire();

  /// Gives the marker back; safe to call more than once.
  Future<void> release();
}

/// The no-op [LongRunningTask] for platforms without one (Windows, iOS, tests).
///
/// It is the **normal** branch, not an error: nothing on those platforms can be suspended between
/// requests the way Android suspends a backgrounded app.
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
///
/// The channel methods are `acquire` / `release`, and the native side keeps one wake lock per
/// activity (released in `onDestroy` too, so a crash cannot leak it).
///
/// A missing plugin or a platform error **degrades instead of throwing**: Android without the
/// channel (a test host, an older build) must not turn "check a source" into a crash, so the port
/// flips [isSupported] to `false` and says so once in the log.
final class MethodChannelLongRunningTask implements LongRunningTask {
  /// Creates the channel-backed port.
  MethodChannelLongRunningTask({required this._logger, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(longRunningTaskChannelName);

  final AppLogger _logger;
  final MethodChannel _channel;

  /// `false` as soon as the platform said it cannot do this.
  bool _isSupported = true;

  @override
  bool get isSupported => _isSupported;

  @override
  Future<void> acquire() => _invoke('acquire');

  @override
  Future<void> release() => _invoke('release');

  /// Calls [method] on the channel, turning a missing or failing implementation into a no-op.
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
