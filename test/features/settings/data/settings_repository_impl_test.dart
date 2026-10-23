import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/settings/data/settings_repository_impl.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsRepositoryImpl', () {
    /// A repository on top of a store seeded with [values].
    Future<SettingsRepositoryImpl> repositoryWith(
      Map<String, Object> values,
    ) async {
      SharedPreferences.setMockInitialValues(values);

      return SettingsRepositoryImpl(
        store: PreferenceStore(await SharedPreferences.getInstance()),
      );
    }

    test('load_whenNothingIsStored_answersTheDefaults', () async {
      final SettingsRepositoryImpl repository = await repositoryWith(
        <String, Object>{},
      );

      expect(await repository.load(), AppSettings.defaults);
    });

    test('save_thenLoad_roundTripsEveryValue', () async {
      final SettingsRepositoryImpl repository = await repositoryWith(
        <String, Object>{},
      );
      final AppSettings settings = AppSettings(
        themeMode: AppThemeMode.dark,
        fontScale: 1.4,
        maxConcurrentPerSource: 6,
        allowPlainHttp: true,
      );

      await repository.save(settings);

      expect(await repository.load(), settings);
    });

    test('load_whenNothingIsStored_keepsPlainHttpOff', () async {
      final SettingsRepositoryImpl repository = await repositoryWith(
        <String, Object>{},
      );

      expect((await repository.load()).allowPlainHttp, isFalse);
    });

    test('save_givenAnOutOfRangeBudget_storesTheClampedValue', () async {
      // 存进去的永远是钳制后的值：界面与实际生效的策略不会分叉。
      final SettingsRepositoryImpl repository = await repositoryWith(
        <String, Object>{},
      );

      await repository.save(AppSettings(maxConcurrentPerSource: 0));

      expect((await repository.load()).maxConcurrentPerSource, 1);
    });

    test('load_givenGarbageValues_fallsBackPerSetting', () async {
      final SettingsRepositoryImpl repository = await repositoryWith(
        <String, Object>{
          'settings.themeMode': 'dark',
          'settings.fontScale': 'huge',
          'settings.maxConcurrentPerSource': 4.5,
        },
      );

      // 类型不对的键按「没存过」处理，其余键照常生效：一个坏键不该毁掉整页设置。
      expect(await repository.load(), AppSettings.defaults);
    });

    test('load_givenAStoredThemeOnly_keepsTheOtherDefaults', () async {
      final SettingsRepositoryImpl repository = await repositoryWith(
        <String, Object>{'settings.themeMode': 2},
      );

      final AppSettings settings = await repository.load();

      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.fontScale, 1);
      expect(
        settings.maxConcurrentPerSource,
        AppSettings.defaults.maxConcurrentPerSource,
      );
    });
  });
}
