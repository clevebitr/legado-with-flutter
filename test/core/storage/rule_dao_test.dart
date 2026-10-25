import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/rule_dao.dart';
import 'package:flutter_test/flutter_test.dart';

/// A database with the rules table, in memory.
({ReaderDatabase database, RuleDao dao}) _fixture() {
  final ReaderDatabase database = ReaderDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  return (database: database, dao: RuleDao(database));
}

void main() {
  group('RuleDao', () {
    test('insert_givenNoSortOrder_appendsInsideItsKind', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();

      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '第一条',
        payload: <String, Object?>{'pattern': 'a', 'replacement': 'b'},
      );
      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '第二条',
        payload: <String, Object?>{'pattern': 'c', 'replacement': 'd'},
      );
      await fixture.dao.insert(
        kind: RuleKind.highlight,
        name: '另一类',
        payload: <String, Object?>{'pattern': 'e'},
      );

      final List<RuleRow> replace = await fixture.dao.ofKind(RuleKind.replace);
      expect(replace.map((RuleRow row) => row.name), <String>['第一条', '第二条']);
      expect(replace.map((RuleRow row) => row.sortOrder), <int>[0, 1]);
      // 每一类各自从 0 开始排序：另一个 kind 的行不影响它。
      expect(
        (await fixture.dao.ofKind(RuleKind.highlight)).single.sortOrder,
        0,
      );
    });

    test('updateSortOrder_givenANewOrder_movesTheRow', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();
      final int first = await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '第一',
        payload: const <String, Object?>{},
      );
      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '第二',
        payload: const <String, Object?>{},
      );

      await fixture.dao.updateSortOrder(first, 2);

      expect(
        (await fixture.dao.ofKind(RuleKind.replace))
            .map((RuleRow row) => row.name),
        <String>['第二', '第一'],
      );
    });

    test('byId_givenAnExistingRow_answersIt', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();
      final int id = await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '净化',
        payload: <String, Object?>{'pattern': 'a'},
      );

      final RuleRow? row = await fixture.dao.byId(id);

      expect(row?.name, '净化');
      expect(row?.kind, RuleKind.replace);
    });

    test('byId_givenAnUnknownId_answersNull', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();

      expect(await fixture.dao.byId(4242), isNull);
    });

    test('ofKind_givenSeveralKinds_answersOnlyThatKind', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();

      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: 'r',
        payload: const <String, Object?>{},
      );
      await fixture.dao.insert(
        kind: RuleKind.dict,
        name: 'd',
        payload: const <String, Object?>{},
      );

      expect(
        (await fixture.dao.ofKind(RuleKind.replace))
            .map((RuleRow row) => row.name),
        <String>['r'],
      );
    });

    test('ofKind_givenManualOrder_sortsByItNotByInsertion', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();

      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '后',
        payload: const <String, Object?>{},
        sortOrder: 5,
      );
      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '前',
        payload: const <String, Object?>{},
        sortOrder: 1,
      );

      expect(
        (await fixture.dao.ofKind(RuleKind.replace))
            .map((RuleRow row) => row.name),
        <String>['前', '后'],
      );
    });

    test('enabledOfKind_givenADisabledRow_leavesItOut', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();

      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '开着',
        payload: const <String, Object?>{},
      );
      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '关着',
        payload: const <String, Object?>{},
        isEnabled: false,
      );

      expect(
        (await fixture.dao.enabledOfKind(RuleKind.replace))
            .map((RuleRow row) => row.name),
        <String>['开着'],
      );
    });

    test('updateRow_givenOnlyAName_keepsThePayloadAndSwitch', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();
      final int id = await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '旧名',
        payload: <String, Object?>{'pattern': 'a'},
        isEnabled: true,
      );

      await fixture.dao.updateRow(id, name: '新名');

      final RuleRow row = (await fixture.dao.ofKind(RuleKind.replace)).single;
      expect(row.name, '新名');
      expect(row.payload, '{"pattern":"a"}');
      expect(row.isEnabled, isTrue);
    });

    test('updateRow_givenAPayload_encodesItAsJson', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();
      final int id = await fixture.dao.insert(
        kind: RuleKind.replace,
        name: 'n',
        payload: const <String, Object?>{},
      );

      await fixture.dao.updateRow(
        id,
        payload: <String, Object?>{'pattern': 'x', 'isRegex': true},
        isEnabled: false,
      );

      final RuleRow row = (await fixture.dao.ofKind(RuleKind.replace)).single;
      expect(row.payload, '{"pattern":"x","isRegex":true}');
      expect(row.isEnabled, isFalse);
    });

    test('deleteById_givenAnExistingRow_removesItAndReportsTrue', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();
      final int id = await fixture.dao.insert(
        kind: RuleKind.replace,
        name: 'n',
        payload: const <String, Object?>{},
      );

      expect(await fixture.dao.deleteById(id), isTrue);
      expect(await fixture.dao.ofKind(RuleKind.replace), isEmpty);
      // 删过就不再存在：再删一次是「没删到」，不是错误。
      expect(await fixture.dao.deleteById(id), isFalse);
    });

    test('deleteKind_givenTwoKinds_removesOnlyOne', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();
      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: 'a',
        payload: const <String, Object?>{},
      );
      await fixture.dao.insert(
        kind: RuleKind.highlight,
        name: 'b',
        payload: const <String, Object?>{},
      );

      expect(await fixture.dao.deleteKind(RuleKind.replace), 1);
      expect(await fixture.dao.ofKind(RuleKind.replace), isEmpty);
      expect(await fixture.dao.ofKind(RuleKind.highlight), hasLength(1));
    });

    test('hasAny_givenAnEmptyKind_answersFalseEvenAfterDelete', () async {
      // 播种用它判断「这个 kind 有没有被用户清空过」（ADR-0070 §决策 4）。
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();

      expect(await fixture.dao.hasAny(RuleKind.toc), isFalse);
      await fixture.dao.insert(
        kind: RuleKind.toc,
        name: 'n',
        payload: const <String, Object?>{},
        isEnabled: false,
      );
      expect(await fixture.dao.hasAny(RuleKind.toc), isTrue);
      await fixture.dao.deleteKind(RuleKind.toc);
      expect(await fixture.dao.hasAny(RuleKind.toc), isFalse);
    });

    test('insert_givenBuiltInFlag_keepsIt', () async {
      final ({ReaderDatabase database, RuleDao dao}) fixture = _fixture();

      await fixture.dao.insert(
        kind: RuleKind.replace,
        name: '内置',
        payload: const <String, Object?>{},
        isBuiltIn: true,
        now: DateTime(2026, 10, 24),
      );

      final RuleRow row = (await fixture.dao.ofKind(RuleKind.replace)).single;
      expect(row.isBuiltIn, isTrue);
      expect(row.createdAt, DateTime(2026, 10, 24));
    });

    test('RuleKind_all_coversEveryKindTheDaoDocuments', () {
      // 管理页按这个顺序列出四类；少一个就会有一类规则没有任何入口。
      expect(RuleKind.all, <String>['replace', 'toc', 'dict', 'highlight']);
    });
  });
}
