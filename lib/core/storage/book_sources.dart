// coverage:ignore-file
import 'package:drift/drift.dart';

/// The book sources the user imported (`docs/dev/roadmap.md` 5.1, ADR-0040).
///
/// 本文件是 **drift 代码生成器的输入**：列 getter 与 `uniqueKeys` 只在生成期被分析，
/// 运行时不可达（drift 源码 `lib/src/dsl/columns.dart` 明确写着这些方法
/// 「not meant to be called at runtime」）。因此它按 ADR-0019 登记在
/// `tool/coverage_allowlist.txt` 中豁免；表结构的正确性由
/// `test/core/storage/migration_test.dart`（与 `drift_schemas/` 逐列比对）与
/// `test/core/storage/book_source_dao_test.dart` 保证。
///
/// The identity is `(url, fingerprint)`, **not** the URL alone: the real corpus has both
/// byte-identical duplicates and same-URL sources with different rules, so a URL primary key
/// would silently drop one of them (ADR-0040 §决策 1-3).
@DataClassName('BookSourceRow')
class BookSources extends Table {
  /// Synthetic primary key; never the URL, so a row keeps its identity across re-imports.
  ///
  /// `AUTOINCREMENT` is deliberate rather than a plain `INTEGER PRIMARY KEY`: without it SQLite
  /// may hand a deleted row's id out again, and a stale "current source" reference would then
  /// silently point at **another** source (ADR-0040 §决策 1). Monotonic ids make reuse
  /// impossible, and with a few thousand rows the extra bookkeeping costs nothing.
  IntColumn get id => integer().autoIncrement()();

  /// `bookSourceUrl` — upstream's natural identifier (`book-source.md` §2).
  TextColumn get url => text()();

  /// sha256 of the behaviour fields' canonical JSON (`bookSourceFingerprint`).
  TextColumn get fingerprint => text()();

  /// The entry exactly as imported, re-encoded from the raw JSON map (ADR-0040 §决策 4).
  ///
  /// It is the export source of `docs/dev/roadmap.md` 5.8 and the only place unknown keys survive
  /// byte-for-byte; the projection columns below exist for listing and sorting only.
  TextColumn get payload => text()();

  /// `bookSourceName`, projected for the list.
  TextColumn get name => text()();

  /// `bookSourceGroup`, projected for the list.
  TextColumn get groupName => text().nullable()();

  /// `bookSourceComment`, the note the batch check writes back (`docs/dev/roadmap.md` §5.10).
  ///
  /// It is a **projection column like [groupName]**, not part of [payload]: the check rewrites it on
  /// every run (the previous `// Error: ` block is cleared first), and ADR-0040 §决策 4 keeps
  /// [payload] byte-for-byte so `docs/dev/roadmap.md` 5.8 can export what was imported (ADR-0043 §决策 1).
  TextColumn get comment => text().nullable()();

  /// `bookSourceType`, projected for the list.
  IntColumn get sourceType => integer().withDefault(const Constant(0))();

  /// User state: whether the source takes part in search / explore (`docs/dev/roadmap.md` 5.1).
  ///
  /// Import initialises it for a new row and **never** touches it afterwards
  /// (ADR-0040 §决策 3).
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  /// User state: the manual sort order (`docs/dev/roadmap.md` 5.5); import never touches it either.
  IntColumn get customOrder => integer().withDefault(const Constant(0))();

  /// `weight`, projected for sorting in `docs/dev/roadmap.md` 5.5.
  IntColumn get weight => integer().withDefault(const Constant(0))();

  /// `lastUpdateTime`, projected for display in `docs/dev/roadmap.md` 5.5.
  IntColumn get lastUpdateTime => integer().nullable()();

  /// `respondTime`, projected for display in `docs/dev/roadmap.md` 5.5.
  IntColumn get respondTime => integer().nullable()();

  /// When the row was created.
  DateTimeColumn get importedAt => dateTime()();

  /// When the stored payload was last refreshed.
  DateTimeColumn get updatedAt => dateTime()();

  /// The identity unique key: same URL and same behaviour is the same source.
  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{url, fingerprint},
  ];
}
