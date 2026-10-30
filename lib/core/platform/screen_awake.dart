import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';

/// The platform channel the Android side implements (`MainActivity.kt`).
const String screenAwakeChannelName = 'flutter_reader/screen_awake';

/// Keeps the display on while the reader is open.
///
/// Upstream holds `FLAG_KEEP_SCREEN_ON` on the reader window (`ReadBookController.kt:335/466`;
/// recorded in `docs/dev/adr/0086-reader-comfort-and-status-bar.md`). A reading session is
/// minutes of *no* touch input, which is exactly what the platform's screen timeout is for, so
/// without this the reader goes dark every 30 seconds.
///
/// Platforms without support answer [isSupported] `false` instead of throwing, and both calls are
/// idempotent.
abstract interface class ScreenAwake {
  /// Whether this platform can actually keep the display on.
  bool get isSupported;

  /// Asks the platform to keep the display on ([awake]) or to let it sleep again.
  Future<void> setAwake({required bool awake});
}

/// The no-op [ScreenAwake] for platforms without one (Windows, iOS, tests).
final class UnsupportedScreenAwake implements ScreenAwake {
  /// Creates the no-op port.
  const UnsupportedScreenAwake();

  @override
  bool get isSupported => false;

  @override
  Future<void> setAwake({required bool awake}) async {}
}

/// Android [ScreenAwake] backed by the activity's window flags in `MainActivity`.
final class MethodChannelScreenAwake implements ScreenAwake {
  /// Creates the channel-backed port.
  MethodChannelScreenAwake({required this._logger, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(screenAwakeChannelName);

  final AppLogger _logger;
  final MethodChannel _channel;

  // 平台一旦表示做不到就置为 false，后续调用直接跳过。
  bool _isSupported = true;

  @override
  bool get isSupported => _isSupported;

  @override
  Future<void> setAwake({required bool awake}) async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setAwake', <String, Object?>{
        'awake': awake,
      });
    } on MissingPluginException {
      // 通道没接（测试宿主 / 未重新构建的原生工程）：降级为「不支持」，只记一次。
      _isSupported = false;
      _logger.debug('ScreenAwake is not implemented on this platform.');
    } on PlatformException catch (error, stackTrace) {
      _isSupported = false;
      _logger.warning(
        'ScreenAwake.setAwake failed; the display may sleep while reading.',
        error,
        stackTrace,
      );
    }
  }
}
