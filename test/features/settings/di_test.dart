import 'package:drift/native.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/settings/data/cache_dao_cache_purger.dart';
import 'package:flutter_reader/features/settings/data/settings_repository_impl.dart';
import 'package:flutter_reader/features/settings/di.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('settingsRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('settingsRepository_whenRead_wiresThePreferenceStore', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(settingsRepositoryProvider.future),
        isA<SettingsRepositoryImpl>(),
      );
      expect(
        await container.read(preferenceStoreProvider.future),
        isA<PreferenceStore>(),
      );
    });
  });

  group('cachePurger', () {
    test('cachePurger_whenRead_wiresTheCacheDao', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          databaseExecutorProvider.overrideWithValue(NativeDatabase.memory()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(cachePurgerProvider), isA<CacheDaoCachePurger>());
    });
  });
}
