import 'package:flutter_reader/core/storage/cache_dao.dart';

/// How long one detection result stays usable (`docs/dev/book-source.md` §5).
///
/// The label a site encodes a URL with almost never changes, so the only reason to expire
/// the entry at all is a site that fixes a wrong declaration: a week keeps the sniffing win
/// while letting such a fix take effect. The cache key and the expiry column belong to
/// [CacheDao] (C-NET-6); this is the number that goes into it, defined once here.
const Duration defaultCharsetCacheTtl = Duration(days: 7);

/// Remembers the charset **detection** result of one book source and URL
/// (`docs/dev/book-source.md` §5, C-NET-6).
///
/// Only the sniffed lane is cached: a declared charset is read from the response itself on
/// every request, so it needs no cache and keeps winning over a cached label — which is
/// what keeps ADR-0031's two lanes stable. A cache miss and a cache failure are the same
/// thing to a caller: sniff again.
abstract interface class CharsetCache {
  /// The charset detected for ([sourceId], [url]) earlier, or `null`.
  ///
  /// [sourceId] is the book source URL, and [ruleField] / [page] are the rest of
  /// [CacheDao]'s stable key. A page that is not tied to a book source cannot be cached
  /// at all, which is why the caller passes `null` [sourceId] through as a miss.
  Future<String?> read({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
  });

  /// Stores the charset detected for ([sourceId], [url]) with [defaultCharsetCacheTtl].
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
/// It reuses the DAO's stable key and expiry column — no new column, no new table — so the
/// first production consumer of `CacheDao` is also the one that proves the key shape works
/// for something other than a page payload.
final class CacheDaoCharsetCache implements CharsetCache {
  /// Creates the cache on top of the app's TTL cache.
  const CacheDaoCharsetCache(this._dao);

  final CacheDao _dao;

  @override
  Future<String?> read({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
  }) =>
      _dao.get(sourceId: sourceId, ruleField: ruleField, url: url, page: page);

  @override
  Future<void> write({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
    required String charset,
  }) => _dao.put(
    sourceId: sourceId,
    ruleField: ruleField,
    url: url,
    page: page,
    payload: charset,
    ttl: defaultCharsetCacheTtl,
  );
}
