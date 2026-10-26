import 'package:drift/drift.dart'
    show DriftWrappedException, InvalidDataException;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/charset_cache.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_log_printer.dart';

/// A [DriftRemoteException] the test can raise.
///
/// drift 2.35.2 keeps its constructor private (`remote.dart:63` exports the type only), so
/// the double **implements** it — which is exactly what `on DriftRemoteException` catches.
final class _RemoteFailure implements DriftRemoteException, Exception {
  @override
  Object get remoteCause => 'remote';

  @override
  StackTrace? get remoteStackTrace => null;

  @override
  String toString() => 'remote failure';
}

/// A DAO whose cache operations always fail with [error].
final class _FailingCacheDao extends CacheDao {
  _FailingCacheDao(super.attachedDatabase, {required this.error})
    : super(clock: _FixedClock(DateTime.utc(2026, 10, 12)));

  /// 静态类型是 `Exception`（而不是 `Object`）：`only_throw_errors` 要求抛出的东西可证明是
  /// `Exception` / `Error`，而适配器吸收的正好是前者。
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
  }) async => throw error;
}

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
    late FakeLogPrinter printer;

    const String sourceId = 'https://example-novel.test';
    const String url = 'https://example-novel.test/book/1/';

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime.utc(2026, 10, 12));
      printer = FakeLogPrinter();
      cache = CacheDaoCharsetCache(
        CacheDao(database, clock: clock),
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );
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

  group('CacheDaoCharsetCache 的失败面', () {
    const String sourceId = 'https://example-novel.test';
    const String url = 'https://example-novel.test/book/1/';

    /// The exceptions the adapter absorbs, i.e. the ones this test can raise.
    ///
    /// `ConnectionClosedException` cannot be listed: drift 2.35.2 does not export it
    /// (`remote.dart` / `isolate.dart` export only `DriftRemoteException`), which is exactly
    /// why ADR-0033 pins an `on Exception` fallback in `_absorb`. The last entry stands in
    /// for that fallback — a plain `Exception`, since the real type cannot be named here
    /// either.
    final Map<String, Exception> failures = <String, Exception>{
      'SqliteException': SqliteException(
        extendedResultCode: 1,
        message: 'no such table: cache_entries',
      ),
      'DriftRemoteException': _RemoteFailure(),
      'DriftWrappedException': DriftWrappedException(message: 'wrapped'),
      'InvalidDataException': InvalidDataException('bad data'),
      'Exception': Exception('a cache failure the adapter cannot name'),
    };

    for (final MapEntry<String, Exception> failure in failures.entries) {
      test('read_given${failure.key}_answersAMissInsteadOfThrowing', () async {
        final ReaderDatabase database = ReaderDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final FakeLogPrinter printer = FakeLogPrinter();
        final CacheDaoCharsetCache failing = CacheDaoCharsetCache(
          _FailingCacheDao(database, error: failure.value),
          logger: AppLogger(level: LogLevel.debug, printer: printer),
        );

        // 端口契约是 total（C-ERR-2 的边界只能涵盖 presentation Notifier，所以失败面在
        // 适配器里吸收）：读失败 = 未命中，且必须留一条 debug 痕迹（C-ERR-3）。
        expect(
          await failing.read(
            sourceId: sourceId,
            ruleField: 'charset',
            url: url,
            page: 1,
          ),
          isNull,
        );
        await expectLater(
          failing.write(
            sourceId: sourceId,
            ruleField: 'charset',
            url: url,
            page: 1,
            charset: 'gbk',
          ),
          completes,
        );
        expect(
          printer.events.map((LogEvent event) => event.message),
          hasLength(2),
        );
        expect(
          printer.events.first.message,
          contains('Charset cache unavailable'),
        );
        expect(
          printer.events.map((LogEvent event) => event.level),
          everyElement(Level.debug),
        );
      });
    }
  });
}
