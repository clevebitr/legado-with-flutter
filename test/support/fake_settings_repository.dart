import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/repositories/settings_repository.dart';

/// In-memory [SettingsRepository] for tests (`docs/dev/testing.md` §4).
///
/// It keeps the **clamped** value it was handed, exactly like the real implementation: a test
/// that asks for a `0` budget and then reads it back must see the floor, not the request.
final class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({AppSettings? initial})
    : _settings = initial ?? AppSettings.defaults;

  AppSettings _settings;

  /// Whether [load] and [save] throw (the C-ERR-2 boundary case).
  bool fail = false;

  /// The stored settings, for assertions.
  AppSettings get stored => _settings;

  @override
  Future<AppSettings> load() async {
    if (fail) {
      throw Exception('the settings store is unavailable');
    }

    return _settings;
  }

  @override
  Future<void> save(AppSettings settings) async {
    if (fail) {
      throw Exception('the settings store is unavailable');
    }
    _settings = settings;
  }
}

/// In-memory [CachePurger] that reports how many entries it pretended to remove.
final class FakeCachePurger implements CachePurger {
  /// Creates the purger; [removed] is what [purgeAll] reports.
  FakeCachePurger({this.removed = 3});

  /// The count the next purge answers with.
  int removed;

  /// Whether [purgeAll] throws (the C-ERR-2 boundary case).
  bool fail = false;

  /// How often [purgeAll] ran.
  int calls = 0;

  @override
  Future<int> purgeAll() async {
    calls++;
    if (fail) {
      throw Exception('the cache table is unavailable');
    }

    return removed;
  }
}
