import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/cookie_store.dart';
import 'package:flutter_reader/core/network/persistent_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_log_printer.dart';

/// In-memory [CookieStore] that records what the manager wrote (`docs/dev/testing.md` §4).
final class _FakeStore implements CookieStore {
  /// The rows the store currently holds, keyed by `domain|path|name`.
  final Map<String, StoredCookie> rows = <String, StoredCookie>{};

  /// Every saved cookie, in order.
  final List<StoredCookie> saved = <StoredCookie>[];

  /// Every removed cookie, in order.
  final List<StoredCookie> removed = <StoredCookie>[];

  /// The `now` values [deleteExpired] was called with.
  final List<DateTime> purgedAt = <DateTime>[];

  /// When set, [loadAll] answers it instead of [rows] (a corrupted jar).
  List<StoredCookie>? loadOverride;

  @override
  Future<List<StoredCookie>> loadAll() async =>
      loadOverride ?? rows.values.toList();

  @override
  Future<void> save(StoredCookie cookie) async {
    saved.add(cookie);
    rows[_key(cookie)] = cookie;
  }

  @override
  Future<void> remove(StoredCookie cookie) async {
    removed.add(cookie);
    rows.remove(_key(cookie));
  }

  @override
  Future<int> deleteExpired(DateTime now) async {
    purgedAt.add(now);
    final int before = rows.length;
    rows.removeWhere(
      (String _, StoredCookie cookie) => cookie.isExpiredAt(now),
    );

    return before - rows.length;
  }

  @override
  Future<int> deleteByDomain(String domain) async {
    final int before = rows.length;
    rows.removeWhere(
      (String _, StoredCookie cookie) => cookie.domain == domain,
    );

    return before - rows.length;
  }

  @override
  Future<int> deleteAll() async {
    final int before = rows.length;
    rows.clear();

    return before;
  }

  /// The storage key of one cookie.
  String _key(StoredCookie cookie) =>
      '${cookie.domain}|${cookie.path}|${cookie.name}';
}

/// One parsed cookie for the fake store to start with.
StoredCookie _cookie({
  String name = 'session',
  String value = 'abc',
  String domain = 'example.com',
  String path = '/',
  DateTime? expiresAt,
}) => StoredCookie(
  name: name,
  value: value,
  domain: domain,
  path: path,
  isSecure: false,
  isDeletion: false,
  expiresAt: expiresAt,
);

