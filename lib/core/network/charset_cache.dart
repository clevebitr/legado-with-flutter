import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/cache_failure_absorber.dart';

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
/// what keeps ADR-0031's two lanes stable.
///
/// **The port is total.** A miss, a failure and “this page has no cacheable identity” are
/// one answer: [read] returns `null` and [write] does nothing, and neither ever throws. The
/// implementation absorbs its own failure surface (see [CacheDaoCharsetCache]); that is why
/// the request layer can call this without a `try`, and why `core/network`'s request path
/// needs no exception boundary of its own (C-ERR-2).
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
///
/// **The failure surface is absorbed by [absorbCacheFailure]**, the app's single absorption
/// point (ADR-0033, whose revision note moved the exemption there when the chapter cache
/// arrived): the request layer therefore never has to know what a database can throw, and a
/// lost entry is a miss instead of an exception (C-ERR-1).
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

  /// Runs one cache operation through the shared absorber; a lost entry costs a sniff, not a page.
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
