import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  group('appLogger', () {
    test('appLogger_whenNoLogLevelIsDefined_usesTheInfoDefault', () {
      final ProviderContainer container = ProviderContainer.test();

      expect(container.read(appLoggerProvider), isA<AppLogger>());
      expect(container.read(appLoggerProvider).level, LogLevel.info);
    });

    test('appLogger_whenOverridden_returnsTheInjectedLogger', () {
      final AppLogger injected = AppLogger(level: LogLevel.debug);
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[appLoggerProvider.overrideWithValue(injected)],
      );

      expect(container.read(appLoggerProvider), same(injected));
    });
  });
}
