import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clock a test can move by hand; timestamps must never depend on wall time
/// (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

void main() {
  group('BookSourceDao', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late BookSourceDao dao;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime(2026, 10, 14));
      dao = BookSourceDao(database, clock: clock);
    });

    tearDown(() => database.close());

    /// Inserts one row with [url] / [fingerprint], defaulting everything else.
    Future<int> insert({
      String url = 'https://example.test',
      String fingerprint = 'fp-1',
      String name = '示例书源',
      String? groupName = '精选',
      int sourceType = 0,
      bool isEnabled = true,
      int customOrder = 0,
    }) => dao.insertNew(
      url: url,
      fingerprint: fingerprint,
      payload: '{"bookSourceName":"$name"}',
      name: name,
      groupName: groupName,
      sourceType: sourceType,
      isEnabled: isEnabled,
      customOrder: customOrder,
      weight: 7,
      lastUpdateTime: 1612777312843,
      respondTime: null,
    );

    test('findAll_whenNothingWasImported_returnsNothing', () async {
      expect(await dao.findAll(), isEmpty);
    });

    test('insertNew_whenCalled_writesEveryProjectedColumn', () async {
      final int id = await insert();
      final BookSourceRow row = (await dao.findById(id))!;

      expect(row.url, 'https://example.test');
      expect(row.fingerprint, 'fp-1');
      expect(row.payload, '{"bookSourceName":"示例书源"}');
      expect(row.name, '示例书源');
      expect(row.groupName, '精选');
      expect(row.sourceType, 0);
      expect(row.isEnabled, isTrue);
      expect(row.customOrder, 0);
      expect(row.weight, 7);
      expect(row.lastUpdateTime, 1612777312843);
      expect(row.respondTime, isNull);
      expect(row.importedAt, clock.now());
      expect(row.updatedAt, clock.now());
    });

    test(
      'findAll_givenSeveralRows_ordersByEnabledThenCustomOrderThenId',
      () async {
        // ADR-0040 §后果：列表与「默认选中源」必须共用同一个顺序口径。
        final int disabled = await insert(
          url: 'https://c.test',
          fingerprint: 'c',
          name: 'c',
          isEnabled: false,
        );
        final int lateOrder = await insert(
          url: 'https://b.test',
          fingerprint: 'b',
          name: 'b',
          customOrder: 5,
        );
        final int firstOrder = await insert(
          url: 'https://a.test',
          fingerprint: 'a',
          name: 'a',
          customOrder: 1,
        );

        expect((await dao.findAll()).map((BookSourceRow row) => row.id), <int>[
          firstOrder,
          lateOrder,
          disabled,
        ]);
      },
    );

    test('findById_givenAnUnknownId_returnsNull', () async {
      expect(await dao.findById(404), isNull);
    });

    test('findIdentity_givenTheSameUrlAndFingerprint_returnsTheRow', () async {
      final int id = await insert(url: 'https://a.test', fingerprint: 'fp-a');

      final BookSourceRow? row = await dao.findIdentity(
        url: 'https://a.test',
        fingerprint: 'fp-a',
      );

      expect(row?.id, id);
    });

    test('findIdentity_givenAnotherFingerprint_returnsNull', () async {
      await insert(url: 'https://a.test', fingerprint: 'fp-a');

      expect(
        await dao.findIdentity(url: 'https://a.test', fingerprint: 'fp-b'),
        isNull,
      );
    });

    test(
      'insertNew_givenTheSameIdentityTwice_isRejectedByTheUniqueKey',
      () async {
        // 唯一键是 ADR-0040 §决策 1 的落点：幂等由仓储在插入前判，但库本身也不许出现重复身份。
        await insert(url: 'https://a.test', fingerprint: 'fp-a');

        await expectLater(
          insert(url: 'https://a.test', fingerprint: 'fp-a'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'refreshPayload_givenAnExistingRow_touchesOnlyPayloadAndTime',
      () async {
        final int id = await insert(isEnabled: false, customOrder: 9);
        clock.advance(const Duration(minutes: 5));

        await dao.refreshPayload(id: id, payload: '{"bookSourceName":"新负载"}');
        final BookSourceRow row = (await dao.findById(id))!;

        expect(row.payload, '{"bookSourceName":"新负载"}');
        expect(row.updatedAt, clock.now());
        // 用户态与首次导入时间不动（ADR-0040 §决策 3）。
        expect(row.isEnabled, isFalse);
        expect(row.customOrder, 9);
        expect(row.importedAt, DateTime(2026, 10, 14));
      },
    );

    test('setEnabled_givenAnExistingRow_flipsOnlyTheFlag', () async {
      final int id = await insert(isEnabled: false);

      await dao.setEnabled(id: id, isEnabled: true);

      expect((await dao.findById(id))!.isEnabled, isTrue);
    });

    test('deleteById_givenAnExistingRow_removesExactlyThatRow', () async {
      final int kept = await insert(url: 'https://keep.test', fingerprint: 'k');
      final int removed = await insert(
        url: 'https://gone.test',
        fingerprint: 'g',
      );

      expect(await dao.deleteById(removed), 1);
      expect(await dao.findById(removed), isNull);
      expect((await dao.findAll()).single.id, kept);
    });

    test('deleteById_givenAnUnknownId_removesNothing', () async {
      expect(await dao.deleteById(404), 0);
    });

    test('deleteAll_whenRowsExist_removesEveryRow', () async {
      await insert(url: 'https://a.test', fingerprint: 'a');
      await insert(url: 'https://b.test', fingerprint: 'b');

      expect(await dao.deleteAll(), 2);
      expect(await dao.findAll(), isEmpty);
    });
  });
}
