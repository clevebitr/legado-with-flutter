import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/book_sources.dart';
import 'package:flutter_reader/core/storage/cache_entries.dart';

part 'database.g.dart';

/// The application database: primary store for structured data (ADR-0003).
///
/// Schema changes must be recorded with the `drift_dev schema dump` /
/// `schema generate` workflow documented in `docs/dev/tech-stack.md` §8, otherwise
/// `test/core/storage/migration_test.dart` fails.
///
/// The DAO is deliberately **not** listed in `daos:`: the generated getter would
/// construct it with the database alone, while `CacheDao` needs an injected clock
/// (`docs/dev/testing.md` §4). The `@DriftAccessor` mixin is generated either way.
/// `BookSourceDao` has the same reason, plus its clock.
@DriftDatabase(tables: <Type>[CacheEntries, BookSources])
class ReaderDatabase extends _$ReaderDatabase {
  /// Creates the database on top of [e].
  ReaderDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      // v2 只新增导入的书源表（ADR-0040）；没有列改动，所以不需要数据搬迁。
      if (from < 2) {
        await m.createTable(bookSources);
      }
    },
  );
}
