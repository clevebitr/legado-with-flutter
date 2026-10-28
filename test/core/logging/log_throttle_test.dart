import 'package:flutter_reader/core/logging/log_throttle.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// A clock a test moves by hand.
final class _FakeClock implements Clock {
  DateTime current = DateTime.utc(2026, 10, 28, 15);

  @override
  DateTime now() => current;

  void advance(Duration duration) => current = current.add(duration);
}

void main() {
  group('LogThrottle', () {
    test('admit_givenTheFirstKey_writesItWithNoSuppressedCount', () {
      final _FakeClock clock = _FakeClock();
      final LogThrottle throttle = LogThrottle(clock: clock);

      expect(throttle.admit('a'), 0);
    });

    test('admit_givenTheSameKeyInsideTheWindow_suppressesIt', () {
      final _FakeClock clock = _FakeClock();
      final LogThrottle throttle = LogThrottle(clock: clock);

      expect(throttle.admit('a'), 0);
      clock.advance(const Duration(seconds: 30));
      expect(throttle.admit('a'), isNull);
      expect(throttle.admit('a'), isNull);
      // 窗口过去后的第一条要带上被压掉的条数。
      clock.advance(const Duration(seconds: 31));
      expect(throttle.admit('a'), 2);
    });

    test('admit_givenDistinctKeys_keepsTheirWindowsApart', () {
      final _FakeClock clock = _FakeClock();
      final LogThrottle throttle = LogThrottle(clock: clock);

      expect(throttle.admit('a'), 0);
      expect(throttle.admit('b'), 0);
      clock.advance(const Duration(seconds: 10));
      expect(throttle.admit('a'), isNull);
      // 被压掉之后再写 b，`a` 的 suppressed 不应混进 `b` 的计数。
      expect(throttle.admit('b'), isNull);
      clock.advance(const Duration(minutes: 1));
      expect(throttle.admit('a'), 1);
      expect(throttle.admit('b'), 1);
    });

    test('admit_givenMoreKeysThanTheCapacity_forgetsTheOldest', () {
      final _FakeClock clock = _FakeClock();
      final LogThrottle throttle = LogThrottle(clock: clock, capacity: 2);

      throttle.admit('a');
      throttle.admit('b');
      throttle.admit('c');
      // `a` 已被淘汰，所以它重新写入时 counts 从 0 开始。
      expect(throttle.admit('a'), 0);
    });
  });
}
