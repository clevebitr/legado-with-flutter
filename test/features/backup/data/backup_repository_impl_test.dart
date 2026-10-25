// 只为了关掉「同时开两个内存库」的警告：drift 与 matcher 都导出 isNull，所以隐藏它。
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/bookmark_dao.dart';
import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/core/storage/read_record_dao.dart';
import 'package:flutter_reader/core/storage/rule_dao.dart';
import 'package:flutter_reader/core/storage/shelf_group_dao.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/backup/data/backup_repository_impl.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_restore_report.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/domain/entities/restore_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A frozen clock: the backup writes dates, and a moving clock would make round trips flaky.
final class _FixedClock implements Clock {
  _FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 10, 25, 12);
}

/// One database with every DAO the backup uses, plus the repository under test.
final class _Harness {
  _Harness._(this.database, this.preferences);

  final ReaderDatabase database;
  final PreferenceStore preferences;

  static Future<_Harness> create() async {
    final ReaderDatabase database = ReaderDatabase(NativeDatabase.memory());
    final SharedPreferences shared = await SharedPreferences.getInstance();

    return _Harness._(database, PreferenceStore(shared));
  }

  late final BookSourceDao sources = BookSourceDao(
    database,
    clock: _FixedClock(),
  );
  late final BookshelfDao books = BookshelfDao(database, clock: _FixedClock());
  late final ShelfGroupDao groups = ShelfGroupDao(
    database,
    clock: _FixedClock(),
  );
  late final BookmarkDao bookmarks = BookmarkDao(
    database,
    clock: _FixedClock(),
  );
  late final ReadRecordDao records = ReadRecordDao(database);
  late final RuleDao rules = RuleDao(database);

  late final BackupRepositoryImpl repository = BackupRepositoryImpl(
    database: database,
    sources: sources,
    books: books,
    groups: groups,
    bookmarks: bookmarks,
    records: records,
    rules: rules,
    preferences: preferences,
  );

  Future<void> close() => database.close();

  /// Writes one row into every backed-up table, so a round trip has something to carry.
  Future<void> seed() async {
    final int groupId = await groups.insertNew(name: '仙侠', sortOrder: 0);
    final int bookId = await books.insertNew(
      sourceUrl: 'https://a.example',
      bookUrl: 'https://a.example/book/1',
      tocUrl: 'https://a.example/book/1/toc',
      name: '剑来',
      author: '烽火戏诸侯',
      kind: '仙侠',
      coverUrl: null,
      intro: '简介',
      lastChapter: '第1279章',
    );
    await books.restoreUserState(
      id: bookId,
      status: 1,
      isPinned: true,
      groupId: groupId,
      customCoverPath: '/covers/jianlai.jpg',
    );
    await books.upsertProgress(
      sourceUrl: 'https://a.example',
      bookUrl: 'https://a.example/book/1',
      chapterUrl: 'https://a.example/book/1/chapter/3',
      chapterName: '第三章',
      charOffset: 42,
      updatedAt: DateTime.utc(2026, 10, 20, 8),
    );
    await bookmarks.insertNew(
      sourceUrl: 'https://a.example',
      bookUrl: 'https://a.example/book/1',
      bookName: '剑来',
      tocUrl: 'https://a.example/book/1/toc',
      chapterUrl: 'https://a.example/book/1/chapter/3',
      chapterName: '第三章',
      chapterIndex: 3,
      charOffset: 42,
      excerpt: '摘录',
      createdAt: DateTime.utc(2026, 10, 20, 9),
    );
    await records.insertNew(
      sourceUrl: 'https://a.example',
      bookUrl: 'https://a.example/book/1',
      bookName: '剑来',
      chapterUrl: 'https://a.example/book/1/chapter/3',
      chapterName: '第三章',
      startedAt: DateTime.utc(2026, 10, 20, 8),
      endedAt: DateTime.utc(2026, 10, 20, 9),
      durationSeconds: 3600,
    );
    await rules.insert(
      kind: 'replace',
      name: '去广告',
      payload: <String, Object?>{'pattern': '广告', 'replacement': ''},
      isEnabled: false,
      isBuiltIn: true,
      sortOrder: 3,
      now: DateTime.utc(2026, 10, 1),
    );
    await sources.insertNew(
      url: 'https://a.example',
      fingerprint: 'fp-a',
      payload: '{"bookSourceName":"A"}',
      name: '源A',
      groupName: '仙侠',
      sourceType: 1,
      isEnabled: true,
      customOrder: 2,
      weight: 3,
      lastUpdateTime: 100,
      respondTime: 200,
      isExploreEnabled: false,
      comment: '备注',
      loginInfo: '{"账号":"u"}',
      importedAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 2),
    );
  }
}

