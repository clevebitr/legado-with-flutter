// coverage:ignore-file
import 'package:drift/drift.dart';

/// The books the user put on the shelf.
///
/// Identity is `(sourceUrl, bookUrl)`, referenced by URL so re-import stays valid.
@DataClassName('BookRow')
class Books extends Table {
  /// Synthetic primary key.
  IntColumn get id => integer().autoIncrement()();

  /// `bookSourceUrl` of the source this entry came from.
  TextColumn get sourceUrl => text()();

  /// The detail page URL — the book's identity inside one source.
  TextColumn get bookUrl => text()();

  /// The table-of-contents URL resolved from the detail page.
  ///
  /// A source may keep chapters elsewhere; opening the reader falls back to [bookUrl].
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

  /// User state: 0 = tracking, 1 = finished; the UI owns it.
  IntColumn get status => integer().withDefault(const Constant(0))();

  /// User state: whether the entry is pinned to the top of the shelf.
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// The shelf group, or `null` for 「未分组」.
  ///
  /// No foreign key: the delete path clears this column explicitly in a transaction.
  IntColumn get groupId => integer().nullable()();

  /// Absolute path of a cover the user picked; `null` falls back to [coverUrl].
  TextColumn get customCoverPath => text().nullable()();

  /// The introduction the user wrote, which wins over [intro] when set (M33, ADR-0092).
  ///
  /// [intro] stays the source's snapshot: re-adding the book refreshes it, and a user's own words
  /// must survive that.
  TextColumn get customIntro => text().nullable()();

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

/// Where the reader stopped in one book.
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