void main() {
  group('PersistentCookieManager', () {
    late _FakeStore store;
    late FakeClock clock;
    late PersistentCookieManager manager;

    setUp(() {
      store = _FakeStore();
      clock = FakeClock(start: DateTime.utc(2026, 10, 23));
      manager = PersistentCookieManager(
        store: store,
        clock: clock,
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      );
    });

    /// Lets the fire-and-forget writes reach the store.
    Future<void> flush() => Future<void>.delayed(Duration.zero);

    test('hydrate_whenTheStoreHasCookies_loadsThemForRequests', () async {
      store.rows['example.com|/|session'] = _cookie();

      await manager.hydrate();

      expect(
        manager.cookieHeaderFor(Uri.parse('https://example.com/')),
        'session=abc',
      );
    });

    test('hydrate_whenACookieExpired_skipsItAndPurgesTheJar', () async {
      store.rows['example.com|/|old'] = _cookie(
        name: 'old',
        expiresAt: clock.now().subtract(const Duration(days: 1)),
      );
      store.rows['example.com|/|new'] = _cookie(
        name: 'new',
        expiresAt: clock.now().add(const Duration(days: 1)),
      );

      await manager.hydrate();

      expect(
        manager.cookieHeaderFor(Uri.parse('https://example.com/')),
        'new=abc',
      );
      expect(store.purgedAt, hasLength(1));
    });

    test(
      'removeCookiesFor_whenTheSourceLogsOut_dropsMemoryAndStorage',
      () async {
        // `source.removeLoginHeader`（M25/S5a）：内存与库都要清，否则重启后会话又回来了。
        store.rows['example.com|/|session'] = _cookie();
        store.rows['other.test|/|keep'] = _cookie(domain: 'other.test');
        await manager.hydrate();

        manager.removeCookiesFor(Uri.parse('https://example.com/book/1'));
        await flush();

        expect(
          manager.cookieHeaderFor(Uri.parse('https://example.com/')),
          isNull,
        );
        expect(store.rows.keys, <String>['other.test|/|keep']);
        // 别的域的会话照旧可用。
        expect(
          manager.cookieHeaderFor(Uri.parse('https://other.test/')),
          'session=abc',
        );
      },
    );

    test('hydrate_whenNothingExpired_doesNotPurge', () async {
      store.rows['example.com|/|session'] = _cookie();

      await manager.hydrate();

      expect(store.purgedAt, isEmpty);
    });

    test('storeFromResponse_whenACookieArrives_persistsIt', () async {
      manager.storeFromResponse(
        Uri.parse('https://example.com/login'),
        <String>['session=xyz; Path=/; Max-Age=3600'],
      );
      await flush();

      expect(store.saved.single.value, 'xyz');
      expect(store.saved.single.expiresAt, isNotNull);
      expect(
        manager.cookieHeaderFor(Uri.parse('https://example.com/')),
        'session=xyz',
      );
    });

    test(
      'storeFromResponse_whenTheServerDeletesARemovesItFromStorage',
      () async {
        store.rows['example.com|/|session'] = _cookie();
        await manager.hydrate();

        manager.storeFromResponse(Uri.parse('https://example.com/'), <String>[
          'session=; Max-Age=0',
        ]);
        await flush();

        expect(store.removed.single.name, 'session');
        expect(
          manager.cookieHeaderFor(Uri.parse('https://example.com/')),
          isNull,
        );
      },
    );

    test(
      'storeFromResponse_whenTheCookieIsAlreadyExpired_doesNotKeepIt',
      () async {
        manager.storeFromResponse(Uri.parse('https://example.com/'), <String>[
          'gone=1; Max-Age=-10',
        ]);
        await flush();

        expect(
          manager.cookieHeaderFor(Uri.parse('https://example.com/')),
          isNull,
        );
        expect(store.removed, isNotEmpty);
      },
    );

    test('importFromWebView_whenCookiesArrive_theyAreSentFromNowOn', () async {
      await manager.importFromWebView(<StoredCookie>[
        _cookie(name: 'cf_clearance', value: 'solved'),
      ]);
      await flush();

      expect(
        manager.cookieHeaderFor(Uri.parse('https://example.com/book')),
        'cf_clearance=solved',
      );
      expect(store.saved.single.name, 'cf_clearance');
    });

    test('importFromWebView_whenTheJarIsEmpty_staysEmpty', () async {
      await manager.importFromWebView(const <StoredCookie>[]);

      expect(
        manager.cookieHeaderFor(Uri.parse('https://example.com/')),
        isNull,
      );
    });

    test('cookiesFor_whenCookiesAreStored_answersTheMatchingOnes', () async {
      store.rows['example.com|/|session'] = _cookie();
      store.rows['other.test|/|other'] = _cookie(
        name: 'other',
        domain: 'other.test',
      );
      await manager.hydrate();

      final List<StoredCookie> forExample = manager.cookiesFor(
        Uri.parse('https://example.com/'),
      );

      expect(forExample.map((StoredCookie c) => c.name), <String>['session']);
    });

    test('mergeCookieHeader_writesEveryCookieThrough', () async {
      // 登录头里的 Cookie 必须落库：否则重启后要重新登录一次。
      manager.mergeCookieHeader(
        Uri.parse('https://example.com/'),
        'sid=1; token=ab',
      );
      await pumpEventQueue();

      expect(store.saved.map((StoredCookie cookie) => cookie.name), <String>[
        'sid',
        'token',
      ]);
      expect(
        manager.cookieHeaderFor(Uri.parse('https://example.com/')),
        'sid=1; token=ab',
      );
    });

    test('cookiesFor_whenNothingMatches_answersNothing', () async {
      expect(manager.cookiesFor(Uri.parse('https://example.com/')), isEmpty);
    });
  });
}
