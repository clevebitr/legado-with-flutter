import 'package:drift/native.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/source_login_info_dao_repository.dart';
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
  group('SourceLoginInfoDaoRepository', () {
    late ReaderDatabase database;
    late BookSourceDao dao;
    late SourceLoginInfoDaoRepository repository;
    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      dao = BookSourceDao(
        database,
        clock: _FixedClock(DateTime.utc(2026, 10, 27)),
      );
      repository = SourceLoginInfoDaoRepository(
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

    test('write_givenAMap_storesItAsJsonForTheLoginForm', () async {
      // 列的形状必须和登录表单读的那份一致（`loginInfoOf` 解的是 JSON map）。
      final int id = await insert();

      await repository.write('https://a.test', <String, String>{'账号': 'alice'});

      expect((await dao.findById(id))?.loginInfo, '{"账号":"alice"}');
    });

    test('write_givenNull_clearsTheColumn', () async {
      final int id = await insert();
      await repository.write('https://a.test', <String, String>{'账号': 'alice'});

      await repository.write('https://a.test', null);

      expect((await dao.findById(id))?.loginInfo, isNull);
    });

    test('write_givenAnEmptyMap_clearsTheColumn', () async {
      // 空表与「没登录过」在表单那侧是同一件事，存个 `{}` 只会让下次读多解一次。
      final int id = await insert();

      await repository.write('https://a.test', <String, String>{});

      expect((await dao.findById(id))?.loginInfo, isNull);
    });

    test('write_whenTheSourceIsGone_doesNotThrow', () async {
      // 登录过程中源可能被删掉：写不进去只是丢一份表单值，不该让脚本失败。
      await repository.write('https://gone.test', <String, String>{'账号': 'a'});

      expect(await dao.findById(1), isNull);
    });
  });
}
