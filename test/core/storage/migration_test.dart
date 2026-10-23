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

    test('migration_whenSchemaIsCreated_matchesTheRecordedV6Schema', () async {
      // 走 onCreate（`m.createAll()`）建库，再与 `drift_schemas/` 里 dump 出的
      // v5 逐列比对：有人改了表却忘了重新 dump 时，这条会失败。
      final InitializedSchema schema = await verifier.schemaAt(5);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 6);
      await database.close();
    });

    test('migration_fromV1ToV6_createsEveryTable', () async {
      // 从 v1 建库再跑到最新版：v2 加 `book_sources`（ADR-0040），v3 加 `books` 与
      // `reading_progress`（ADR-0041 §决策 4），v4 给书源加 `comment` 列（ADR-0043），
      // v5 给书架加 `tocUrl` 列（ADR-0044），v6 加校验历史表与 `isExploreEnabled` 列
      // （ADR-0052 §决策 1/3）。
      final InitializedSchema schema = await verifier.schemaAt(1);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 6);
      await database.close();
    });

    test('migration_fromV2ToV6_keepsTheImportedSources', () async {
      // v3 只有新表、v4 只有一列可空值：从导入书源那一版升上来时，既有行必须原样保留，
      // 新列的初值就是 null。
      final InitializedSchema schema = await verifier.schemaAt(2);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 6);
      await database.close();
    });

    test('migration_fromV3ToV6_addsTheCommentAndTocColumns', () async {
      // 5.4 / 5.6 那一版的库升上来：书架与阅读进度表已存在，两列分别在这一步补上。
      final InitializedSchema schema = await verifier.schemaAt(3);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 6);
      await database.close();
    });

    test('migration_fromV4ToV6_addsTheTocUrlColumn', () async {
      // M10 那一版（v4）升上来：书源表多一列可空的目录地址（ADR-0044 §决策 3），
      // 再到 v6 时补校验历史表与探索开关列。
      final InitializedSchema schema = await verifier.schemaAt(4);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 6);
      await database.close();
    });

    test('migration_fromV5ToV6_addsTheCheckHistoryAndExploreFlag', () async {
      // M13 那一版（v5）升上来：书源与书架列不动，新增 `source_checks` 表与
      // `is_explore_enabled` 列，默认值让旧行保持「发现开着」（ADR-0052 §决策 1/3）。
      final InitializedSchema schema = await verifier.schemaAt(5);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 6);
      await database.close();
    });

    test(
      'migration_whenTheVersionIsBehindTheActualSchema_repairsTheDatabase',
      () async {
        // 回归点（ADR-0056）：库的实际结构已经是 v6，`user_version` 却还停在 5。
        // 真实成因是「用还没提交的表定义建过库」或迁移做到一半被杀 —— 用户机器上的
        // reader.db 就是这样，表现为打开库就抛 DriftRemoteException，前台看到的是
        // 「书源加载不出来」「导入失败」。
        //
        // 旧实现在这里重跑 v6 步骤，`create index` 撞上已存在的索引直接抛，于是每次启动
        // 都失败；现在每个步骤先问「对象在不在」，重跑是空操作。
        final InitializedSchema schema = await verifier.schemaAt(6);
        schema.rawDatabase.execute('PRAGMA user_version = 5');
        final ReaderDatabase database = ReaderDatabase(schema.newConnection());

        await verifier.migrateAndValidate(database, 6);
        final QueryRow version = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data.values.single, 6);
        await database.close();
      },
    );

    test('schemaVersion_whenRead_isSix', () {
      expect(ReaderDatabase(NativeDatabase.memory()).schemaVersion, 6);
    });
  });
}
