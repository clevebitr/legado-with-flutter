// coverage:ignore-file
import 'package:drift/drift.dart';

/// One reading session in one book.
///
/// One row per reader opening; switching chapters does not split it.
@DataClassName('ReadRecordRow')
@TableIndex(name: 'read_records_book', columns: {#bookUrl, #endedAt})
@TableIndex(name: 'read_records_ended', columns: {#endedAt})
class ReadRecords extends Table {
  /// Synthetic primary key; the history is append-only.
  IntColumn get id => integer().autoIncrement()();

  /// `bookSourceUrl` of the source the book came from.
  TextColumn get sourceUrl => text()();

  /// The book's detail page URL.
  TextColumn get bookUrl => text()();

  /// The book title as it was when the session ended.
  TextColumn get bookName => text()();

  /// The chapter the session ended on; `null` when the list never loaded.
  TextColumn get chapterUrl => text().nullable()();

  /// The chapter title the session ended on, when known.
  TextColumn get chapterName => text().nullable()();

  /// When the reader was opened.
  DateTimeColumn get startedAt => dateTime()();

  /// When the reader was closed; the day view groups by this instant's local date.
  DateTimeColumn get endedAt => dateTime()();

  /// Wall-clock length of the session, which is what the day view sums.
  IntColumn get durationSeconds => integer()();
}
