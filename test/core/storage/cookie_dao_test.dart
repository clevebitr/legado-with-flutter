import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/cookie_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clock a test can move by hand (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

void main() {
  group('CookieDao', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late CookieDao dao;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime.utc(2026, 10, 23));
      dao = CookieDao(database, clock: clock);
    });

    tearDown(() => database.close());

    /// Stores one cookie, defaulting everything but the identity.
    Future<void> save({
      String domain = 'example.com',
      String path = '/',
      String name = 'session',
      String value = 'abc',
      bool isSecure = false,
      DateTime? expiresAt,
    }) => dao.upsert(
      domain: domain,
      path: path,
      name: name,
      value: value,
      isSecure: isSecure,
      expiresAt: expiresAt,
    );

    test('findAll_whenNothingIsStored_returnsNothing', () async {
      expect(await dao.findAll(), isEmpty);
    });

    test('upsert_whenCalled_storesTheCookieWithTheInjectedTimestamp', () async {
      await save(isSecure: true);

      final CookieRow row = (await dao.findAll()).single;
      expect(row.domain, 'example.com');
      expect(row.name, 'session');
      expect(row.value, 'abc');
      expect(row.isSecure, isTrue);
      // drift 按 UTC 存、按本地读回：比较前统一时区（与其它 DAO 测试同一条约定）。
      expect(row.createdAt.toUtc(), clock.now().toUtc());
      expect(row.expiresAt, isNull);
    });

    test('upsert_whenTheIdentityExists_replacesTheValue', () async {
      await save(value: 'abc');
      clock.advance(const Duration(minutes: 1));
      await save(value: 'def');

      final CookieRow row = (await dao.findAll()).single;
      expect(row.value, 'def');
      // drift 按 UTC 存、按本地读回：比较前统一时区（与其它 DAO 测试同一条约定）。
      expect(row.createdAt.toUtc(), clock.now().toUtc());
    });

    test('upsert_whenThePathDiffers_keepsBothCookies', () async {
      await save();
      await save(path: '/api');

      expect(await dao.findAll(), hasLength(2));
    });

    test('deleteOne_whenTheCookieExists_removesIt', () async {
      await save();

      expect(
        await dao.deleteOne(domain: 'example.com', path: '/', name: 'session'),
        1,
      );
      expect(await dao.findAll(), isEmpty);
    });

    test('deleteExpired_whenACookieExpired_removesOnlyThatOne', () async {
      await save(name: 'old', expiresAt: clock.now());
      await save(
        name: 'new',
        expiresAt: clock.now().add(const Duration(days: 1)),
      );
      await save(name: 'session');

      expect(await dao.deleteExpired(clock.now()), 1);
      expect((await dao.findAll()).map((CookieRow row) => row.name), <String>[
        'new',
        'session',
      ]);
    });

    test('deleteAll_whenCalled_emptiesTheJar', () async {
      await save();
      await save(name: 'other');

      expect(await dao.deleteAll(), 2);
      expect(await dao.findAll(), isEmpty);
    });
  });
}
