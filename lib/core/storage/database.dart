import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/book_groups.dart';
import 'package:flutter_reader/core/storage/book_sources.dart';
import 'package:flutter_reader/core/storage/bookmarks.dart';
import 'package:flutter_reader/core/storage/books.dart';
import 'package:flutter_reader/core/storage/cache_entries.dart';
import 'package:flutter_reader/core/storage/cookies.dart';
import 'package:flutter_reader/core/storage/read_records.dart';
import 'package:flutter_reader/core/storage/rules.dart';
import 'package:flutter_reader/core/storage/source_checks.dart';
import 'package:flutter_reader/core/storage/source_variables.dart';

part 'database.g.dart';

/// The application database and its schema migrations.
@DriftDatabase(
  tables: <Type>[
    CacheEntries,
    BookSources,
    Books,
    ReadingProgress,
    SourceChecks,
    BookGroups,
    Bookmarks,
    ReadRecords,
    Cookies,
    Rules,
    SourceVariables,
  ],
)
class ReaderDatabase extends _$ReaderDatabase {
  /// Creates the database on top of [e].
  ReaderDatabase(super.e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      // v2 只新增书源表，没有列改动。`createTable` 使用的是当前表定义，从更早版本
      // 升级上来的库已包含后续新增列，因此加列只在列确实缺失时执行。
      if (from < 2) {
        await m.createTable(bookSources);
      } else if (from < 4) {
        await _addColumnIfMissing(m, bookSources, bookSources.comment);
      }
      // v3 新增书架与阅读进度两张表，同样只有新表。
      if (from < 3) {
        await m.createTable(books);
        await m.createTable(readingProgress);
      } else if (from < 5) {
        // v5 给书架加目录地址；书架表已存在时才补列。
        await _addColumnIfMissing(m, books, books.tocUrl);
      }
      // v6 新增校验历史表与探索开关列。
      if (from < 6) {
        // `createTable` 不建索引，且 drift 生成的 `CREATE INDEX` 不可重入，故先查后建。
        await m.createTable(sourceChecks);
        if (!await _hasSchemaObject(sourceChecksSourceChecked.entityName)) {
          await m.create(sourceChecksSourceChecked);
        }
        if (from >= 2) {
          await _addColumnIfMissing(
            m,
            bookSources,
            bookSources.isExploreEnabled,
          );
        }
      }
      // v7 新增分组表、书签表、阅读记录表，以及书架与缓存表的新列。
      if (from < 7) {
        await m.createTable(bookGroups);
        await m.createTable(bookmarks);
        if (!await _hasSchemaObject(bookmarksBook.entityName)) {
          await m.create(bookmarksBook);
        }
        await m.createTable(readRecords);
        if (!await _hasSchemaObject(readRecordsBook.entityName)) {
          await m.create(readRecordsBook);
        }
        if (!await _hasSchemaObject(readRecordsEnded.entityName)) {
          await m.create(readRecordsEnded);
        }
        // 书架表从 v3 起存在，更早的库已由 `createTable(books)` 建好当前形状。
        if (from >= 3) {
          await _addColumnIfMissing(m, books, books.groupId);
          await _addColumnIfMissing(m, books, books.customCoverPath);
        }
        // `cache_entries` 从 v1 起就存在，旧库没有这一列，故无条件补。
        await _addColumnIfMissing(m, cacheEntries, cacheEntries.scopeKey);
      }
      // v8 新增 Cookie 表与域名索引。
      if (from < 8) {
        await m.createTable(cookies);
        if (!await _hasSchemaObject(cookiesDomain.entityName)) {
          await m.create(cookiesDomain);
        }
      }
      // v9 新增规则表与「kind + 顺序」索引（ADR-0070 §决策 4）。内置规则不在迁移里插入：
      // 迁移只做结构变更，默认数据由仓储在首次使用时写入。
      if (from < 9) {
        await m.createTable(rules);
        if (!await _hasSchemaObject(rulesKindOrder.entityName)) {
          await m.create(rulesKindOrder);
        }
      }
      // v11 给书源加「登录信息」列（ADR-0072 §决策 3）：`loginUi` 表单填出来的值，按源存一份。
      if (from < 11) {
        await _addColumnIfMissing(m, bookSources, bookSources.loginInfo);
      }
      // v10 给缓存加「来源」列与索引，并清掉旧缓存（ADR-0072 §决策 1）：旧行没有来源摘要，
      // 留着会让按源统计在 TTL 内少算——缓存是可再生数据，清空比显示错数诚实。
      if (from < 10) {
        await _addColumnIfMissing(m, cacheEntries, cacheEntries.sourceKey);
        if (!await _hasSchemaObject(cacheEntriesSource.entityName)) {
          await m.create(cacheEntriesSource);
        }
        await delete(cacheEntries).go();
      }
      // v12 新增每源变量表（ADR-0076 §决策 1）：只建表与索引，既有行不动。
      if (from < 12) {
        await m.createTable(sourceVariables);
        if (!await _hasSchemaObject(sourceVariablesSource.entityName)) {
          await m.create(sourceVariablesSource);
        }
      }
      // v13 给书源加「登录头」列（M25/S3b）：`source.putLoginHeader` 写下的请求头，按源存一份。
      // 迁移测试会以「目标版本」为参数跑到中间版本，所以这里必须两头都判：只判 `from` 会把
      // 新列加进 v12 及更早的库，与对应 schema 比对时多出一列。
      if (from < 13 && to >= 13) {
        await _addColumnIfMissing(m, bookSources, bookSources.loginHeader);
      }
    },
  );

  // `sqlite_master` 里是否已有名为 [name] 的对象。
  Future<bool> _hasSchemaObject(String name) async {
    final QueryRow? row = await customSelect(
      'SELECT name FROM sqlite_master WHERE name = ? LIMIT 1',
      variables: <Variable<Object>>[Variable<String>(name)],
    ).getSingleOrNull();

    return row != null;
  }

  // 升级可能被中断而 `user_version` 落后于实际结构，直接加列会抛 `duplicate column name`，
  // 且每次打开库都会重复失败，因此升级步骤一律先查后写，保证可重入。
  Future<void> _addColumnIfMissing(
    Migrator migrator,
    TableInfo<Table, Object?> table,
    GeneratedColumn<Object> column,
  ) async {
    final List<QueryRow> info = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    final bool exists = info.any(
      (QueryRow row) => row.data['name'] == column.$name,
    );
    if (!exists) {
      await migrator.addColumn(table, column);
    }
  }
}
