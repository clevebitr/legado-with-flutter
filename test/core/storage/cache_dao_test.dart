import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clock a test can move by hand; TTL tests must never sleep
/// (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

void main() {
  group('CacheDao', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late CacheDao dao;

    const String sourceId = 'source-1';
    const String ruleField = 'contentRule.content';
    const String url = 'https://example.com/book/1';
    const int page = 1;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime.utc(2026, 10, 11));
      dao = CacheDao(database, clock: clock);
    });

    tearDown(() => database.close());

    test('get_whenNothingIsCached_returnsNull', () async {
      expect(
        await dao.get(
          sourceId: sourceId,
          ruleField: ruleField,
          url: url,
          page: page,
        ),
        isNull,
      );
    });

    test('get_whenEntryIsFresh_returnsThePayload', () async {
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: url,
        page: page,
        payload: '<html>content</html>',
        ttl: const Duration(minutes: 5),
      );

      expect(
        await dao.get(
          sourceId: sourceId,
          ruleField: ruleField,
          url: url,
          page: page,
        ),
        '<html>content</html>',
      );
    });

    test('get_whenEntryHasExpired_returnsNull', () async {
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: url,
        page: page,
        payload: '<html>content</html>',
        ttl: const Duration(minutes: 5),
      );
      clock.advance(const Duration(minutes: 6));

      expect(
        await dao.get(
          sourceId: sourceId,
          ruleField: ruleField,
          url: url,
          page: page,
        ),
        isNull,
      );
    });

    test('get_whenTheTtlBoundaryIsReached_returnsNull', () async {
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: url,
        page: page,
        payload: '<html>content</html>',
        ttl: const Duration(minutes: 5),
      );
      clock.advance(const Duration(minutes: 5));

      expect(
        await dao.get(
          sourceId: sourceId,
          ruleField: ruleField,
          url: url,
          page: page,
        ),
        isNull,
        reason: 'An entry that expires exactly now is already invalid.',
      );
    });

    test('put_whenTheEntryExists_replacesPayloadAndRestartsTheTtl', () async {
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: url,
        page: page,
        payload: 'old',
        ttl: const Duration(minutes: 1),
      );
      clock.advance(const Duration(minutes: 2));
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: url,
        page: page,
        payload: 'new',
        ttl: const Duration(minutes: 5),
      );

      expect(
        await dao.get(
          sourceId: sourceId,
          ruleField: ruleField,
          url: url,
          page: page,
        ),
        'new',
      );
    });

    test('get_whenOnlyAnotherPageIsCached_returnsNull', () async {
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: url,
        page: 1,
        payload: 'page-1',
        ttl: const Duration(minutes: 5),
      );

      expect(
        await dao.get(
          sourceId: sourceId,
          ruleField: ruleField,
          url: url,
          page: 2,
        ),
        isNull,
      );
    });

    test('deleteExpired_whenOneEntryExpired_removesOnlyThatEntry', () async {
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: 'https://example.com/expired',
        page: page,
        payload: 'expired',
        ttl: const Duration(minutes: 1),
      );
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: 'https://example.com/fresh',
        page: page,
        payload: 'fresh',
        ttl: const Duration(hours: 1),
      );
      clock.advance(const Duration(minutes: 2));

      expect(await dao.deleteExpired(), 1);
      expect(
        await dao.get(
          sourceId: sourceId,
          ruleField: ruleField,
          url: 'https://example.com/fresh',
          page: page,
        ),
        'fresh',
      );
    });

    test('deleteExpired_whenNothingExpired_removesNothing', () async {
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: url,
        page: page,
        payload: 'fresh',
        ttl: const Duration(hours: 1),
      );

      expect(await dao.deleteExpired(), 0);
    });

    test('deleteAll_whenEntriesExist_removesThemAll', () async {
      // roadmap 5.7 ①：全量清空零 schema 变更，设置页的就是这样清缓存的。
      await dao.put(
        sourceId: sourceId,
        ruleField: ruleField,
        url: url,
        page: page,
        payload: 'one',
        ttl: const Duration(hours: 1),
      );
      await dao.put(
        sourceId: sourceId,
        ruleField: 'content',
        url: url,
        page: 1,
        payload: 'two',
        ttl: const Duration(hours: 1),
      );

      expect(await dao.deleteAll(), 2);
      expect(
        await dao.get(
          sourceId: sourceId,
          ruleField: ruleField,
          url: url,
          page: page,
        ),
        isNull,
      );
    });
  });
}
