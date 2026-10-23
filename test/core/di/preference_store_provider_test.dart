import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_log_printer.dart';

void main() {
  group('preferenceStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{'probe': 3});
    });

    test('preferenceStore_whenRead_opensThePlatformStoreOnce', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appLoggerProvider.overrideWithValue(
            AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final PreferenceStore store = await container.read(
        preferenceStoreProvider.future,
      );

      expect(store.readInt('probe'), 3);
      // keepAlive：第二次读拿到同一个实例，不会重新打开平台存储。
      expect(await container.read(preferenceStoreProvider.future), same(store));
    });
  });
}
