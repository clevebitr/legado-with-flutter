import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  test('appLogger_whenNoLogLevelIsDefined_usesTheInfoDefault', () {
    final AppLogger logger = ProviderContainer.test().read(appLoggerProvider);

    expect(logger, isA<AppLogger>());
    expect(logger.level, LogLevel.info);
  });
}
