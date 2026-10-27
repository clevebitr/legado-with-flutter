import 'package:flutter_reader/core/js/source_login_header.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_log_printer.dart';

/// A repository whose operations can be made to fail, and which records the writes.
final class _RecordingRepository implements SourceLoginHeaderRepository {
  _RecordingRepository({this.stored, this.failReads = false});

  String? stored;
  bool failReads;
  bool failWrites = false;
  final List<String?> writes = <String?>[];

  @override
  Future<String?> read(String sourceUrl) async {
    if (failReads) {
      throw const FormatException('unreadable');
    }

    return stored;
  }

  @override
  Future<void> write(String sourceUrl, String? header) async {
    if (failWrites) {
      throw const FormatException('unwritable');
    }
    writes.add(header);
    stored = header;
  }
}

SourceLoginHeaderStore _store(SourceLoginHeaderRepository repository) =>
    SourceLoginHeaderStore(
      repository: repository,
      logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
    );

void main() {
  group('SourceLoginHeaderStore', () {
    test('snapshot_beforeTheFirstLoad_answersNull', () {
      final SourceLoginHeaderStore store = _store(_RecordingRepository());

      expect(store.snapshot('https://a.test'), isNull);
    });

    test('ensureLoaded_givenAStoredHeader_seedsTheSnapshot', () async {
      final _RecordingRepository repository = _RecordingRepository(
        stored: '{"Token":"t"}',
      );
      final SourceLoginHeaderStore store = _store(repository);

      await store.ensureLoaded('https://a.test');

      expect(store.snapshot('https://a.test'), '{"Token":"t"}');
    });

    test('ensureLoaded_whenTheRepositoryFails_answersNoHeader', () async {
      // 读不出来只是少带一个头：重试会把每个 job 都拖慢一次。
      final _RecordingRepository repository = _RecordingRepository(
        stored: '{"Token":"t"}',
        failReads: true,
      );
      final SourceLoginHeaderStore store = _store(repository);

      await store.ensureLoaded('https://a.test');

      expect(store.snapshot('https://a.test'), isNull);
    });

    test('ensureLoaded_calledTwice_readsTheRepositoryOnce', () async {
      final _CountingRepository repository = _CountingRepository();
      final SourceLoginHeaderStore store = _store(repository);

      await store.ensureLoaded('https://a.test');
      await store.ensureLoaded('https://a.test');

      expect(repository.reads, 1);
    });

    test('put_beforeTheFirstLoad_isNotOverwrittenByTheRead', () async {
      // 内存里的值总是比库里新（写穿是排队的）：首读不能用旧值盖回去。
      final SourceLoginHeaderStore store = _store(
        _StaleRepository('{"Token":"old"}'),
      );

      store.put('https://a.test', '{"Token":"new"}');
      await store.ensureLoaded('https://a.test');

      expect(store.snapshot('https://a.test'), '{"Token":"new"}');
    });

    test('put_storesTheValueAndWritesThrough', () async {
      final _RecordingRepository repository = _RecordingRepository();
      final SourceLoginHeaderStore store = _store(repository);

      store.put('https://a.test', '{"Cookie":"sid=1"}');
      await pumpEventQueue();

      expect(store.snapshot('https://a.test'), '{"Cookie":"sid=1"}');
      expect(repository.writes, <String?>['{"Cookie":"sid=1"}']);
    });

    test('put_givenNull_clearsTheValue', () async {
      final _RecordingRepository repository = _RecordingRepository(
        stored: '{"Token":"t"}',
      );
      final SourceLoginHeaderStore store = _store(repository);
      await store.ensureLoaded('https://a.test');

      store.put('https://a.test', null);
      await pumpEventQueue();

      expect(store.snapshot('https://a.test'), isNull);
      expect(repository.writes, <String?>[null]);
    });

    test('put_whenTheRepositoryFails_keepsTheValueInMemory', () async {
      // 落库失败只记 warning：登录头丢了只是要重新登录一次，规则不该因此失败。
      final _RecordingRepository repository = _RecordingRepository();
      repository.failWrites = true;
      final SourceLoginHeaderStore store = _store(repository);

      store.put('https://a.test', '{"Token":"t"}');
      await pumpEventQueue();

      expect(store.snapshot('https://a.test'), '{"Token":"t"}');
    });

    test('put_withoutARepository_staysInMemory', () async {
      final SourceLoginHeaderStore store = SourceLoginHeaderStore();

      store.put('https://a.test', '{"Token":"t"}');
      await pumpEventQueue();

      expect(store.snapshot('https://a.test'), '{"Token":"t"}');
    });
  });

  group('InMemorySourceLoginHeaderRepository', () {
    test('write_thenRead_answersTheSameValuePerSource', () async {
      final InMemorySourceLoginHeaderRepository repository =
          InMemorySourceLoginHeaderRepository();

      await repository.write('https://a.test', '{"Token":"a"}');
      await repository.write('https://b.test', '{"Token":"b"}');

      expect(await repository.read('https://a.test'), '{"Token":"a"}');
      expect(await repository.read('https://b.test'), '{"Token":"b"}');
    });

    test('writeGivenNull_removesTheValue', () async {
      final InMemorySourceLoginHeaderRepository repository =
          InMemorySourceLoginHeaderRepository();
      await repository.write('https://a.test', '{"Token":"a"}');

      await repository.write('https://a.test', null);

      expect(await repository.read('https://a.test'), isNull);
    });
  });

  group('loginHeaderCookieOf', () {
    test('givenACookieHeader_answersItsValue', () {
      expect(
        loginHeaderCookieOf('{"User-Agent":"x","Cookie":"sid=1; t=2"}'),
        'sid=1; t=2',
      );
    });

    test('givenALowerCaseCookieHeader_answersItsValue', () {
      expect(loginHeaderCookieOf('{"cookie":"sid=1"}'), 'sid=1');
    });

    test('givenNoCookieHeader_answersNull', () {
      expect(loginHeaderCookieOf('{"Token":"t"}'), isNull);
    });

    test('givenAnEmptyCookie_answersNull', () {
      expect(loginHeaderCookieOf('{"Cookie":"  "}'), isNull);
    });

    test('givenBrokenJson_answersNull', () {
      // 规则可以往登录头里写任何东西：坏值只该丢掉 Cookie 合并，不该让请求失败。
      expect(loginHeaderCookieOf('not json'), isNull);
      expect(loginHeaderCookieOf('["Cookie"]'), isNull);
      expect(loginHeaderCookieOf('{"Cookie":1}'), isNull);
    });
  });
}

/// Always answers a stale value, so a test can prove that a memory write wins.
final class _StaleRepository implements SourceLoginHeaderRepository {
  _StaleRepository(this.stale);

  final String stale;

  @override
  Future<String?> read(String sourceUrl) async => stale;

  @override
  Future<void> write(String sourceUrl, String? header) async {}
}

/// Counts the reads, for the single-flight case.
final class _CountingRepository implements SourceLoginHeaderRepository {
  int reads = 0;

  @override
  Future<String?> read(String sourceUrl) async {
    reads += 1;

    return null;
  }

  @override
  Future<void> write(String sourceUrl, String? header) async {}
}
