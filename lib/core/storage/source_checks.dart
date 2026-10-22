// coverage:ignore-file
import 'package:drift/drift.dart';

/// How many checks one source keeps (`docs/dev/roadmap.md` §3.10 V1, ADR-0052 §决策 1).
///
/// The history answers "what did the last runs find", not "what happened in June": twenty rows per
/// source is enough to spot a flapping source while keeping a thousand-source batch at 20k rows.
const int checkHistoryLimit = 20;

/// One run of the book-source check (`docs/dev/roadmap.md` §3.10 V1, ADR-0052 §决策 1).
///
/// 本文件是 **drift 代码生成器的输入**：列 getter 只在生成期被分析，运行时不可达，
/// 因此按 ADR-0019 第三类理由登记在 `tool/coverage_allowlist.txt`；表结构与索引的正确性由
/// `test/core/storage/migration_test.dart`（与 `drift_schemas/drift_schema_v6.json` 逐列比对）
/// 与 `test/core/storage/book_source_dao_test.dart` 保证。
///
/// 为什么单独一张表而不是继续往 `book_sources` 加列：状态灯要显示「上次校验时间」并区分
/// 「失败 / 超时或 JS 失效」，而列只能表达最后一次的结论，没有时间也没有阶段（ADR-0052 §决策 1）。
/// 列写回继续存在（ADR-0043 / ADR-0050 的契约），两者在同一事务里写，避免给出两个答案。
@DataClassName('SourceCheckRow')
@TableIndex(
  name: 'source_checks_source_checked',
  columns: {#sourceId, #checkedAt},
)
class SourceChecks extends Table {
  /// Synthetic primary key; the history is append-only.
  IntColumn get id => integer().autoIncrement()();

  /// The `book_sources.id` this run belongs to.
  ///
  /// Deliberately **no** foreign key: deleting a source and its history is one explicit
  /// transaction in `BookSourceDao` (`deleteById` / `deleteByIds` / `deleteAll`), which keeps the
  /// cascade visible in code instead of relying on `PRAGMA foreign_keys` being on.
  IntColumn get sourceId => integer()();

  /// When the run finished, from the injected `Clock` (never the database clock).
  DateTimeColumn get checkedAt => dateTime()();

  /// `succeeded` / `failed` / `cancelled` — the domain enum's name, so an unknown value in an old
  /// database is a name lookup miss rather than a wrong index (same reason as the view store).
  TextColumn get status => text()();

  /// The failure group tokens this run wrote, joined with `joinGroups`, or `null` when healthy.
  TextColumn get invalidGroups => text().nullable()();

  /// The note this run wrote into `bookSourceComment`, or `null` when healthy.
  TextColumn get errorComment => text().nullable()();

  /// How long the run took, which is also what `respondTime` stores.
  IntColumn get elapsedMillis => integer()();
}
