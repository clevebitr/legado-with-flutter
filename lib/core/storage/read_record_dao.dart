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

  /// Every record, newest first.
  ///
  /// The backup exports the whole history (`ADR-0073` §决策 1), so this one has no `limit`; the pages
  /// keep using [findRecent] / [findForBook].
  Future<List<ReadRecordRow>> findAll() =>
      (select(readRecords)..orderBy(<OrderClauseGenerator<$ReadRecordsTable>>[
            ($ReadRecordsTable table) => OrderingTerm.desc(table.startedAt),
            ($ReadRecordsTable table) => OrderingTerm.desc(table.id),
          ]))
          .get();

  /// The record of one session, identified by `(sourceUrl, bookUrl, startedAt)`, or `null`.
  ///
  /// That triple is the restore's natural key (`ADR-0073` §决策 3): re-importing the same backup must
  /// not add the session twice, and the history table has no other stable identity.
  Future<ReadRecordRow?> findSession({
    required String sourceUrl,
    required String bookUrl,
    required DateTime startedAt,
  }) =>
      (select(readRecords)..where(
            (ReadRecords table) =>
                table.sourceUrl.equals(sourceUrl) &
                table.bookUrl.equals(bookUrl) &
                table.startedAt.equals(startedAt),
          ))
          .getSingleOrNull();

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

  /// Deletes every record (`ADR-0074` §决策 3, overwrite restore).
  Future<int> deleteAll() => delete(readRecords).go();

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
