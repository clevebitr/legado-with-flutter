import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/features/settings/data/cache_dao_cache_purger.dart';
import 'package:flutter_reader/features/settings/data/settings_repository_impl.dart';
import 'package:flutter_reader/features/settings/domain/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides the settings persistence (`docs/dev/roadmap.md` 5.6)。
@Riverpod(keepAlive: true)
Future<SettingsRepository> settingsRepository(Ref ref) async =>
    SettingsRepositoryImpl(
      store: await ref.watch(preferenceStoreProvider.future),
    );

/// Provides the cache purge the settings page offers (`docs/dev/roadmap.md` 5.7 ①)。
@Riverpod(keepAlive: true)
CachePurger cachePurger(Ref ref) =>
    CacheDaoCachePurger(ref.watch(cacheDaoProvider));
