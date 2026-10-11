import 'package:drift/drift.dart';
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
@DriftDatabase(tables: <Type>[CacheEntries])
class ReaderDatabase extends _$ReaderDatabase {
  /// Creates the database on top of [e].
  ReaderDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (Migrator m) async => m.createAll());
}
