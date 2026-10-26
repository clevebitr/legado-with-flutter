import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/source_checks.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
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
      String? fingerprint,
      String name = '示例书源',
      String? groupName = '精选',
      int sourceType = 0,
      bool isEnabled = true,
      int customOrder = 0,
      int weight = 7,
      int? respondTime,
    }) => dao.insertNew(
      url: url,
      // 每行一个指纹：`(url, fingerprint)` 是唯一键，测试里要能插多行。
      fingerprint: fingerprint ?? 'fp-$name',
      payload: '{"bookSourceName":"$name"}',
      name: name,
      groupName: groupName,
      sourceType: sourceType,
      isEnabled: isEnabled,
      isExploreEnabled: true,
      customOrder: customOrder,
      weight: weight,
      lastUpdateTime: 1612777312843,
      respondTime: respondTime,
    );

    test('writeCheckState_whenCalled_writesTheCheckColumns', () async {
      final int id = await insert();
      clock.advance(const Duration(days: 2));

      await dao.writeCheckState(
        id: id,
        groupName: '搜索失效, 校验超时',
        comment: '// Error: 搜索失效',
        respondTime: 4321,
      );

      final BookSourceRow row = (await dao.findById(id))!;
      expect(row.groupName, '搜索失效, 校验超时');
      expect(row.comment, '// Error: 搜索失效');
      expect(row.respondTime, 4321);
      expect(row.updatedAt, clock.now());
      // 校验只写这三列（外加 updatedAt），负载与用户态一概不动（ADR-0043 §决策 1）。
      expect(row.payload, '{"bookSourceName":"示例书源"}');
      expect(row.isEnabled, isTrue);
      expect(row.importedAt, DateTime(2026, 10, 14));
    });

    test('findAll_whenNothingWasImported_returnsNothing', () async {
      expect(await dao.findAll(), isEmpty);
    });

    test('insertNew_whenCalled_writesEveryProjectedColumn', () async {
      final int id = await insert();
      final BookSourceRow row = (await dao.findById(id))!;

      expect(row.url, 'https://example.test');
      expect(row.fingerprint, 'fp-示例书源');
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

    test('findAll_givenTheWeightOrder_putsTheHeaviestFirst', () async {
      await insert(name: '轻', weight: 1, customOrder: 0);
      await insert(name: '重', weight: 9, customOrder: 1);

      // 方向由调用方给：视图把「权重」的默认方向初始化成降序（ADR-0052 §决策 4），
      // DAO 只负责按这个方向排。
      final List<BookSourceRow> rows = await dao.findAll(
        order: BookSourceSortOrder.weight,
        ascending: false,
      );

      expect(rows.map((BookSourceRow row) => row.name), <String>['重', '轻']);
    });

    test('findAll_givenTheRespondTimeOrder_putsNeverCheckedLast', () async {
      // 未校验 = NULL，不是 0 ms：升序时它必须排在所有有值的后面（ADR-0045 §决策 2）。
      await insert(name: '未校验', respondTime: null, customOrder: 0);
      await insert(name: '慢', respondTime: 900, customOrder: 1);
      await insert(name: '快', respondTime: 120, customOrder: 2);

      final List<BookSourceRow> rows = await dao.findAll(
        order: BookSourceSortOrder.respondTime,
      );

      expect(rows.map((BookSourceRow row) => row.name), <String>[
        '快',
        '慢',
        '未校验',
      ]);
    });

    test(
      'findAll_givenTheNameOrder_keepsEnabledFirstAsTheTieBreaker',
      () async {
        // 「启用优先」对所有排序键都成立：禁用源不该插在启用源中间。
        await insert(name: 'b', isEnabled: false, customOrder: 0);
        await insert(name: 'a', isEnabled: true, customOrder: 1);

        final List<BookSourceRow> rows = await dao.findAll(
          order: BookSourceSortOrder.name,
        );

        expect(rows.map((BookSourceRow row) => row.name), <String>['a', 'b']);
      },
    );

    test('findAll_givenTheWeightOrder_breaksTiesByTheManualOrder', () async {
      // 同权重时回落到 (启用 → 手动序 → id)：同一份数据任何一次查询都是同一顺序。
      await insert(name: 'second', weight: 5, customOrder: 1);
      await insert(name: 'first', weight: 5, customOrder: 0);

      final List<BookSourceRow> rows = await dao.findAll(
        order: BookSourceSortOrder.weight,
        ascending: false,
      );

      expect(rows.map((BookSourceRow row) => row.name), <String>[
        'first',
        'second',
      ]);
    });

    test('reorder_whenCalled_renumbersTheManualOrderInOneGo', () async {
      final int a = await insert(name: 'a', customOrder: 0);
      final int b = await insert(name: 'b', customOrder: 1);
      final int c = await insert(name: 'c', customOrder: 2);

      // 拖成 c → a → b：整体编号 0..2，而不是交换相邻两行（ADR-0045 §决策 3）。
      await dao.reorder(<int>[c, a, b]);

      final List<BookSourceRow> rows = await dao.findAll();
      expect(rows.map((BookSourceRow row) => row.name), <String>[
        'c',
        'a',
        'b',
      ]);
      expect(rows.map((BookSourceRow row) => row.customOrder), <int>[0, 1, 2]);
    });

    test('reorder_givenAnIdThatIsGone_skipsIt', () async {
      final int a = await insert(name: 'a', customOrder: 0);
      final int b = await insert(name: 'b', customOrder: 1);

      await dao.reorder(<int>[b, 404, a]);

      final List<BookSourceRow> rows = await dao.findAll();
      expect(rows.map((BookSourceRow row) => row.name), <String>['b', 'a']);
    });

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

    test('applyCheck_whenCalled_writesTheColumnsAndOneHistoryRow', () async {
      final int id = await insert();
      clock.advance(const Duration(minutes: 3));

      await dao.applyCheck(
        id: id,
        groupName: '搜索失效',
        comment: '// Error: 搜索失效',
        respondTime: 900,
        status: 'failed',
        invalidGroups: '搜索失效',
        errorComment: '搜索失效',
        elapsedMillis: 900,
      );

      final BookSourceRow row = (await dao.findById(id))!;
      expect(row.groupName, '搜索失效');
      expect(row.respondTime, 900);
      final List<SourceCheckRow> history = await database
          .select(database.sourceChecks)
          .get();
      expect(history, hasLength(1));
      expect(history.single.sourceId, id);
      expect(history.single.status, 'failed');
      expect(history.single.invalidGroups, '搜索失效');
      expect(history.single.errorComment, '搜索失效');
      expect(history.single.elapsedMillis, 900);
      expect(history.single.checkedAt, clock.now());
    });

    test('latestChecks_givenACancelledRun_answersTheLastVerdict', () async {
      final int id = await insert();
      await dao.applyCheck(
        id: id,
        groupName: null,
        comment: null,
        respondTime: 120,
        status: 'succeeded',
        invalidGroups: null,
        errorComment: null,
        elapsedMillis: 120,
      );
      clock.advance(const Duration(minutes: 1));
      await dao.applyCheck(
        id: id,
        groupName: null,
        comment: null,
        respondTime: 50,
        status: 'cancelled',
        invalidGroups: null,
        errorComment: null,
        elapsedMillis: 50,
      );

      final Map<int, SourceCheckRow> latest = await dao.latestChecks(
        excludedStatus: 'cancelled',
      );

      // 取消不构成结论（ADR-0043 §后果）：灯与「上次校验」都停在通过那一次。
      expect(latest[id]!.status, 'succeeded');
    });

    test('applyCheck_givenMoreThanTheLimit_keepsTheNewestRows', () async {
      final int id = await insert();
      for (var index = 0; index < checkHistoryLimit + 5; index++) {
        clock.advance(const Duration(minutes: 1));
        await dao.applyCheck(
          id: id,
          groupName: null,
          comment: null,
          respondTime: index,
          status: 'succeeded',
          invalidGroups: null,
          errorComment: null,
          elapsedMillis: index,
        );
      }

      final List<SourceCheckRow> history = await database
          .select(database.sourceChecks)
          .get();
      final Set<int> elapsed = <int>{
        for (final SourceCheckRow row in history) row.elapsedMillis,
      };

      // 只留最近 20 条：最老的 5 条（0-4）被裁掉（ADR-0052 §决策 1）。
      expect(history, hasLength(checkHistoryLimit));
      expect(elapsed.contains(0), isFalse);
      expect(elapsed.contains(4), isFalse);
      expect(elapsed.contains(5), isTrue);
      expect(elapsed.contains(checkHistoryLimit + 4), isTrue);
    });

    test('setExploreEnabledFor_whenCalled_flipsEverySelectedRow', () async {
      final int a = await insert(url: 'https://a.test', fingerprint: 'a');
      final int b = await insert(url: 'https://b.test', fingerprint: 'b');

      await dao.setExploreEnabledFor(<int>[a, b], isExploreEnabled: false);

      expect((await dao.findById(a))!.isExploreEnabled, isFalse);
      expect((await dao.findById(b))!.isExploreEnabled, isFalse);
    });

    test('moveToEdge_whenToTop_movesTheSelectionInFrontOfTheRest', () async {
      final int a = await insert(
        url: 'https://a.test',
        fingerprint: 'a',
        customOrder: 0,
      );
      final int b = await insert(
        url: 'https://b.test',
        fingerprint: 'b',
        customOrder: 1,
      );
      final int c = await insert(
        url: 'https://c.test',
        fingerprint: 'c',
        customOrder: 2,
      );

      await dao.moveToEdge(<int>[c], toTop: true);
      expect((await dao.findAll()).map((BookSourceRow row) => row.id), <int>[
        c,
        a,
        b,
      ]);

      await dao.moveToEdge(<int>[c], toTop: false);
      expect((await dao.findAll()).map((BookSourceRow row) => row.id), <int>[
        a,
        b,
        c,
      ]);
    });

    test(
      'findAll_givenDescendingName_answersTheReverseAlphabeticalOrder',
      () async {
        await insert(url: 'https://a.test', fingerprint: 'a', name: 'alpha');
        await insert(url: 'https://b.test', fingerprint: 'b', name: 'beta');

        final List<BookSourceRow> rows = await dao.findAll(
          order: BookSourceSortOrder.name,
          ascending: false,
        );

        expect(rows.map((BookSourceRow row) => row.name), <String>[
          'beta',
          'alpha',
        ]);
      },
    );

    test('deleteById_whenTheRowHasHistory_removesTheHistoryToo', () async {
      final int id = await insert();
      await dao.applyCheck(
        id: id,
        groupName: null,
        comment: null,
        respondTime: 10,
        status: 'succeeded',
        invalidGroups: null,
        errorComment: null,
        elapsedMillis: 10,
      );

      await dao.deleteById(id);

      expect(await database.select(database.sourceChecks).get(), isEmpty);
    });

    test('deleteAll_whenRowsHaveHistory_clearsTheHistory', () async {
      final int id = await insert();
      await dao.applyCheck(
        id: id,
        groupName: null,
        comment: null,
        respondTime: 10,
        status: 'succeeded',
        invalidGroups: null,
        errorComment: null,
        elapsedMillis: 10,
      );

      await dao.deleteAll();

      expect(await database.select(database.sourceChecks).get(), isEmpty);
    });

    test('writeLoginInfo_givenJson_storesItAndNullClearsIt', () async {
      // M22-a 第二批（ADR-0072 §决策 3）：登录信息是「按源的用户态」，只有登录页写它。
      final int id = await insert();

      await dao.writeLoginInfo(id: id, loginInfo: '{"账号":"n"}');
      expect((await dao.findById(id))?.loginInfo, '{"账号":"n"}');

      await dao.writeLoginInfo(id: id, loginInfo: null);
      expect((await dao.findById(id))?.loginInfo, isNull);
    });
  });
}
