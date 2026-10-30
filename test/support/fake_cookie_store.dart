import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/cookie_store.dart';

/// In-memory [CookieStore] for tests that exercise the **real** cookie jar wiring.
///
/// `cookieStoreProvider` is the seam: overriding it keeps `PersistentCookieManager` (and therefore
/// the sandbox's `java.getCookie` / `cookie.*`) real while the database stays out of the test
/// (`docs/dev/testing.md` §4 — fake the collaborator, not the behaviour under test).
final class FakeCookieStore implements CookieStore {
  /// The rows the store currently holds, keyed by `domain|path|name`.
  final Map<String, StoredCookie> rows = <String, StoredCookie>{};

  @override
  Future<List<StoredCookie>> loadAll() async => rows.values.toList();

  @override
  Future<void> save(StoredCookie cookie) async {
    rows[_keyOf(cookie)] = cookie;
  }

  @override
  Future<void> remove(StoredCookie cookie) async {
    rows.remove(_keyOf(cookie));
  }

  @override
  Future<int> deleteExpired(DateTime now) async {
    final List<String> expired = <String>[
      for (final MapEntry<String, StoredCookie> row in rows.entries)
        if (row.value.isExpiredAt(now)) row.key,
    ];
    for (final String key in expired) {
      rows.remove(key);
    }

    return expired.length;
  }

  @override
  Future<int> deleteByDomain(String domain) async {
    final List<String> matching = <String>[
      for (final MapEntry<String, StoredCookie> row in rows.entries)
        if (row.value.domain == domain) row.key,
    ];
    for (final String key in matching) {
      rows.remove(key);
    }

    return matching.length;
  }

  @override
  Future<int> deleteAll() async {
    final int count = rows.length;
    rows.clear();

    return count;
  }

  static String _keyOf(StoredCookie cookie) =>
      '${cookie.domain}|${cookie.path}|${cookie.name}';
}
