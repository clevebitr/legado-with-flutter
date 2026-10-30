import 'package:drift/native.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/data/cache_dao_content_cache.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_log_printer.dart';

/// Clock a test can move by hand; TTL tests must never sleep (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

/// A [CacheDao] whose two operations always fail, so the adapter's absorption can be pinned.
final class _FailingCacheDao extends CacheDao {
  _FailingCacheDao(super.attachedDatabase, {required this.error})
    : super(clock: _FixedClock(DateTime.utc(2026, 10, 14)));

  /// 静态类型是 `Exception`：`only_throw_errors` 要求抛出的东西可证明是异常，而适配器吸收的
  /// 正好是 `Exception`（`Error` 必须原样向上，ADR-0022）。
  final Exception error;

  @override
  Future<String?> get({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
  }) async => throw error;

  @override
  Future<void> put({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
    required String payload,
    required Duration ttl,
    String? scopeKey,
    String? sourceKey,
    bool persistent = false,
  }) async => throw error;

  @override
  Future<int> deleteAll() async => throw error;
}

void main() {
  group('CacheDaoContentCache', () {
    const String sourceId = 'https://example-novel.test';
    const String url = 'https://example-novel.test/book/1/1.html';
    const String body = '正文第一段。\n正文第二段。';

    late ReaderDatabase database;
    late _FixedClock clock;
    late FakeLogPrinter printer;
    late CacheDaoContentCache cache;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime.utc(2026, 10, 14));
      printer = FakeLogPrinter();
      cache = CacheDaoContentCache(
        CacheDao(database, clock: clock),
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );
    });

    tearDown(() => database.close());

    test('read_givenNothingStored_isAMiss', () async {
      expect(await cache.read(sourceId: sourceId, url: url), isNull);
    });

    test('read_givenAStoredBody_returnsIt', () async {
      await cache.write(sourceId: sourceId, url: url, body: body);

      expect(await cache.read(sourceId: sourceId, url: url), body);
    });

    test('read_givenAnotherSourceWithTheSameUrl_isAMiss', () async {
      // 键含书源 ID：两个书源发布同一个章节 URL 时不得互相串味（C-NET-6）。
      await cache.write(sourceId: sourceId, url: url, body: body);

      expect(
        await cache.read(sourceId: 'https://other.test', url: url),
        isNull,
      );
    });

    test('read_givenAnExpiredBody_isAMiss', () async {
      await cache.write(sourceId: sourceId, url: url, body: body);
      clock.advance(chapterCacheTtl + const Duration(minutes: 1));

      expect(await cache.read(sourceId: sourceId, url: url), isNull);
    });

    test('read_givenAPersistentBody_survivesTheTtlAndCleanup', () async {
      // 在架书的正文不自动过期（ADR-0097 §决策 1）：十天后再读仍然命中，`clearExpired` 也不碰它。
      await cache.write(
        sourceId: sourceId,
        url: url,
        body: body,
        bookUrl: 'https://example-novel.test/book/1',
        persistent: true,
      );
      clock.advance(const Duration(days: 10));

      expect(await cache.read(sourceId: sourceId, url: url), body);
      expect(await cache.clearExpired(), 0);
      expect(await cache.read(sourceId: sourceId, url: url), body);
    });

    test('read_givenANonShelfBody_expiresAfterThreeDays', () async {
      // 非在架书默认 3 天（ADR-0097 §决策 1）。
      await cache.write(sourceId: sourceId, url: url, body: body);
      clock.advance(const Duration(days: 2));

      expect(await cache.read(sourceId: sourceId, url: url), body);

      clock.advance(const Duration(days: 1, hours: 1));
      expect(await cache.read(sourceId: sourceId, url: url), isNull);
    });

    test('read_givenADatabaseFailure_isAMissAndIsLogged', () async {
      // 端口是 total（ADR-0033）：缓存读失败只是一次未命中，且必须留一条 debug 痕迹。
      final CacheDaoContentCache failing = CacheDaoContentCache(
        _FailingCacheDao(database, error: Exception('database is gone')),
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      expect(await failing.read(sourceId: sourceId, url: url), isNull);
      expect(
        printer.events.last.message.toString(),
        allOf(contains('Chapter cache unavailable'), contains('url=')),
      );
    });

    test('write_givenADatabaseFailure_isAbsorbed', () async {
      final CacheDaoContentCache failing = CacheDaoContentCache(
        _FailingCacheDao(database, error: Exception('database is gone')),
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      // 丢一条缓存条目只值一次请求，绝不能把章节变成失败（C-ERR-1）。
      await expectLater(
        failing.write(sourceId: sourceId, url: url, body: body),
        completes,
      );
    });

    test('write_givenABookUrl_recordsTheScopeOnTheEntry', () async {
      await cache.write(
        sourceId: sourceId,
        url: url,
        body: body,
        bookUrl: 'https://example-novel.test/book/1',
      );

      expect(
        await cache.countForBook(
          sourceId: sourceId,
          bookUrl: 'https://example-novel.test/book/1',
        ),
        1,
      );
      // 作用域不参与键计算：读仍是同一个入口。
      expect(await cache.read(sourceId: sourceId, url: url), body);
    });

    test('countForBook_givenNoEntryForThatBook_answersZero', () async {
      await cache.write(
        sourceId: sourceId,
        url: url,
        body: body,
        bookUrl: 'https://example-novel.test/book/1',
      );

      expect(
        await cache.countForBook(
          sourceId: sourceId,
          bookUrl: 'https://example-novel.test/book/2',
        ),
        0,
      );
    });

    test('clearForBook_givenTwoBooks_removesOnlyThatBook', () async {
      await cache.write(
        sourceId: sourceId,
        url: url,
        body: body,
        bookUrl: 'https://example-novel.test/book/1',
      );
      await cache.write(
        sourceId: sourceId,
        url: 'https://example-novel.test/book/2/1.html',
        body: body,
        bookUrl: 'https://example-novel.test/book/2',
      );

      expect(
        await cache.clearForBook(
          sourceId: sourceId,
          bookUrl: 'https://example-novel.test/book/1',
        ),
        1,
      );
      expect(await cache.read(sourceId: sourceId, url: url), isNull);
      expect(
        await cache.countForBook(
          sourceId: sourceId,
          bookUrl: 'https://example-novel.test/book/2',
        ),
        1,
      );
    });

    test('countForSource_givenTwoSources_countsEach', () async {
      await cache.write(sourceId: sourceId, url: url, body: body);
      await cache.write(
        sourceId: 'https://other.test',
        url: 'https://other.test/1.html',
        body: body,
      );

      expect(await cache.countForSource(sourceId), 1);
      expect(await cache.countForSource('https://other.test'), 1);
      expect(await cache.countForSource('https://none.test'), 0);
      expect(await cache.countAll(), 2);
    });

    test('clearForSource_givenTwoSources_removesOnlyThatOne', () async {
      await cache.write(sourceId: sourceId, url: url, body: body);
      await cache.write(
        sourceId: 'https://other.test',
        url: 'https://other.test/1.html',
        body: body,
      );

      expect(await cache.clearForSource(sourceId), 1);
      expect(await cache.read(sourceId: sourceId, url: url), isNull);
      expect(await cache.countAll(), 1);
    });

    test('clearExpired_givenAFreshEntry_keepsIt', () async {
      await cache.write(sourceId: sourceId, url: url, body: body);

      expect(await cache.clearExpired(), 0);
      expect(await cache.read(sourceId: sourceId, url: url), body);
    });

    test('clearAll_givenStoredBodies_removesEveryEntry', () async {
      // 净化规则一改，所有已缓存的「成品正文」都过期了（ADR-0070 增补 §7）。
      await cache.write(sourceId: sourceId, url: url, body: body);
      await cache.write(
        sourceId: sourceId,
        url: 'https://example-novel.test/book/2/1.html',
        body: body,
      );

      await cache.clearAll();

      expect(await cache.read(sourceId: sourceId, url: url), isNull);
      expect(
        await cache.read(
          sourceId: sourceId,
          url: 'https://example-novel.test/book/2/1.html',
        ),
        isNull,
      );
    });

    test('clearAll_givenABrokenDatabase_completesAnyway', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final CacheDaoContentCache failing = CacheDaoContentCache(
        _FailingCacheDao(database, error: Exception('database is gone')),
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      // 没删干净只会让旧正文多活一阵，不该把「改一条净化规则」变成一次失败（ADR-0033）。
      await expectLater(failing.clearAll(), completes);
      expect(printer.events, isNotEmpty);
    });
  });
}
