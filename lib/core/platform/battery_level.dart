import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';

/// The platform channel the Android side implements (`MainActivity.kt`).
const String batteryLevelChannelName = 'flutter_reader/battery';

/// Reads the device's charge level for the reader's status line.
///
/// The reading view shows the time and the battery the way upstream's configurable header does
/// (`BgTextConfigSheet.kt`, recorded in `docs/dev/adr/0086-reader-comfort-and-status-bar.md`); on
/// platforms that cannot answer, [read] answers `null` and the status line simply leaves it out
/// instead of inventing a value (C-UI-7: no placeholder text that pretends to be data).
abstract interface class BatteryLevel {
  /// Whether this platform can report a level.
  bool get isSupported;

  /// The current charge percentage, 0–100, or `null` when the platform does not know.
  Future<int?> read();
}

/// The no-op [BatteryLevel] for platforms without one (Windows, iOS, tests).
final class UnsupportedBatteryLevel implements BatteryLevel {
  /// Creates the no-op port.
  const UnsupportedBatteryLevel();

  @override
  bool get isSupported => false;

  @override
  Future<int?> read() async => null;
}

/// Android [BatteryLevel] backed by `BatteryManager` in `MainActivity`.
final class MethodChannelBatteryLevel implements BatteryLevel {
  /// Creates the channel-backed port.
  MethodChannelBatteryLevel({required this._logger, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(batteryLevelChannelName);

  final AppLogger _logger;
  final MethodChannel _channel;

  // 平台一旦表示读不到就置为 false，后续调用直接跳过。
  bool _isSupported = true;

  @override
  bool get isSupported => _isSupported;

  @override
  Future<int?> read() async {
    if (!_isSupported) {
      return null;
    }

    try {
      final int? level = await _channel.invokeMethod<int>('level');
      if (level == null) {
        _isSupported = false;

        return null;
      }

      // 原生侧给的是 0–100；越界的值只可能是原生 bug，钳制而不是画一条错进度。
      return level.clamp(0, 100);
    } on MissingPluginException {
      _isSupported = false;
      _logger.debug('BatteryLevel is not implemented on this platform.');

      return null;
    } on PlatformException catch (error, stackTrace) {
      _isSupported = false;
      _logger.warning(
        'BatteryLevel.read failed; the status line omits the charge.',
        error,
        stackTrace,
      );

      return null;
    }
  }
}
