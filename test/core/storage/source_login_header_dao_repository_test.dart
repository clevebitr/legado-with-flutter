import 'package:drift/native.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/source_login_header_dao_repository.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_log_printer.dart';

/// Clock a test can move by hand (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  final DateTime _now;

  @override
  DateTime now() => _now;
}

void main() {
  group('SourceLoginHeaderDaoRepository', () {
    late ReaderDatabase database;
    late BookSourceDao dao;
    late SourceLoginHeaderDaoRepository repository;
    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      dao = BookSourceDao(
        database,
        clock: _FixedClock(DateTime.utc(2026, 10, 26)),
      );
      repository = SourceLoginHeaderDaoRepository(
        dao,
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      );
    });

    tearDown(() => database.close());

    Future<int> insert({String url = 'https://a.test', String name = '甲'}) =>
        dao.insertNew(
          url: url,
          fingerprint: 'fp-$name',
          payload: '{"bookSourceName":"$name"}',
          name: name,
          groupName: null,
          sourceType: 0,
          isEnabled: true,
          customOrder: 0,
          weight: 0,
          lastUpdateTime: null,
          respondTime: null,
          isExploreEnabled: true,
        );

    test('read_givenNoSource_answersNull', () async {
      expect(await repository.read('https://a.test'), isNull);
    });

    test('write_thenRead_roundTripsThroughTheColumn', () async {
      await insert();

      await repository.write('https://a.test', '{"Token":"t"}');

      expect(await repository.read('https://a.test'), '{"Token":"t"}');
    });

    test('write_givenNull_clearsTheValue', () async {
      await insert();
      await repository.write('https://a.test', '{"Token":"t"}');

      await repository.write('https://a.test', null);

      expect(await repository.read('https://a.test'), isNull);
    });

    test('write_withoutAMatchingSource_doesNotThrow', () async {
      // 书源可能在登录过程中被删掉：写不进去只是丢一个登录头，不该让规则失败。
      await repository.write('https://gone.test', '{"Token":"t"}');

      expect(await repository.read('https://gone.test'), isNull);
    });
  });
}
