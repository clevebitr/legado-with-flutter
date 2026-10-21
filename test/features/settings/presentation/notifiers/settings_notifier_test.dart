import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/settings/di.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_reader/features/settings/presentation/notifiers/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_settings_repository.dart';

void main() {
  group('Settings', () {
    late FakeSettingsRepository repository;
    late FakeCachePurger purger;
    late ProviderContainer container;

    setUp(() {
      repository = FakeSettingsRepository();
      purger = FakeCachePurger();
      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWith(
            (Ref ref) async => repository,
          ),
          cachePurgerProvider.overrideWithValue(purger),
        ],
      );
      addTearDown(container.dispose);
    });

    /// Reads the settings and returns them.
    Future<AppSettings> settle() => container.read(settingsProvider.future);

    test('build_whenNothingIsStored_answersTheDefaults', () async {
      expect(await settle(), AppSettings.defaults);
    });

    test('build_givenStoredValues_answersThem', () async {
      repository = FakeSettingsRepository(
        initial: AppSettings(
          themeMode: AppThemeMode.dark,
          fontScale: 1.3,
          maxConcurrentPerSource: 5,
        ),
      );
      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWith(
            (Ref ref) async => repository,
          ),
          cachePurgerProvider.overrideWithValue(purger),
        ],
      );
      addTearDown(container.dispose);

      expect((await settle()).themeMode, AppThemeMode.dark);
    });

    test('setThemeMode_whenCalled_storesAndPublishes', () async {
      await settle();

      await container
          .read(settingsProvider.notifier)
          .setThemeMode(AppThemeMode.light);

      expect(
        container.read(settingsProvider).value?.themeMode,
        AppThemeMode.light,
      );
      expect(repository.stored.themeMode, AppThemeMode.light);
    });

    test(
      'setFontScale_givenAnOutOfRangeValue_publishesTheClampedOne',
      () async {
        await settle();

        await container.read(settingsProvider.notifier).setFontScale(9);

        // 界面显示的就是存下去的值：钳制在 AppSettings 里，notifier 不再各写一份。
        expect(container.read(settingsProvider).value?.fontScale, maxFontScale);
        expect(repository.stored.fontScale, maxFontScale);
      },
    );

    test('setMaxConcurrentPerSource_givenZero_publishesTheFloor', () async {
      await settle();

      await container
          .read(settingsProvider.notifier)
          .setMaxConcurrentPerSource(0);

      expect(
        container.read(settingsProvider).value?.maxConcurrentPerSource,
        minConcurrentBudget,
      );
    });

    test('clearCache_whenThePurgeSucceeds_answersTheCount', () async {
      final ParseResult<int> result = await container
          .read(settingsProvider.notifier)
          .clearCache();

      expect(result, isA<ParseSuccess<int>>());
      expect((result as ParseSuccess<int>).data, 3);
      expect(purger.calls, 1);
    });

    test('clearCache_whenThePurgeThrows_answersAFailure', () async {
      purger.fail = true;

      final ParseResult<int> result = await container
          .read(settingsProvider.notifier)
          .clearCache();

      expect(result, isA<ParseFailure<int>>());
      expect((result as ParseFailure<int>).rulePath, 'cache.purgeAll');
    });

    test('build_whenTheStoreThrows_isAnErrorState', () async {
      repository.fail = true;

      // 仓储抛出的异常变成 AsyncError（页面据此显示「读取设置失败」而不是白屏）。
      // 必须先订阅：未监听的 keepAlive provider 不会被构建，`.future` 会一直挂着。
      final ProviderSubscription<AsyncValue<AppSettings>> subscription =
          container.listen(settingsProvider, (_, _) {});
      addTearDown(subscription.close);

      await Future<void>.delayed(Duration.zero);

      expect(container.read(settingsProvider).hasError, isTrue);
    });
  });
}
