import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/settings/data/cache_dao_cache_purger.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clock a test can move by hand (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  final DateTime _now;

  @override
  DateTime now() => _now;
}

void main() {
  group('CacheDaoCachePurger', () {
    late ReaderDatabase database;
    late CacheDao dao;
    late CacheDaoCachePurger purger;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      dao = CacheDao(database, clock: _FixedClock(DateTime(2026, 10, 21)));
      purger = CacheDaoCachePurger(dao);
    });

    tearDown(() => database.close());

    test('purgeAll_whenEmpty_reportsNothingRemoved', () async {
      expect(await purger.purgeAll(), 0);
    });

    test('purgeAll_givenEntries_removesThemAndReportsTheCount', () async {
      await dao.put(
        sourceId: 'source',
        ruleField: 'content',
        url: 'https://source.test/book/1/1.html',
        page: 1,
        payload: 'body',
        ttl: const Duration(hours: 1),
      );

      expect(await purger.purgeAll(), 1);
      expect(
        await dao.get(
          sourceId: 'source',
          ruleField: 'content',
          url: 'https://source.test/book/1/1.html',
          page: 1,
        ),
        isNull,
      );
    });
  });
}
