import 'package:flutter_reader/core/platform/battery_level.dart';
import 'package:flutter_reader/core/platform/screen_awake.dart';

/// A [ScreenAwake] that records what the reader asked for.
final class FakeScreenAwake implements ScreenAwake {
  /// Creates the fake; [isSupported] is what the platform would answer.
  FakeScreenAwake({this.isSupported = true});

  @override
  final bool isSupported;

  /// Every value passed to [setAwake], in order.
  final List<bool> calls = <bool>[];

  /// The last value asked for, or `null` when nothing was asked yet.
  bool? get lastCall => calls.isEmpty ? null : calls.last;

  @override
  Future<void> setAwake({required bool awake}) async => calls.add(awake);
}

/// A [BatteryLevel] that answers a fixed charge.
final class FakeBatteryLevel implements BatteryLevel {
  /// Creates the fake; [level] `null` means “this platform does not know”.
  FakeBatteryLevel({this.level = 80, this.isSupported = true});

  /// The charge every [read] answers.
  int? level;

  @override
  bool isSupported;

  /// How many times [read] was called.
  int reads = 0;

  @override
  Future<int?> read() async {
    reads++;

    return level;
  }
}
