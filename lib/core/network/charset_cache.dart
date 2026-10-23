import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/cache_failure_absorber.dart';

/// How long one detection result stays usable.
const Duration defaultCharsetCacheTtl = Duration(days: 7);

/// Remembers the detected charset of one page.
///
/// Never throws: a miss and a storage failure both come back as `null` / a silent no-op.
abstract interface class CharsetCache {
  /// The charset detected earlier for ([sourceId], [url]), or `null`.
  Future<String?> read({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
  });

  /// Stores [charset] for ([sourceId], [url]) with [defaultCharsetCacheTtl].
  Future<void> write({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
    required String charset,
  });
}

/// [CharsetCache] backed by the app's TTL cache ([CacheDao]).
///
/// Storage failures are absorbed and reported as a miss.
final class CacheDaoCharsetCache implements CharsetCache {
  /// Creates the cache on top of the app's TTL cache.
  const CacheDaoCharsetCache(this._dao, {required this._logger});

  final CacheDao _dao;
  final AppLogger _logger;

  @override
  Future<String?> read({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
  }) => _absorb<String?>(
    () => _dao.get(
      sourceId: sourceId,
      ruleField: ruleField,
      url: url,
      page: page,
    ),
    url: url,
  );

  @override
  Future<void> write({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
    required String charset,
  }) async {
    await _absorb(() async {
      await _dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: url,
        page: page,
        payload: charset,
        ttl: defaultCharsetCacheTtl,
      );

      return true;
    }, url: url);
  }

  // 失败按未命中处理：丢一条缓存只多嗅探一次。
  Future<T?> _absorb<T>(
    Future<T> Function() operation, {
    required String url,
  }) => absorbCacheFailure(
    operation,
    logger: _logger,
    scope: 'Charset cache',
    url: url,
  );
}
