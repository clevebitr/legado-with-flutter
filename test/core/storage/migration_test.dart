import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';

void main() {
  group('ReaderDatabase', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('migration_fromV6ToV7_addsGroupsBookmarksAndRecords', () async {
      // M18 那一版（v6）升上来：新增 `book_groups` / `bookmarks` / `read_records` 三张表（含
      // `bookmarks` 的唯一键与两张表的索引）、书架两列（`group_id` / `custom_cover_path`，
      // 默认 null = 未分组 / 用书源封面）与缓存表的 `scope_key`（ADR-0066 §决策 6）。升级后的
      // 结构必须与 `drift_schemas/drift_schema_v7.json` 逐列一致。
      final InitializedSchema schema = await verifier.schemaAt(6);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 8);
      await database.close();
    });

    test('migration_fromV7ToV8_addsTheCookieJar', () async {
      // M21a（ADR-0068 §决策 4）：只加 `cookies` 表与它的域索引；既有行不动。
      final InitializedSchema schema = await verifier.schemaAt(7);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 8);
      await database.close();
    });

    test('migration_fromV1ToV8_createsEveryTable', () async {
      // 从 v1 建库再跑到最新版：v2 加 `book_sources`（ADR-0040），v3 加 `books` 与
      // `reading_progress`（ADR-0041 §决策 4），v4 给书源加 `comment` 列（ADR-0043），
      // v5 给书架加 `tocUrl` 列（ADR-0044），v6 加校验历史表与 `isExploreEnabled` 列
      // （ADR-0052 §决策 1/3），v7 加分组 / 书签 / 阅读记录与按书缓存列（ADR-0066），v8 加 Cookie jar
      // （ADR-0068）。
      // 这条也是「新表已建好之后不要再 addColumn」的回归点：v1 的 `books` 走的是
      // `createTable` 的当前形状。
      final InitializedSchema schema = await verifier.schemaAt(1);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 8);
      await database.close();
    });

    test('migration_fromV2ToV8_keepsTheImportedSources', () async {
      // v3 只有新表、v4 只有一列可空值：从导入书源那一版升上来时，既有行必须原样保留，
      // 新列的初值就是 null。
      final InitializedSchema schema = await verifier.schemaAt(2);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 8);
      await database.close();
    });

    test('migration_fromV3ToV8_addsTheCommentAndTocColumns', () async {
      // 5.4 / 5.6 那一版的库升上来：书架与阅读进度表已存在，两列分别在这一步补上。
      final InitializedSchema schema = await verifier.schemaAt(3);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 8);
      await database.close();
    });

    test('migration_fromV4ToV8_addsTheTocUrlColumn', () async {
      // M10 那一版（v4）升上来：书源表多一列可空的目录地址（ADR-0044 §决策 3），
      // 再到 v6 时补校验历史表与探索开关列。
      final InitializedSchema schema = await verifier.schemaAt(4);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 8);
      await database.close();
    });

    test('migration_fromV5ToV8_addsTheCheckHistoryAndExploreFlag', () async {
      // M13 那一版（v5）升上来：书源与书架列不动，新增 `source_checks` 表与
      // `is_explore_enabled` 列，默认值让旧行保持「发现开着」（ADR-0052 §决策 1/3）。
      final InitializedSchema schema = await verifier.schemaAt(5);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 8);
      await database.close();
    });

    test(
      'migration_whenTheVersionIsBehindTheActualSchema_repairsTheDatabase',
      () async {
        // 回归点（ADR-0056）：库的实际结构已经是 v8，`user_version` 却还停在 7。
        // 真实成因是「用还没提交的表定义建过库」或迁移做到一半被杀 —— 用户机器上的
        // reader.db 就是这样，表现为打开库就抛 DriftRemoteException，前台看到的是
        // 「书源加载不出来」「导入失败」。
        //
        // 旧实现在这里重跑版本步骤，`create index` 撞上已存在的索引直接抛，于是每次启动
        // 都失败；现在每个步骤先问「对象在不在」，重跑是空操作。ADR-0066 的 v7 步骤同样走
        // `createTable` + `sqlite_master` 询问，所以从「结构已是 v7、版本还是 6」的库上也
        // 能重新打开。
        final InitializedSchema schema = await verifier.schemaAt(8);
        schema.rawDatabase.execute('PRAGMA user_version = 7');
        final ReaderDatabase database = ReaderDatabase(schema.newConnection());

        await verifier.migrateAndValidate(database, 8);
        final QueryRow version = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data.values.single, 8);
        await database.close();
      },
    );

    test('schemaVersion_whenRead_isEight', () {
      expect(ReaderDatabase(NativeDatabase.memory()).schemaVersion, 8);
    });
  });
}
