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

    test('migration_whenSchemaIsCreated_matchesTheRecordedV4Schema', () async {
      // 走 onCreate（`m.createAll()`）建库，再与 `drift_schemas/` 里 dump 出的
      // v4 逐列比对：有人改了表却忘了重新 dump 时，这条会失败。
      final InitializedSchema schema = await verifier.schemaAt(4);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 4);
      await database.close();
    });

    test('migration_fromV1ToV4_createsTheBookSourceAndShelfTables', () async {
      // 从 v1 建库再跑到最新版：v2 加 `book_sources`（ADR-0040），v3 加 `books` 与
      // `reading_progress`（ADR-0041 §决策 4），v4 给书源加 `comment` 列（ADR-0043）。
      final InitializedSchema schema = await verifier.schemaAt(1);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 4);
      await database.close();
    });

    test('migration_fromV2ToV4_keepsTheImportedSources', () async {
      // v3 只有新表、v4 只有一列可空值：从导入书源那一版升上来时，既有行必须原样保留，
      // 新列的初值就是 null。
      final InitializedSchema schema = await verifier.schemaAt(2);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 4);
      await database.close();
    });

    test('migration_fromV3ToV4_addsTheCommentColumn', () async {
      // 5.4 / 5.6 那一版的库升上来：书架与阅读进度不受影响，书源多一列。
      final InitializedSchema schema = await verifier.schemaAt(3);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 4);
      await database.close();
    });

    test('schemaVersion_whenRead_isFour', () {
      expect(ReaderDatabase(NativeDatabase.memory()).schemaVersion, 4);
    });
  });
}
