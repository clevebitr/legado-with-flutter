import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  group('clock', () {
    test('clock_whenRead_returnsTheSystemClock', () {
      final ProviderContainer container = ProviderContainer.test();

      expect(container.read(clockProvider), isA<SystemClock>());
    });
  });
}
