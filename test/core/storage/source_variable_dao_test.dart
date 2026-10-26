import 'package:drift/native.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/source_variable_dao.dart';
import 'package:flutter_reader/core/storage/source_variable_dao_repository.dart';
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
  group('SourceVariableDao', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late SourceVariableDao dao;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime.utc(2026, 10, 26));
      dao = SourceVariableDao(database, clock: clock);
    });

    tearDown(() => database.close());

    test('findAll_givenNoRows_answersNothing', () async {
      expect(await dao.findAll('https://a.test'), isEmpty);
    });

    test('upsert_givenTheSameName_twice_keepsOneRowWithTheNewValue', () async {
      await dao.upsert(sourceUrl: 'https://a.test', name: 'token', value: 'a');
      clock.advance(const Duration(minutes: 1));
      await dao.upsert(sourceUrl: 'https://a.test', name: 'token', value: 'b');

      final List<SourceVariableRow> rows = await dao.findAll('https://a.test');

      expect(rows, hasLength(1));
      expect(rows.single.value, 'b');
      // drift 把 DateTime 存成 Unix 秒并以本地时区读回，比较的是同一个瞬间。
      expect(rows.single.updatedAt.toUtc(), clock.now().toUtc());
    });

    test('findAll_givenSeveralSources_answersOnlyTheAskedOne', () async {
      await dao.upsert(sourceUrl: 'https://a.test', name: 'x', value: '1');
      await dao.upsert(sourceUrl: 'https://b.test', name: 'x', value: '2');

      final List<SourceVariableRow> rows = await dao.findAll('https://b.test');

      expect(rows.single.value, '2');
    });

    test('findAll_ordersByName', () async {
      await dao.upsert(sourceUrl: 'https://a.test', name: 'z', value: '1');
      await dao.upsert(sourceUrl: 'https://a.test', name: 'a', value: '2');

      expect(
        (await dao.findAll('https://a.test'))
            .map((SourceVariableRow row) => row.name),
        <String>['a', 'z'],
      );
    });

    test('deleteOne_givenARow_removesItAndIgnoresAMissingOne', () async {
      await dao.upsert(sourceUrl: 'https://a.test', name: 'x', value: '1');

      expect(await dao.deleteOne(sourceUrl: 'https://a.test', name: 'x'), 1);
      expect(await dao.deleteOne(sourceUrl: 'https://a.test', name: 'x'), 0);
    });

    test('deleteAll_givenOneSource_keepsTheOtherSources', () async {
      await dao.upsert(sourceUrl: 'https://a.test', name: 'x', value: '1');
      await dao.upsert(sourceUrl: 'https://a.test', name: 'y', value: '2');
      await dao.upsert(sourceUrl: 'https://b.test', name: 'x', value: '3');

      expect(await dao.deleteAll('https://a.test'), 2);
      expect(await dao.findAll('https://a.test'), isEmpty);
      expect(await dao.findAll('https://b.test'), hasLength(1));
    });
  });

  group('SourceVariableDaoRepository', () {
    late ReaderDatabase database;
    late SourceVariableDaoRepository repository;
    late FakeLogPrinter printer;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      printer = FakeLogPrinter();
      repository = SourceVariableDaoRepository(
        SourceVariableDao(database, clock: _FixedClock(DateTime.utc(2026))),
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );
    });

    tearDown(() => database.close());

    test('read_givenNoRows_answersAnEmptyMap', () async {
      expect(await repository.read('https://a.test'), isEmpty);
    });

    test('write_givenValues_roundTripsThroughRead', () async {
      await repository.write('https://a.test', <String, String?>{
        'token': 'abc',
        'empty': '',
      });

      expect(await repository.read('https://a.test'), <String, String>{
        'token': 'abc',
        'empty': '',
      });
    });

    test('write_givenANullValue_deletesTheRow', () async {
      await repository.write('https://a.test', <String, String?>{'token': 'a'});

      await repository.write('https://a.test', <String, String?>{
        'token': null,
      });

      expect(await repository.read('https://a.test'), isEmpty);
    });
  });
}
