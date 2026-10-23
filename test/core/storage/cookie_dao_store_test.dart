import 'package:drift/native.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/storage/cookie_dao.dart';
import 'package:flutter_reader/core/storage/cookie_dao_store.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_log_printer.dart';

/// Clock a test can move by hand (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

void main() {
  group('CookieDaoStore', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late CookieDaoStore store;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime.utc(2026, 10, 23));
      store = CookieDaoStore(
        CookieDao(database, clock: clock),
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      );
    });

    tearDown(() => database.close());

    /// One cookie value object for the store to save.
    StoredCookie cookie({
      String name = 'session',
      String value = 'abc',
      DateTime? expiresAt,
    }) => StoredCookie(
      name: name,
      value: value,
      domain: 'example.com',
      path: '/',
      isSecure: false,
      isDeletion: false,
      expiresAt: expiresAt,
    );

    test('loadAll_whenNothingIsStored_answersNothing', () async {
      expect(await store.loadAll(), isEmpty);
    });

    test('save_thenLoadAll_roundTripsEveryField', () async {
      await store.save(
        cookie(
          value: 'xyz',
          expiresAt: clock.now().add(const Duration(days: 1)),
        ),
      );

      final StoredCookie loaded = (await store.loadAll()).single;
      expect(loaded.name, 'session');
      expect(loaded.value, 'xyz');
      expect(loaded.domain, 'example.com');
      expect(loaded.path, '/');
      expect(loaded.isDeletion, isFalse);
      expect(
        loaded.expiresAt?.toUtc(),
        clock.now().toUtc().add(const Duration(days: 1)),
      );
    });

    test('save_whenTheIdentityExists_replacesTheValue', () async {
      await store.save(cookie(value: 'old'));
      await store.save(cookie(value: 'new'));

      expect((await store.loadAll()).single.value, 'new');
    });

    test('remove_whenTheCookieExists_deletesIt', () async {
      await store.save(cookie());

      await store.remove(cookie());

      expect(await store.loadAll(), isEmpty);
    });

    test('deleteExpired_whenOneExpired_answersOne', () async {
      await store.save(cookie(name: 'old', expiresAt: clock.now()));
      await store.save(
        cookie(
          name: 'new',
          expiresAt: clock.now().add(const Duration(days: 1)),
        ),
      );

      expect(await store.deleteExpired(clock.now()), 1);
      expect((await store.loadAll()).single.name, 'new');
    });
  });

  group('CookieDaoStore absorption', () {
    test('loadAll_whenTheDatabaseThrows_isAbsorbedAsAnEmptyJar', () async {
      // 端口是 total 的（ADR-0033 的同一立场）：库坏了只是「没有 cookie」，不能抛到请求里。
      // 这个用例单独成组：同时存在两个 ReaderDatabase 会让 drift 打「multiple databases」警告。
      final _FixedClock brokenClock = _FixedClock(DateTime.utc(2026, 10, 23));
      final ReaderDatabase broken = ReaderDatabase(NativeDatabase.memory());
      await broken.close();
      final CookieDaoStore brokenStore = CookieDaoStore(
        CookieDao(broken, clock: brokenClock),
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      );

      expect(await brokenStore.loadAll(), isEmpty);
      // 运行时构造（不写 const）：`const` 构造会被编译期折叠，覆盖率看不到那一行。
      await brokenStore.save(
        // ignore: prefer_const_constructors  const folding hides the constructor line from lcov
        StoredCookie(
          name: 'session',
          value: 'abc',
          domain: 'example.com',
          path: '/',
          isSecure: false,
          isDeletion: false,
        ),
      );
      expect(await brokenStore.deleteExpired(brokenClock.now()), 0);
    });
  });
}
