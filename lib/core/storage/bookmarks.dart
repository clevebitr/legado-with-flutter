// coverage:ignore-file
import 'package:drift/drift.dart';

/// One bookmark: a position in one chapter of one book.
///
/// `bookName` / `chapterName` are snapshots so the list renders offline.
@DataClassName('BookmarkRow')
@TableIndex(name: 'bookmarks_book', columns: {#bookUrl})
class Bookmarks extends Table {
  /// Synthetic primary key.
  IntColumn get id => integer().autoIncrement()();

  /// `bookSourceUrl` of the source the book came from.
  TextColumn get sourceUrl => text()();

  /// The book's detail page URL — the book's identity inside one source.
  TextColumn get bookUrl => text()();

  /// The book title as it was when the mark was made.
  TextColumn get bookName => text()();

  /// The table-of-contents URL the reader was opened with, when it had one.
  TextColumn get tocUrl => text().nullable()();

  /// The chapter the mark points into.
  TextColumn get chapterUrl => text()();

  /// The chapter title as it was when the mark was made, when the list knew it.
  TextColumn get chapterName => text().nullable()();

  /// Index of the chapter in the table of contents at the time of the write.
  ///
  /// Stale after renumbering; opening a mark falls back to it after [chapterUrl].
  IntColumn get chapterIndex => integer().withDefault(const Constant(0))();

  /// Character offset inside the chapter body.
  IntColumn get charOffset => integer().withDefault(const Constant(0))();

  /// Up to 80 characters of the body around the position, for the list.
  TextColumn get excerpt => text().nullable()();

  /// When the mark was made.
  DateTimeColumn get createdAt => dateTime()();

  /// A position is one bookmark: pressing the button again removes it.
  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{sourceUrl, bookUrl, chapterUrl, charOffset},
  ];
}
