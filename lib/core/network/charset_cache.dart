import 'package:drift/drift.dart'
    show DriftWrappedException, InvalidDataException;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';
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
/// **The cache's failure surface is absorbed here, and only here.** C-ERR-2 allows an
/// `on Exception` clause in the `presentation/` Notifiers alone (ADR-0002's revision note),
/// and the request layer must not have to know what a database can throw, so this class
/// names the exceptions that losing a cache entry can produce — sqlite's [SqliteException]
/// and drift's [DriftRemoteException] / [InvalidDataException] / [DriftWrappedException] —
/// and answers “no cache” for them. `Error` stays uncaught, as ADR-0022 requires: a
/// programming bug must not be filed under “cache miss”.
///
/// **One [Exception] falls through to a last clause, by ruling (ADR-0033).** drift's
/// `ConnectionClosedException` (“the background isolate was closed”) is not exported by
/// drift 2.35.2, so it cannot be named, and letting it escape would break C-ERR-1 — a lost
/// cache entry must never fail a page. ADR-0033 pins that exemption to this one method,
/// keeps `Error` out of it, and requires it to be deleted the moment drift exports the
/// type enough to write a named clause instead.
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

  /// Runs one cache operation and turns the database's failure surface into “no cache”.
  ///
  /// A lost entry costs a sniff, never a page, so the failure is recorded at `debug` level
  /// (with the URL's digest and the error's digest, C-SEC-4) and reported as a miss.
  Future<T?> _absorb<T>(
    Future<T> Function() operation, {
    required String url,
  }) async {
    try {
      return await operation();
    } on SqliteException catch (error, stackTrace) {
      _report(error, stackTrace, url);
    } on DriftRemoteException catch (error, stackTrace) {
      _report(error, stackTrace, url);
    } on DriftWrappedException catch (error, stackTrace) {
      _report(error, stackTrace, url);
    } on InvalidDataException catch (error, stackTrace) {
      _report(error, stackTrace, url);
    } on Exception catch (error, stackTrace) {
      // ADR-0033 钉下的唯一豁免：drift 的 `ConnectionClosedException`（后台 isolate 被关闭）
      // 在 2.35.2 里没有公开导出，点不到名；放它逃出去就会让缓存这条旁路失败变成页面请求抛
      // 异常（C-ERR-1）。豁免只限本方法、只限 `Exception`（`Error` 仍然原样向上，ADR-0022），
      // 且 drift 一旦导出该类型就必须换回具名 catch、删掉这一支。
      _report(error, stackTrace, url);
    }

    return null;
  }

  /// Records one absorbed cache failure; never a page body, never a cleartext URL.
  void _report(Object error, StackTrace stackTrace, String url) {
    _logger.debug(
      'Charset cache unavailable: url=${redactUrl(url)}',
      describeError(error),
      stackTrace,
    );
  }
}
