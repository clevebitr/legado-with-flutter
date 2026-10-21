import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/book_sources.dart';
import 'package:flutter_reader/core/storage/books.dart';
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
@DriftDatabase(
  tables: <Type>[CacheEntries, BookSources, Books, ReadingProgress],
)
class ReaderDatabase extends _$ReaderDatabase {
  /// Creates the database on top of [e].
  ReaderDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      // v2 只新增导入的书源表（ADR-0040）；没有列改动，所以不需要数据搬迁。
      // 注意 `createTable` 用的是**当前**表定义：从 v1 上来的库已经拿到 `comment` 列，
      // 所以 v4 的 `addColumn` 只能在「书源表已存在」的升级路径上执行，否则会撞
      // `duplicate column name`（migration_test 的 v1 → 最新用例就是这条的回归点）。
      if (from < 2) {
        await m.createTable(bookSources);
      } else if (from < 4) {
        await m.addColumn(bookSources, bookSources.comment);
      }
      // v3 新增书架与阅读进度两张表（ADR-0041 §决策 4，`docs/dev/roadmap.md` 5.4）：
      // 同样只有新表，没有列改动。
      if (from < 3) {
        await m.createTable(books);
        await m.createTable(readingProgress);
      } else if (from < 5) {
        // v5 给书架加目录地址（ADR-0044 §决策 3）。同一条注意事项：从 v1/v2 上来的库走的是
        // 上面的 `createTable(books)`，那已经是**当前**形状（含 `tocUrl`），所以这里的
        // `addColumn` 只对「书架表已存在」的升级路径执行。
        await m.addColumn(books, books.tocUrl);
      }
    },
  );
}
