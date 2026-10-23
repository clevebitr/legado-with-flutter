import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/data/book_source_repository_impl.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../support/fake_log_printer.dart';

/// Clock a test can move by hand (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

/// One minimal but valid book source object, raw as an import would hand it over.
Map<String, Object?> _entry({
  String name = '示例书源',
  String url = 'https://a.test',
  String content = 'class.body',
  bool? enabled,
  bool? exploreEnabled,
  String? group,
  Object? customOrder,
  Object? weight,
}) {
  // 两个可选项用赋值而不是集合字面量里的 `if`：analyzer 的 `use_null_aware_elements` 拒绝后者。
  final Map<String, Object?> entry = <String, Object?>{
    'bookSourceName': name,
    'bookSourceUrl': url,
    'ruleSearch': <String, Object?>{
      'bookList': 'class.item',
      'name': 'class.n',
    },
    'ruleToc': <String, Object?>{'chapterList': 'class.c'},
    'ruleContent': <String, Object?>{'content': content},
  };
  if (enabled != null) {
    entry['enabled'] = enabled;
  }
  if (exploreEnabled != null) {
    entry['enabledExplore'] = exploreEnabled;
  }
  if (group != null) {
    entry['bookSourceGroup'] = group;
  }
  if (customOrder != null) {
    entry['customOrder'] = customOrder;
  }
  if (weight != null) {
    entry['weight'] = weight;
  }

  return entry;
}

