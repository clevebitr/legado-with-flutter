import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/cookie_store.dart';
import 'package:flutter_reader/core/storage/cache_failure_absorber.dart';
import 'package:flutter_reader/core/storage/cookie_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';

/// [CookieStore] backed by the app database's `cookies` table.
///
/// Every operation goes through [absorbCacheFailure]: a lost cookie costs one re-login.
final class CookieDaoStore implements CookieStore {
  /// Creates the store.
  const CookieDaoStore(this._dao, {required this._logger});

  final CookieDao _dao;
  final AppLogger _logger;

  // 稳定字符串，便于在日志中检索。
  static const String _scope = 'Cookie jar';

  @override
  Future<List<StoredCookie>> loadAll() async {
    final List<CookieRow>? rows = await absorbCacheFailure<List<CookieRow>>(
      _dao.findAll,
      logger: _logger,
      scope: _scope,
      url: 'cookies',
    );

    return <StoredCookie>[
      for (final CookieRow row in rows ?? const <CookieRow>[])
        StoredCookie(
          name: row.name,
          value: row.value,
          domain: row.domain,
          path: row.path,
          isSecure: row.isSecure,
          isDeletion: false,
          expiresAt: row.expiresAt,
        ),
    ];
  }

  @override
  Future<void> save(StoredCookie cookie) async {
    await absorbCacheFailure<bool>(
      () async {
        await _dao.upsert(
          domain: cookie.domain,
          path: cookie.path,
          name: cookie.name,
          value: cookie.value,
          isSecure: cookie.isSecure,
          expiresAt: cookie.expiresAt,
        );

        return true;
      },
      logger: _logger,
      scope: _scope,
      url: cookie.domain,
    );
  }

  @override
  Future<void> remove(StoredCookie cookie) async {
    await absorbCacheFailure<bool>(
      () async {
        await _dao.deleteOne(
          domain: cookie.domain,
          path: cookie.path,
          name: cookie.name,
        );

        return true;
      },
      logger: _logger,
      scope: _scope,
      url: cookie.domain,
    );
  }

  @override
  Future<int> deleteExpired(DateTime now) async {
    final int? removed = await absorbCacheFailure<int>(
      () => _dao.deleteExpired(now),
      logger: _logger,
      scope: _scope,
      url: 'cookies',
    );

    return removed ?? 0;
  }
}
