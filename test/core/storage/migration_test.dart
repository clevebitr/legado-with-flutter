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

    test('migration_whenSchemaIsCreated_matchesTheRecordedV1Schema', () async {
      // 走 onCreate（`m.createAll()`）建库，再与 `drift_schemas/` 里 dump 出的
      // v1 逐列比对：有人改了表却忘了重新 dump 时，这条会失败。
      final InitializedSchema schema = await verifier.schemaAt(1);
      final ReaderDatabase database = ReaderDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 1);
      await database.close();
    });

    test('schemaVersion_whenRead_isOne', () {
      expect(ReaderDatabase(NativeDatabase.memory()).schemaVersion, 1);
    });
  });
}