void main() {
  group('BookSourceRepositoryImpl', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late FakeLogPrinter printer;
    late BookSourceDao dao;
    late BookSourceRepositoryImpl repository;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime(2026, 10, 14));
      printer = FakeLogPrinter();
      dao = BookSourceDao(database, clock: clock);
      repository = BookSourceRepositoryImpl(
        dao: dao,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );
    });

    tearDown(() => database.close());

    test('saveAll_givenANewEntry_insertsIt', () async {
      final BookSourceSaveReport report = await repository.saveAll(
        <Map<String, Object?>>[_entry()],
      );

      expect(report.inserted, 1);
      expect(report.refreshed, 0);
      final StoredBookSource stored = (await repository.getAll()).single;
      expect(stored.source.name, '示例书源');
      expect(stored.source.url, 'https://a.test');
      expect(stored.isEnabled, isTrue);
      expect(stored.customOrder, 0);
      expect(stored.importedAt, clock.now());
    });

    test('saveAll_givenTheSameEntryTwice_isIdempotent', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final int firstId = (await repository.getAll()).single.id;
      clock.advance(const Duration(days: 1));

      final BookSourceSaveReport second = await repository.saveAll(
        <Map<String, Object?>>[_entry()],
      );

      expect(second.inserted, 0);
      expect(second.refreshed, 1);
      final List<StoredBookSource> all = await repository.getAll();
      expect(all.single.id, firstId);
      expect(all.single.importedAt, DateTime(2026, 10, 14));
    });

    test('saveAll_givenAReorderedEntry_treatsItAsTheSameSource', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final Map<String, Object?> reordered = <String, Object?>{
        for (final MapEntry<String, Object?> entry
            in _entry().entries.toList().reversed)
          entry.key: entry.value,
      };

      final BookSourceSaveReport report = await repository.saveAll(
        <Map<String, Object?>>[reordered],
      );

      expect(report.inserted, 0);
      expect(report.refreshed, 1);
      expect(await repository.getAll(), hasLength(1));
    });

    test('saveAll_givenSameUrlWithDifferentRules_keepsBothSources', () async {
      // ADR-0040 §决策 3：与上游「URL 即主键、后者覆盖」的登记差异。
      await repository.saveAll(<Map<String, Object?>>[
        _entry(content: 'class.a'),
      ]);

      final BookSourceSaveReport report = await repository.saveAll(
        <Map<String, Object?>>[_entry(content: 'class.b')],
      );

      expect(report.inserted, 1);
      expect(await repository.getAll(), hasLength(2));
    });

    test(
      'saveAll_givenAnAlreadyStoredIdentity_keepsTheUsersEnabledFlag',
      () async {
        await repository.saveAll(<Map<String, Object?>>[_entry()]);
        final int id = (await repository.getAll()).single.id;
        await repository.setEnabled(id: id, isEnabled: false);

        // 负载里写着 enabled=true，但重新导入不得把用户关掉的源又打开（ADR-0040 §决策 3）。
        await repository.saveAll(<Map<String, Object?>>[_entry()]);

        expect((await repository.findById(id))!.isEnabled, isFalse);
      },
    );

    test(
      'saveAll_givenDisabledEntryInThePayload_startsTheRowDisabled',
      () async {
        await repository.saveAll(<Map<String, Object?>>[
          _entry(enabled: false),
        ]);

        expect((await repository.getAll()).single.isEnabled, isFalse);
      },
    );

    test(
      'saveAll_givenUserStateOfTheWrongType_usesTheColumnDefaults',
      () async {
        // 投影列只在导入时读一次；类型不对时回退到默认值，绝不让导入失败（ADR-0040 §决策 6）。
        await repository.saveAll(<Map<String, Object?>>[
          _entry(customOrder: 'x'),
        ]);

        final StoredBookSource stored = (await repository.getAll()).single;
        expect(stored.customOrder, 0);
        expect(stored.isEnabled, isTrue);
      },
    );

    test('findById_givenAnUnknownId_returnsNull', () async {
      expect(await repository.findById(404), isNull);
    });

    test('getAll_givenARowWhosePayloadIsNotJson_skipsItWithAWarning', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      await dao.insertNew(
        url: 'https://broken.test',
        fingerprint: 'broken',
        payload: 'not json',
        name: '坏行',
        groupName: null,
        sourceType: 0,
        isEnabled: true,
        isExploreEnabled: true,
        customOrder: 0,
        weight: 0,
        lastUpdateTime: null,
        respondTime: null,
      );

      expect(await repository.getAll(), hasLength(1));
      expect(
        printer.events.last.message.toString(),
        allOf(contains('https://broken.test'), contains('not JSON')),
      );
    });

    test(
      'getAll_givenARowWhosePayloadIsNotAnObject_skipsItWithAWarning',
      () async {
        await dao.insertNew(
          url: 'https://array.test',
          fingerprint: 'array',
          payload: '[1,2]',
          name: '坏行',
          groupName: null,
          sourceType: 0,
          isEnabled: true,
          isExploreEnabled: true,
          customOrder: 0,
          weight: 0,
          lastUpdateTime: null,
          respondTime: null,
        );

        expect(await repository.getAll(), isEmpty);
        expect(
          printer.events.last.message.toString(),
          contains('not a JSON object'),
        );
      },
    );

    test('getAll_givenARowTheModelRejects_skipsItWithAWarning', () async {
      await dao.insertNew(
        url: 'https://missing.test',
        fingerprint: 'missing',
        // 缺 `ruleToc`：JSON 合法，但 checked 模式下的模型解析必须拒绝（ADR-0022）。
        payload:
            '{"bookSourceName":"x","bookSourceUrl":"https://missing.test"}',
        name: '坏行',
        groupName: null,
        sourceType: 0,
        isEnabled: true,
        isExploreEnabled: true,
        customOrder: 0,
        weight: 0,
        lastUpdateTime: null,
        respondTime: null,
      );

      expect(await repository.getAll(), isEmpty);
      expect(
        printer.events.last.message.toString(),
        contains('no longer parses'),
      );
    });

    test(
      'applyCheckReport_givenInvalidGroups_writesGroupsNoteAndRespondTime',
      () async {
        await repository.saveAll(<Map<String, Object?>>[_entry()]);
        final int id = (await repository.getAll()).single.id;

        final bool applied = await repository.applyCheckReport(
          id: id,
          report: const SourceCheckReport(
            status: SourceCheckStatus.failed,
            invalidGroups: <String>[searchInvalidGroup, searchTocInvalidGroup],
            errorComment: '搜索失效, 搜索目录失效',
            elapsedMillis: 1234,
          ),
        );

        expect(applied, isTrue);
        final BookSourceRow row = (await dao.findById(id))!;
        expect(row.groupName, '搜索失效, 搜索目录失效');
        expect(row.comment, '// Error: 搜索失效, 搜索目录失效');
        expect(row.respondTime, 1234);
      },
    );

    test(
      'applyCheckReport_givenASecondHealthyRun_clearsThePreviousVerdict',
      () async {
        // ADR-0043 §后果：重新校验必须先清掉上次的「失效」分组与错误注释，否则修好的源
        // 会永远显示成坏的。
        await repository.saveAll(<Map<String, Object?>>[_entry()]);
        final int id = (await repository.getAll()).single.id;
        await repository.applyCheckReport(
          id: id,
          report: const SourceCheckReport(
            status: SourceCheckStatus.failed,
            invalidGroups: <String>[searchInvalidGroup],
            errorComment: '搜索失效',
            elapsedMillis: 1234,
          ),
        );

        await repository.applyCheckReport(
          id: id,
          report: const SourceCheckReport(
            status: SourceCheckStatus.succeeded,
            elapsedMillis: 900,
          ),
        );

        final BookSourceRow row = (await dao.findById(id))!;
        expect(row.groupName, isNull);
        expect(row.comment, isNull);
        expect(row.respondTime, 900);
      },
    );

    test('applyCheckReport_givenTheUsersOwnGroup_keepsIt', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final int id = (await repository.getAll()).single.id;
      await dao.writeCheckState(
        id: id,
        groupName: '精选, 搜索失效',
        comment: '我自己的说明\n\n// Error: 搜索失效',
        respondTime: 5,
      );

      await repository.applyCheckReport(
        id: id,
        report: const SourceCheckReport(
          status: SourceCheckStatus.succeeded,
          elapsedMillis: 42,
        ),
      );

      final BookSourceRow row = (await dao.findById(id))!;
      expect(row.groupName, '精选');
      expect(row.comment, '我自己的说明');
      expect(row.respondTime, 42);
    });

    test('applyCheckReport_givenADeletedRow_answersFalse', () async {
      expect(
        await repository.applyCheckReport(
          id: 404,
          report: const SourceCheckReport(
            status: SourceCheckStatus.succeeded,
            elapsedMillis: 1,
          ),
        ),
        isFalse,
      );
      expect(
        printer.events.last.message.toString(),
        contains('no row to land on'),
      );
    });

    test('getAll_givenACheckVerdict_answersTheColumnProjections', () async {
      // 校验写的是列（ADR-0043 §决策 1）：仓储必须把它们交给界面，否则列表显示的还是
      // 校验之前的分组与注释（ADR-0045 §决策 1）。
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final int id = (await repository.getAll()).single.id;
      const SourceCheckReport report = SourceCheckReport(
        status: SourceCheckStatus.failed,
        invalidGroups: <String>[searchInvalidGroup],
        errorComment: searchInvalidGroup,
        elapsedMillis: 777,
      );

      await repository.applyCheckReport(id: id, report: report);

      final StoredBookSource stored = (await repository.getAll()).single;
      expect(stored.groupName, searchInvalidGroup);
      expect(stored.comment, '// Error: $searchInvalidGroup');
      expect(stored.respondTime, 777);
      // 负载里的分组仍是导入时那一份，没被校验改写。
      expect(stored.source.group, isNull);
    });

    test('getAll_givenTheWeightOrder_answersTheHeaviestFirst', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(name: '轻', url: 'https://light.test', weight: 1),
        _entry(name: '重', url: 'https://heavy.test', weight: 9),
      ]);

      // 方向是独立轴：视图给「权重」的默认方向是降序（ADR-0052 §决策 4）。
      final List<StoredBookSource> rows = await repository.getAll(
        order: BookSourceSortOrder.weight,
        ascending: false,
      );

      expect(
        rows.map((StoredBookSource source) => source.source.name),
        <String>['重', '轻'],
      );
    });

    test('reorder_whenCalled_renumbersTheManualOrder', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(name: 'a', url: 'https://a.test'),
        _entry(name: 'b', url: 'https://b.test'),
      ]);
      final List<StoredBookSource> before = await repository.getAll();
      final List<int> reversed = before
          .map((StoredBookSource source) => source.id)
          .toList()
          .reversed
          .toList();

      await repository.reorder(reversed);

      final List<StoredBookSource> after = await repository.getAll();
      expect(after.map((StoredBookSource source) => source.id), reversed);
      expect(after.map((StoredBookSource source) => source.customOrder), <int>[
        0,
        1,
      ]);
    });

    test('payloadOf_givenARow_answersTheImportedBytes', () async {
      final Map<String, Object?> entry = _entry();
      await repository.saveAll(<Map<String, Object?>>[entry]);
      final int id = (await repository.getAll()).single.id;

      // ADR-0050 §决策 4：导出的是**原文**，不是模型重建。
      expect(
        await repository.payloadOf(id),
        contains('"bookSourceUrl":"https://a.test"'),
      );
      expect(await repository.payloadOf(999), isNull);
    });

    test('setEnabledFor_givenASelection_flipsEveryRow', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(name: 'a', url: 'https://a.test'),
        _entry(name: 'b', url: 'https://b.test'),
      ]);
      final List<int> ids = (await repository.getAll())
          .map((StoredBookSource source) => source.id)
          .toList();

      await repository.setEnabledFor(ids, isEnabled: false);

      expect(
        (await repository.getAll()).every(
          (StoredBookSource source) => !source.isEnabled,
        ),
        isTrue,
      );
    });

    test('deleteMany_givenAWholeSelection_removesThemAll', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(name: 'a', url: 'https://a.test'),
        _entry(name: 'b', url: 'https://b.test'),
      ]);
      final List<int> ids = (await repository.getAll())
          .map((StoredBookSource source) => source.id)
          .toList();

      await repository.deleteMany(ids);

      expect(await repository.getAll(), isEmpty);
    });

    test('setGroupFor_givenAGroup_writesThePayloadOnly', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final StoredBookSource before = (await repository.getAll()).single;

      await repository.setGroupFor(<int>[before.id], '精选');

      final StoredBookSource after = (await repository.getAll()).single;
      expect(after.source.group, '精选');
      // 身份不变（分组不在指纹里），校验列也不动（ADR-0050 §决策 1）。
      expect(after.groupName, isNull);
      expect(after.comment, isNull);
      expect(after.id, before.id);
    });

    test('setGroupFor_givenNull_clearsTheGroup', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final int id = (await repository.getAll()).single.id;
      await repository.setGroupFor(<int>[id], '精选');

      await repository.setGroupFor(<int>[id], null);

      expect((await repository.getAll()).single.source.group, isNull);
    });

    test('update_givenAChangedField_savesAndKeepsUserState', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final StoredBookSource before = (await repository.getAll()).single;
      await repository.setEnabled(id: before.id, isEnabled: false);

      final BookSourceEditOutcome outcome = await repository.update(
        id: before.id,
        entry: _entry(name: '改名之后'),
      );

      expect(outcome, BookSourceEditOutcome.saved);
      final StoredBookSource after = (await repository.getAll()).single;
      expect(after.source.name, '改名之后');
      // 用户态不被编辑重置（ADR-0050 §决策 3）。
      expect(after.isEnabled, isFalse);
    });

    test('update_givenAnotherRowsIdentity_refusesTheEdit', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(name: 'a', url: 'https://a.test', content: 'class.body'),
        _entry(name: 'b', url: 'https://b.test', content: 'class.body'),
      ]);
      final List<StoredBookSource> rows = await repository.getAll();
      final StoredBookSource first = rows.firstWhere(
        (StoredBookSource source) => source.source.name == 'a',
      );

      // 把 a 改成与 b 完全相同的 (url, 指纹)：显式失败，不合并、不删行。
      final BookSourceEditOutcome outcome = await repository.update(
        id: first.id,
        entry: _entry(name: 'b', url: 'https://b.test', content: 'class.body'),
      );

      expect(outcome, BookSourceEditOutcome.identityConflict);
      expect(await repository.getAll(), hasLength(2));
      expect(
        (await repository.getAll()).map(
          (StoredBookSource source) => source.source.name,
        ),
        containsAll(<String>['a', 'b']),
      );
    });

    test('update_givenAMissingRow_reportsIt', () async {
      expect(
        await repository.update(id: 404, entry: _entry()),
        BookSourceEditOutcome.sourceMissing,
      );
    });

    test('setGroupFor_givenARowWithABrokenPayload_skipsIt', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final int id = (await repository.getAll()).single.id;
      // 直接破坏负载：批量改分组必须跳过它而不是整批失败（端口是 total 的口径）。
      await (database.update(
        database.bookSources,
      )..where(($BookSourcesTable table) => table.id.equals(id))).write(
        const BookSourcesCompanion(payload: Value<String>('{not json')),
      );

      await repository.setGroupFor(<int>[id], '精选');

      expect(
        printer.events
            .map((LogEvent event) => event.message)
            .any((Object? message) => '$message'.contains('skipped')),
        isTrue,
      );
    });

    test('delete_givenAnExistingSource_removesIt', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final int id = (await repository.getAll()).single.id;

      await repository.delete(id);

      expect(await repository.getAll(), isEmpty);
    });

    test(
      'saveAll_givenExploreDisabled_initialisesTheFlagAndKeepsItOnReimport',
      () async {
        await repository.saveAll(<Map<String, Object?>>[
          _entry(exploreEnabled: false),
        ]);
        // 用户重新打开发现后再次导入同一身份：用户态不许被覆盖（ADR-0040 §决策 3）。
        final int id = (await repository.getAll()).single.id;
        await repository.setExploreEnabledFor(<int>[
          id,
        ], isExploreEnabled: true);

        await repository.saveAll(<Map<String, Object?>>[
          _entry(exploreEnabled: false),
        ]);

        expect((await repository.findById(id))!.isExploreEnabled, isTrue);
      },
    );

    test('applyCheckReport_givenAVerdict_recordsItInTheHistory', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final int id = (await repository.getAll()).single.id;

      await repository.applyCheckReport(
        id: id,
        report: const SourceCheckReport(
          status: SourceCheckStatus.failed,
          invalidGroups: <String>[searchInvalidGroup],
          errorComment: '搜索失效',
          elapsedMillis: 640,
        ),
      );

      final Map<int, SourceCheckRecord> latest = await repository
          .latestChecks();
      expect(latest[id]!.status, SourceCheckStatus.failed);
      expect(latest[id]!.invalidGroups, <String>[searchInvalidGroup]);
      expect(latest[id]!.elapsedMillis, 640);
      expect(latest[id]!.checkedAt, clock.now());
      // 列投影与历史同一次写入，两处说的是同一件事（ADR-0052 §决策 1）。
      expect(
        (await repository.findById(id))!.groupName,
        contains(searchInvalidGroup),
      );
    });

    test('renameGroup_whenCalled_rewritesThePayloadGroupOnly', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(url: 'https://a.test', group: '精选'),
        _entry(url: 'https://b.test', group: '精选, 备用'),
        _entry(url: 'https://c.test', group: '别的'),
      ]);

      await repository.renameGroup('精选', '收藏');

      final Map<String, String?> groups = <String, String?>{
        for (final StoredBookSource source in await repository.getAll())
          source.source.url: source.source.group,
      };
      expect(groups['https://a.test'], '收藏');
      expect(groups['https://b.test'], '收藏, 备用');
      expect(groups['https://c.test'], '别的');
    });

    test('deleteGroup_whenCalled_removesTheTokenFromEverySource', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(url: 'https://a.test', group: '精选, 备用'),
        _entry(url: 'https://b.test', group: '精选'),
      ]);

      await repository.deleteGroup('精选');

      final Map<String, String?> groups = <String, String?>{
        for (final StoredBookSource source in await repository.getAll())
          source.source.url: source.source.group,
      };
      expect(groups['https://a.test'], '备用');
      expect(groups['https://b.test'], isNull);
    });

    test('removeFromGroup_givenSomeIds_leavesTheOtherSourcesAlone', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(url: 'https://a.test', group: '精选'),
        _entry(url: 'https://b.test', group: '精选'),
      ]);
      final int first = (await repository.getAll()).first.id;

      await repository.removeFromGroup(<int>[first], '精选');

      final Map<String, String?> groups = <String, String?>{
        for (final StoredBookSource source in await repository.getAll())
          source.source.url: source.source.group,
      };
      expect(groups['https://a.test'], isNull);
      expect(groups['https://b.test'], '精选');
    });

    test('moveToEdge_whenToTop_ordersTheSelectionFirst', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(name: 'a', url: 'https://a.test'),
        _entry(name: 'b', url: 'https://b.test'),
        _entry(name: 'c', url: 'https://c.test'),
      ]);
      final List<StoredBookSource> rows = await repository.getAll();
      final int last = rows.last.id;

      await repository.moveToEdge(<int>[last], toTop: true);

      expect(
        (await repository.getAll()).map(
          (StoredBookSource source) => source.source.url,
        ),
        <String>['https://c.test', 'https://a.test', 'https://b.test'],
      );
    });

    test('setExploreEnabledFor_whenCalled_flipsEverySelectedSource', () async {
      await repository.saveAll(<Map<String, Object?>>[
        _entry(url: 'https://a.test'),
        _entry(url: 'https://b.test'),
      ]);
      final List<int> ids = <int>[
        for (final StoredBookSource source in await repository.getAll())
          source.id,
      ];

      await repository.setExploreEnabledFor(ids, isExploreEnabled: false);

      for (final StoredBookSource source in await repository.getAll()) {
        expect(source.isExploreEnabled, isFalse);
      }
    });
  });
}
