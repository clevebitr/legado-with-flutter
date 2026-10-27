import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/request_limiter.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_reader/features/settings/domain/repositories/settings_repository.dart';

/// `shared_preferences` key of the theme mode.
///
/// Keys are private to this file: the storage layout is an implementation detail, and a key
/// spelled anywhere else would be a second source for it (`docs/dev/roadmap.md` §6 #9).
const String _themeModeKey = 'settings.themeMode';

/// `shared_preferences` key of the default text scale.
const String _fontScaleKey = 'settings.fontScale';

/// `shared_preferences` key of the per-source concurrency budget.
const String _concurrencyKey = 'settings.maxConcurrentPerSource';

/// `shared_preferences` key of the plaintext-HTTP opt-in.
const String _plainHttpKey = 'settings.allowPlainHttp';

/// `shared_preferences` key of the theme seed colour (ARGB int, `ADR-0075` §决策 1).
const String _seedColorKey = 'settings.seedColor';

/// `shared_preferences` key of the theme background file name (`ADR-0075` §决策 1).
const String _backgroundImageKey = 'settings.backgroundImage';

/// `shared_preferences` key of the log level (`ADR-0082`).
const String _logLevelKey = 'settings.logLevel';

/// [SettingsRepository] on top of [PreferenceStore] (`docs/dev/roadmap.md` 5.6, C-NET-9).
///
/// Every read is defensive: a value written by an older build, a hand-edited store or a wrong
/// type falls back to the default of that one setting instead of failing the whole load. The
/// clamping itself happens in [AppSettings], so this class only translates.
final class SettingsRepositoryImpl implements SettingsRepository {
  /// Creates the repository.
  const SettingsRepositoryImpl({required this._store});

  final PreferenceStore _store;

  @override
  Future<AppSettings> load() async {
    final int? storedTheme = _store.readInt(_themeModeKey);
    final double? storedFontScale = _store.readDouble(_fontScaleKey);
    final int? storedConcurrency = _store.readInt(_concurrencyKey);
    final bool? storedPlainHttp = _store.readBool(_plainHttpKey);
    final int? storedSeedColor = _store.readInt(_seedColorKey);
    final String? storedBackgroundImage = _store.readString(
      _backgroundImageKey,
    );
    final String? storedLogLevel = _store.readString(_logLevelKey);

    return AppSettings(
      themeMode: storedTheme == null
          ? AppThemeMode.system
          : AppThemeMode.fromStorage(storedTheme),
      fontScale: storedFontScale ?? 1,
      maxConcurrentPerSource:
          storedConcurrency ?? defaultMaxConcurrentRequestsPerSource,
      allowPlainHttp: storedPlainHttp ?? false,
      seedColor: storedSeedColor,
      backgroundImageName: storedBackgroundImage,
      logLevel: storedLogLevel == null
          ? defaultLogLevel
          : LogLevel.parse(storedLogLevel),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    // 存的是**钳制后**的值：读回来的永远是 UI 能表示的范围，界面与实际生效的策略不会分叉。
    await _store.writeInt(_themeModeKey, settings.themeMode.storageValue);
    await _store.writeDouble(_fontScaleKey, settings.fontScale);
    await _store.writeInt(_concurrencyKey, settings.maxConcurrentPerSource);
    await _store.writeBool(_plainHttpKey, settings.allowPlainHttp);
    await _store.writeString(_logLevelKey, settings.logLevel.name);
    if (settings.seedColor case final int seed) {
      await _store.writeInt(_seedColorKey, seed);
    } else {
      await _store.remove(_seedColorKey);
    }
    if (settings.backgroundImageName case final String name) {
      await _store.writeString(_backgroundImageKey, name);
    } else {
      await _store.remove(_backgroundImageKey);
    }
  }
}
