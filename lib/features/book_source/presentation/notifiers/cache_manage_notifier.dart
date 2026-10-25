import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cache_manage_notifier.g.dart';

/// One row of the cache page: a source and how many cached chapters belong to it
/// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 1).
///
/// A record rather than an entity: it is a projection of two readers (the source list and the cache
/// counts) for exactly one page, and nothing else in the app has a use for it.
typedef CacheSourceUsage = ({int id, String name, String url, int count});

/// What the cache page shows.
typedef CacheUsage = ({int total, List<CacheSourceUsage> sources});

/// Reads and clears the cache per book source (`docs/dev/roadmap.md` M22, ADR-0072 §决策 1).
///
/// Every action reloads: the counts are the answer, so showing a stale one after a clear would be
/// the one thing this page must not do.
@riverpod
class CacheManage extends _$CacheManage {
  @override
  Future<CacheUsage> build() async {
    final BookSourceRepository repository = ref.watch(
      bookSourceRepositoryProvider,
    );
    final ContentCache cache = ref.watch(contentCacheProvider);
    final List<StoredBookSource> sources = await repository.getAll();
    final List<CacheSourceUsage> usages = <CacheSourceUsage>[
      for (final StoredBookSource source in sources)
        (
          id: source.id,
          name: source.source.name,
          url: source.source.url,
          count: await cache.countForSource(source.source.url),
        ),
    ];

    return (total: await cache.countAll(), sources: usages);
  }

  /// Drops one source's cached chapters.
  Future<void> clearSource(String sourceId) =>
      _apply((ContentCache cache) => cache.clearForSource(sourceId));

  /// Drops every entry whose TTL has passed.
  Future<void> clearExpired() =>
      _apply((ContentCache cache) => cache.clearExpired());

  /// Drops the whole cache.
  Future<void> clearAll() async {
    await _apply((ContentCache cache) => cache.clearAll());
  }

  Future<void> _apply(
    Future<Object?> Function(ContentCache cache) clear,
  ) async {
    final ContentCache cache = ref.read(contentCacheProvider);

    try {
      await clear(cache);
    } on Exception catch (error, stackTrace) {
      // C-ERR-2 的 presentation 兜底：删不掉不该把页面变成错误态，计数重读后照旧显示真相。
      ref
          .read(appLoggerProvider)
          .warning('Clearing the cache failed.', error, stackTrace);
    }

    state = await AsyncValue.guard<CacheUsage>(build);
  }
}
