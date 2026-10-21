// coverage:ignore-file
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';

/// Persistence for the light switches (`docs/dev/roadmap.md` 5.6, C-NET-9).
///
/// The port is total: a missing or corrupt stored value is answered with the default rather than
/// a failure, because "the app still starts with its defaults" is the whole point of these
/// settings. Unexpected storage failures travel to the `presentation` Notifier, the layer C-ERR-2
/// lets catch `Exception`.
///
/// 本文件只有抽象方法签名（无可测量行），已按 ADR-0019 §2 登记在 `tool/coverage_allowlist.txt`；
/// 契约由 `SettingsRepositoryImpl` 与其测试行使。
abstract interface class SettingsRepository {
  /// The stored settings, clamped into their documented ranges.
  Future<AppSettings> load();

  /// Stores [settings]; a partial write leaves the stored file consistent because every key is
  /// independent and read back on the next load.
  Future<void> save(AppSettings settings);
}

/// Empties the cache tables (C-NET-6, `docs/dev/roadmap.md` 5.7 ①).
///
/// It lives behind a port so the settings feature never touches `CacheDao` (a `core/storage`
/// Drift DAO) and so a test can assert the count that reaches the snackbar.
abstract interface class CachePurger {
  /// Deletes every cached entry and returns how many rows went away.
  Future<int> purgeAll();
}
