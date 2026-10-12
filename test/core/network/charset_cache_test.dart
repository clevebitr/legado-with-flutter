import 'package:drift/native.dart';
import 'package:flutter_reader/core/network/charset_cache.dart';
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
  group('CacheDaoCharsetCache', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late CacheDaoCharsetCache cache;

    const String sourceId = 'https://example-novel.test';
    const String url = 'https://example-novel.test/book/1/';

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime.utc(2026, 10, 12));
      cache = CacheDaoCharsetCache(CacheDao(database, clock: clock));
    });

    tearDown(() => database.close());

    test('read_whenNothingWasWritten_returnsNull', () async {
      // 未命中与「缓存不可用」对调用方是同一件事：重新嗅探（`book-source.md` §5）。
      expect(
        await cache.read(
          sourceId: sourceId,
          ruleField: 'charset',
          url: url,
          page: 1,
        ),
        isNull,
      );
    });

    test('read_whenTheCharsetWasWritten_returnsIt', () async {
      await cache.write(
        sourceId: sourceId,
        ruleField: 'charset',
        url: url,
        page: 1,
        charset: 'gbk',
      );

      expect(
        await cache.read(
          sourceId: sourceId,
          ruleField: 'charset',
          url: url,
          page: 1,
        ),
        'gbk',
      );
    });

    test('read_givenAnotherSourceOrUrl_doesNotReuseTheLabel', () async {
      await cache.write(
        sourceId: sourceId,
        ruleField: 'charset',
        url: url,
        page: 1,
        charset: 'gbk',
      );

      // 键是「书源 ID + URL」维度（PLAN 3.9）：别的源 / 别的页必须各自嗅探。
      expect(
        await cache.read(
          sourceId: sourceId,
          ruleField: 'charset',
          url: 'https://example-novel.test/book/2/',
          page: 1,
        ),
        isNull,
      );
      expect(
        await cache.read(
          sourceId: 'https://other-novel.test',
          ruleField: 'charset',
          url: url,
          page: 1,
        ),
        isNull,
      );
    });

    test('read_givenTheEntryExpired_returnsNull', () async {
      await cache.write(
        sourceId: sourceId,
        ruleField: 'charset',
        url: url,
        page: 1,
        charset: 'gbk',
      );
      clock.advance(defaultCharsetCacheTtl + const Duration(seconds: 1));

      // TTL 归 CacheDao（C-NET-6）；过期即未命中，而不是继续用旧标签。
      expect(
        await cache.read(
          sourceId: sourceId,
          ruleField: 'charset',
          url: url,
          page: 1,
        ),
        isNull,
      );
    });

    test('read_whenTheSameKeyIsWrittenTwice_keepsTheLatestLabel', () async {
      await cache.write(
        sourceId: sourceId,
        ruleField: 'charset',
        url: url,
        page: 1,
        charset: 'gbk',
      );
      await cache.write(
        sourceId: sourceId,
        ruleField: 'charset',
        url: url,
        page: 1,
        charset: 'utf-8',
      );

      expect(
        await cache.read(
          sourceId: sourceId,
          ruleField: 'charset',
          url: url,
          page: 1,
        ),
        'utf-8',
      );
    });
  });
}
