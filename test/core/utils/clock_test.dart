import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemClock', () {
    test('SystemClock_whenRead_returnsAnInstantBetweenTheSurroundingCalls', () {
      final DateTime before = DateTime.now();
      final DateTime now = const SystemClock().now();
      final DateTime after = DateTime.now();

      expect(now.isBefore(before), isFalse);
      expect(now.isAfter(after), isFalse);
    });
  });
}