void main() {
  // 往返用例故意同时开两个内存库（源 / 目标），drift 的「多实例」警告在这里是预期的。
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.fontScale': 1.4,
      'reader.pageMode': 2,
    });
  });

  group('collect', () {
    late _Harness harness;

    setUp(() async {
      harness = await _Harness.create();
      await harness.seed();
    });

    tearDown(() => harness.close());

    test('collect_givenEveryTable_answersOneRowPerRow', () async {
      final BackupContents contents = await harness.repository.collect();

      for (final BackupTable table in BackupTable.values) {
        expect(contents.countOf(table), 1, reason: 'table $table');
      }
    });

    test('collect_givenABookInAGroup_writesTheGroupNameNotItsId', () async {
      final BackupContents contents = await harness.repository.collect();

      expect(contents.tables[BackupTable.books]!.single['groupName'], '仙侠');
      expect(
        contents.tables[BackupTable.books]!.single.containsKey('groupId'),
        isFalse,
      );
    });

    test('collect_givenStoredPreferences_carriesThemVerbatim', () async {
      final BackupContents contents = await harness.repository.collect();

      expect(contents.preferences['settings.fontScale'], 1.4);
      expect(contents.preferences['reader.pageMode'], 2);
    });

    test('collect_givenARule_keepsItsPayloadText', () async {
      final BackupContents contents = await harness.repository.collect();

      final Map<String, Object?> rule =
          contents.tables[BackupTable.rules]!.single;
      expect(rule['kind'], 'replace');
      expect(rule['payload'], contains('"pattern":"广告"'));
      expect(rule['isBuiltIn'], isTrue);
    });
  });

  group('restore', () {
    late _Harness source;
    late _Harness target;

    setUp(() async {
      source = await _Harness.create();
      await source.seed();
      target = await _Harness.create();
    });

    tearDown(() async {
      await source.close();
      await target.close();
    });

    test('restore_givenAnEmptyDatabase_roundTripsEveryTable', () async {
      // U12 的验收：导出 → 清库（这里是另一个空库）→ 恢复，内容一模一样。
      final BackupContents before = await source.repository.collect();

      final BackupRestoreReport report = await target.repository.restore(
        before,
      );
      final BackupContents after = await target.repository.collect();

      expect(after.tables, before.tables);
      expect(after.preferences, before.preferences);
      expect(
        report.outcomes[BackupTable.books]?.inserted,
        1,
        reason: 'the shelf row is new here',
      );
      expect(report.preferencesWritten, before.preferences.length);
    });

    test(
      'restore_givenTheSameBackupTwice_changesNothingTheSecondTime',
      () async {
        final BackupContents before = await source.repository.collect();
        await target.repository.restore(before);

        final BackupRestoreReport second = await target.repository.restore(
          before,
        );

        expect(second.outcomes[BackupTable.books]?.inserted, 0);
        expect(second.outcomes[BackupTable.bookmarks]?.skipped, 1);
        expect(second.outcomes[BackupTable.readRecords]?.skipped, 1);
        expect(second.outcomes[BackupTable.rules]?.skipped, 1);
        expect(second.outcomes[BackupTable.bookSources]?.updated, 1);
      },
    );

    test('restore_givenLocalEdits_keepsThemAndNeverDeletesRows', () async {
      final BackupContents before = await source.repository.collect();
      await target.repository.restore(before);

      // 本地在恢复之后又改了一条规则、加了一个书签、读得更远了。
      final Map<String, Object?> changedRule = <String, Object?>{
        ...before.tables[BackupTable.rules]!.single,
        'payload': '{"pattern":"本地改过"}',
      };
      await target.repository.restore(
        BackupContents(
          tables: <BackupTable, List<Map<String, Object?>>>{
            BackupTable.rules: <Map<String, Object?>>[changedRule],
          },
          preferences: const <String, Object?>{},
        ),
      );

      final BackupContents after = await target.repository.collect();
      expect(
        after.tables[BackupTable.rules]!.single['payload'],
        contains('"pattern":"广告"'),
      );
      expect(after.countOf(BackupTable.books), 1);
    });

    test(
      'restore_givenALocalProgressNewerThanTheBackup_keepsTheLocalOne',
      () async {
        final BackupContents before = await source.repository.collect();
        await target.repository.restore(before);
        await target.books.upsertProgress(
          sourceUrl: 'https://a.example',
          bookUrl: 'https://a.example/book/1',
          chapterUrl: 'https://a.example/book/1/chapter/9',
          chapterName: '第九章',
          charOffset: 5,
          updatedAt: DateTime.utc(2026, 10, 24),
        );

        final BackupRestoreReport report = await target.repository.restore(
          before,
        );

        expect(report.outcomes[BackupTable.readingProgress]?.skipped, 1);
        final BackupContents after = await target.repository.collect();
        expect(
          after.tables[BackupTable.readingProgress]!.single['chapterUrl'],
          'https://a.example/book/1/chapter/9',
        );
      },
    );

    test('restore_givenABadRow_skipsItAndKeepsTheRest', () async {
      final BackupContents before = await source.repository.collect();
      final Map<String, Object?> badBook = <String, Object?>{
        'sourceUrl': 'https://a.example',
        // bookUrl 缺失：这条读不出来，但同表的其它行照样要恢复。
        'name': '缺身份的書',
      };
      final Map<String, Object?> badRule = <String, Object?>{
        'kind': 'replace',
        'name': '坏规则',
        'payload': 'not json',
      };

      final BackupRestoreReport report = await target.repository.restore(
        BackupContents(
          tables: <BackupTable, List<Map<String, Object?>>>{
            BackupTable.books: <Map<String, Object?>>[badBook],
            BackupTable.rules: <Map<String, Object?>>[badRule],
            BackupTable.bookGroups: before.tables[BackupTable.bookGroups]!,
          },
          preferences: const <String, Object?>{},
        ),
      );

      expect(report.outcomes[BackupTable.books]?.skipped, 1);
      expect(report.outcomes[BackupTable.rules]?.skipped, 1);
      expect(report.outcomes[BackupTable.bookGroups]?.inserted, 1);
    });

    test('restore_givenABookWithoutAGroup_leavesItUngrouped', () async {
      final BackupRestoreReport report = await target.repository.restore(
        // 不用 const：const 构造会在编译期折叠，域层的构造行就没有执行点（ADR-0019）。
        // ignore: prefer_const_constructors
        BackupContents(
          tables: <BackupTable, List<Map<String, Object?>>>{
            BackupTable.books: <Map<String, Object?>>[
              <String, Object?>{
                'sourceUrl': 'https://a.example',
                'bookUrl': 'https://a.example/book/2',
                'name': '无组书',
                'groupName': '备份里没有的组',
              },
            ],
          },
          preferences: const <String, Object?>{},
        ),
      );

      final List<Map<String, Object?>> books =
          (await target.repository.collect()).tables[BackupTable.books]!;
      expect(report.outcomes[BackupTable.books]?.inserted, 1);
      expect(books.single['groupName'], isNull);
    });

    test('restore_givenOverwrite_clearsTheTablesFirst', () async {
      // 覆盖 = 「回到备份那天」：先清空七张表，再写备份里的内容（ADR-0074 §决策 3）。
      final BackupContents before = await source.repository.collect();
      await target.repository.restore(before);
      await target.books.insertNew(
        sourceUrl: 'https://a.example',
        bookUrl: 'https://a.example/book/extra',
        tocUrl: null,
        name: '本地多出来的书',
        author: null,
        kind: null,
        coverUrl: null,
        intro: null,
        lastChapter: null,
      );

      final BackupRestoreReport report = await target.repository.restore(
        before,
        mode: RestoreMode.overwrite,
      );

      final BackupContents after = await target.repository.collect();
      expect(report.outcomes[BackupTable.books]?.inserted, 1);
      expect(after.tables[BackupTable.books], hasLength(1));
      expect(
        after.tables[BackupTable.books]!.single['name'],
        before.tables[BackupTable.books]!.single['name'],
      );
      // 设置仍然只合并：覆盖不动 preferences。
      expect(after.preferences, before.preferences);
    });

    test('restore_givenPreferences_writesOnlyTheKeysItCarries', () async {
      await target.preferences.writeString('settings.themeMode', 'kept');

      final BackupRestoreReport report = await target.repository.restore(
        const BackupContents(
          tables: <BackupTable, List<Map<String, Object?>>>{},
          preferences: <String, Object?>{'reader.pageMode': 7},
        ),
      );

      expect(report.preferencesWritten, 1);
      expect(target.preferences.readInt('reader.pageMode'), 7);
      expect(target.preferences.readString('settings.themeMode'), 'kept');
    });
  });
}
