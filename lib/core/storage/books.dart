// coverage:ignore-file
import 'package:drift/drift.dart';

/// The books the user put on the shelf (`docs/dev/roadmap.md` 5.4, ADR-0041).
///
/// 本文件是 **drift 代码生成器的输入**：列 getter 与 `uniqueKeys` 只在生成期被分析，
/// 运行时不可达（drift 源码 `lib/src/dsl/columns.dart` 明确写着这些方法
/// 「not meant to be called at runtime」）。因此它按 ADR-0019 登记在
/// `tool/coverage_allowlist.txt` 中豁免；表结构的正确性由
/// `test/core/storage/migration_test.dart`（与 `drift_schemas/` 逐列比对）与
/// `test/core/storage/bookshelf_dao_test.dart` 保证。
///
/// The identity is `(sourceUrl, bookUrl)`, **not** the book URL alone: two sources may carry
/// the same book under different rules, and a book found through two sources is two shelf
/// entries the user can tell apart by source. The source is referenced by its **URL** rather
/// than `book_sources.id`, because that id belongs to one imported row: deleting and
/// re-importing the same source changes the id but not what the book came from (ADR-0040 §决策 1).
@DataClassName('BookRow')
class Books extends Table {
  /// Synthetic primary key.
  IntColumn get id => integer().autoIncrement()();

  /// `bookSourceUrl` of the source this entry came from.
  TextColumn get sourceUrl => text()();

  /// The detail page URL — the book's identity inside one source.
  TextColumn get bookUrl => text()();

  /// The table-of-contents URL the detail page resolved (`ruleBookInfo.tocUrl`, 5.3).
  ///
  /// It is a **nullable** column rather than something the reader can derive: a source may keep its
  /// chapters on a page of their own, and the book page is then the wrong address. Opening the
  /// reader from the shelf falls back to [bookUrl] when the row predates this column (ADR-0044 §决策 3).
  TextColumn get tocUrl => text().nullable()();

  /// The title shown on the shelf.
  TextColumn get name => text()();

  /// The author as the search hit spelled it, when the rule matched.
  TextColumn get author => text().nullable()();

  /// The category as the source spelled it, when the rule matched.
  TextColumn get kind => text().nullable()();

  /// The cover URL, when the source declared one.
  TextColumn get coverUrl => text().nullable()();

  /// The introduction, when the source declared one.
  TextColumn get intro => text().nullable()();

  /// The latest chapter as shown at the time the book was added.
  TextColumn get lastChapter => text().nullable()();

  /// User state: 0 = tracking, 1 = finished (`ShelfStatus`); the UI owns it.
  IntColumn get status => integer().withDefault(const Constant(0))();

  /// User state: whether the entry is pinned to the top of the shelf.
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// When the book was put on the shelf.
  DateTimeColumn get addedAt => dateTime()();

  /// When this row was last written; the shelf's fallback order uses it.
  DateTimeColumn get updatedAt => dateTime()();

  /// One book per source: the same URL under the same source is the same entry.
  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{sourceUrl, bookUrl},
  ];
}

/// Where the reader stopped in one book (`docs/dev/roadmap.md` 5.4, ADR-0041 §决策 4).
///
/// Same generator-input reasoning as [Books]: the file is registered in
/// `tool/coverage_allowlist.txt` and its shape is pinned by the migration test.
///
/// The shelf owns this table; the reader (5.3) only writes it through its
/// `ReadingProgressWriter` port, so the two features stay independent (C-ARCH-2).
@DataClassName('ReadingProgressRow')
class ReadingProgress extends Table {
  /// `bookSourceUrl` of the source the book came from.
  TextColumn get sourceUrl => text()();

  /// The book's detail page URL.
  TextColumn get bookUrl => text()();

  /// The chapter the reader is on.
  TextColumn get chapterUrl => text()();

  /// The chapter's title, kept for the shelf's subtitle (the reader may not be open).
  TextColumn get chapterName => text().nullable()();

  /// Character offset inside the chapter body.
  IntColumn get charOffset => integer().withDefault(const Constant(0))();

  /// When the progress was written; the shelf orders «recently read» by it.
  DateTimeColumn get updatedAt => dateTime()();

  /// One progress row per (source, book) pair.
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{sourceUrl, bookUrl};
}
