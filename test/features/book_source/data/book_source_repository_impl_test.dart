import 'package:drift/native.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/data/book_source_repository_impl.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Object? customOrder,
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
  if (customOrder != null) {
    entry['customOrder'] = customOrder;
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

    test('delete_givenAnExistingSource_removesIt', () async {
      await repository.saveAll(<Map<String, Object?>>[_entry()]);
      final int id = (await repository.getAll()).single.id;

      await repository.delete(id);

      expect(await repository.getAll(), isEmpty);
    });
  });
}
