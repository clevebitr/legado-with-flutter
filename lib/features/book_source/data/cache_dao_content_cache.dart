import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/cache_failure_absorber.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';

/// [ContentCache] backed by the app's TTL cache ([CacheDao]) — no new column, no new table.
///
/// It reuses the DAO's stable key with `ruleField` fixed to `content` and `page` fixed to 1, so one
/// chapter is one entry, and stores [chapterCacheTtl] as the expiry. The failure surface is
/// absorbed by [absorbCacheFailure] — the app's single absorption point (ADR-0033) — so this
/// adapter never throws: a lost entry is a miss that costs one request.
final class CacheDaoContentCache implements ContentCache {
  /// Creates the cache on top of the app's TTL cache.
  const CacheDaoContentCache(this._dao, {required this._logger});

  final CacheDao _dao;
  final AppLogger _logger;

  /// The `ruleField` part of the DAO's key: one chapter body, not a page of one.
  static const String _ruleField = 'content';

  /// The `page` part of the DAO's key; a chapter is one entry, so it is always 1.
  static const int _page = 1;

  @override
  Future<String?> read({required String sourceId, required String url}) =>
      absorbCacheFailure<String?>(
        () => _dao.get(
          sourceId: sourceId,
          ruleField: _ruleField,
          url: url,
          page: _page,
        ),
        logger: _logger,
        scope: 'Chapter cache',
        url: url,
      );

  @override
  Future<void> write({
    required String sourceId,
    required String url,
    required String body,
  }) async {
    await absorbCacheFailure(
      () async {
        await _dao.put(
          sourceId: sourceId,
          ruleField: _ruleField,
          url: url,
          page: _page,
          payload: body,
          ttl: chapterCacheTtl,
        );

        return true;
      },
      logger: _logger,
      scope: 'Chapter cache',
      url: url,
    );
  }
}
