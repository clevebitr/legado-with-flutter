import 'package:flutter_reader/core/network/request_limiter.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppThemeMode', () {
    test('fromStorage_givenEachStoredValue_roundTrips', () {
      for (final AppThemeMode mode in AppThemeMode.values) {
        expect(AppThemeMode.fromStorage(mode.storageValue), mode);
      }
    });

    test('fromStorage_givenAnUnknownValue_answersSystem', () {
      // 更高版本写进来的值不能让 App 白屏：「跟随系统」是安全方向。
      expect(AppThemeMode.fromStorage(9), AppThemeMode.system);
    });
  });

  group('AppSettings', () {
    test('new_whenNothingIsGiven_usesTheDocumentedDefaults', () {
      final AppSettings settings = AppSettings();

      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.fontScale, 1);
      expect(
        settings.maxConcurrentPerSource,
        defaultMaxConcurrentRequestsPerSource,
      );
    });

    test('new_givenAZeroBudget_clampsToOne', () {
      // roadmap §3.7：`assert` 在 release 下会被剥掉，`0` 会让该源的请求永久排队，所以钳制发生
      // 在构造处（而且 release 里也生效）。
      expect(AppSettings(maxConcurrentPerSource: 0).maxConcurrentPerSource, 1);
      expect(AppSettings(maxConcurrentPerSource: -3).maxConcurrentPerSource, 1);
    });

    test('new_givenAHugeBudget_clampsToTheUpperBound', () {
      expect(
        AppSettings(maxConcurrentPerSource: 99).maxConcurrentPerSource,
        maxConcurrentBudget,
      );
    });

    test('new_givenAnOutOfRangeFontScale_clampsIt', () {
      expect(AppSettings(fontScale: 0.1).fontScale, minFontScale);
      expect(AppSettings(fontScale: 9).fontScale, maxFontScale);
    });

    test('copyWith_whenCalled_clampsTheSameWay', () {
      final AppSettings settings = AppSettings().copyWith(
        maxConcurrentPerSource: 0,
        fontScale: 99,
        themeMode: AppThemeMode.dark,
      );

      expect(settings.maxConcurrentPerSource, minConcurrentBudget);
      expect(settings.fontScale, maxFontScale);
      expect(settings.themeMode, AppThemeMode.dark);
    });

    test('copyWith_givenNoArguments_keepsEveryValue', () {
      final AppSettings settings = AppSettings(
        themeMode: AppThemeMode.light,
        fontScale: 1.5,
        maxConcurrentPerSource: 5,
      );

      expect(settings.copyWith(), settings);
    });

    test('equality_givenTheSameValues_holds', () {
      expect(AppSettings(fontScale: 1.2), AppSettings(fontScale: 1.2));
      expect(
        AppSettings(fontScale: 1.2).hashCode,
        AppSettings(fontScale: 1.2).hashCode,
      );
      expect(AppSettings(fontScale: 1.2), isNot(AppSettings(fontScale: 1.3)));
    });
  });
}
