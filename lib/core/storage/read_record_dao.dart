import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/read_records.dart';

part 'read_record_dao.g.dart';

/// Row-level access to the reading records.
///
/// The table is append-only; both UI views are queries over it.
@DriftAccessor(tables: <Type>[ReadRecords])
class ReadRecordDao extends DatabaseAccessor<ReaderDatabase>
    with _$ReadRecordDaoMixin {
  /// Creates the DAO.
  ReadRecordDao(super.attachedDatabase);

  /// The most recent records across every book, newest first.
  ///
  /// [limit] is required because the page only shows the last few sessions.
  Future<List<ReadRecordRow>> findRecent({required int limit}) =>
      (select(readRecords)
            ..orderBy(<OrderClauseGenerator<$ReadRecordsTable>>[
              ($ReadRecordsTable table) => OrderingTerm.desc(table.endedAt),
              ($ReadRecordsTable table) => OrderingTerm.desc(table.id),
            ])
            ..limit(limit))
          .get();

  /// The most recent records of `(sourceUrl, bookUrl)`, newest first.
  Future<List<ReadRecordRow>> findForBook({
    required String sourceUrl,
    required String bookUrl,
    required int limit,
  }) =>
      (select(readRecords)
            ..where(
              (ReadRecords table) =>
                  table.sourceUrl.equals(sourceUrl) &
                  table.bookUrl.equals(bookUrl),
            )
            ..orderBy(<OrderClauseGenerator<$ReadRecordsTable>>[
              ($ReadRecordsTable table) => OrderingTerm.desc(table.endedAt),
              ($ReadRecordsTable table) => OrderingTerm.desc(table.id),
            ])
            ..limit(limit))
          .get();

  /// Appends one finished session and returns its generated id.
  Future<int> insertNew({
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    required String? chapterUrl,
    required String? chapterName,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
  }) => into(readRecords).insert(
    ReadRecordsCompanion.insert(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      bookName: bookName,
      chapterUrl: Value<String?>(chapterUrl),
      chapterName: Value<String?>(chapterName),
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
    ),
  );
}
