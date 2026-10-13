import 'package:flutter_reader/core/utils/clock.dart';

/// Movable [Clock] for tests that must move time instead of waiting for it.
///
/// `docs/dev/testing.md` §4 forbids `sleep` in tests and requires an injectable time
/// source, and the rate window of `book-source.md` §8 is measured in wall-clock
/// milliseconds: a test therefore hands the limiter this clock plus a delay function that
/// advances it, and asserts on the waits instead of experiencing them.
final class FakeClock implements Clock {
  /// Creates a clock starting at [start], or at the epoch.
  FakeClock({DateTime? start})
    : _now = start ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  DateTime _now;

  /// The moment the clock currently reads.
  @override
  DateTime now() => _now;

  /// Moves the clock forward by [duration].
  void advance(Duration duration) => _now = _now.add(duration);
}
