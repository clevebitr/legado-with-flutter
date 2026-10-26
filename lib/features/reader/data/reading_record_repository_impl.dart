import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/read_record_dao.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_session.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_record_repository.dart';

/// Drift-backed [ReadingRecordRepository] (`docs/dev/roadmap.md` M19).
///
/// The one rule it owns is the threshold: a session shorter than [minimumRecordedSeconds] is
/// dropped **here** rather than at the call site, so the reader can hand over every session it
/// knows about and the decision stays in one testable place (ADR-0066 §决策 4).
final class ReadingRecordRepositoryImpl implements ReadingRecordRepository {
  /// Creates the repository.
  const ReadingRecordRepositoryImpl(this._dao);

  final ReadRecordDao _dao;

  @override
  Future<void> record(ReadingSession session) async {
    if (!session.shouldRecord) {
      return;
    }
    await _dao.insertNew(
      sourceUrl: session.sourceUrl,
      bookUrl: session.bookUrl,
      bookName: session.bookName,
      chapterUrl: session.chapterUrl,
      chapterName: session.chapterName,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      durationSeconds: session.durationSeconds,
    );
  }

  @override
  Future<List<ReadingRecord>> getRecent({
    int limit = readingRecordPageLimit,
  }) async => (await _dao.findRecent(limit: limit)).map(_toRecord).toList();

  @override
  Future<List<ReadingRecord>> getForBook({
    required String sourceUrl,
    required String bookUrl,
    int limit = readingRecordPageLimit,
  }) async => (await _dao.findForBook(
    sourceUrl: sourceUrl,
    bookUrl: bookUrl,
    limit: limit,
  )).map(_toRecord).toList();

  /// Maps one row to the reader's value object.
  ReadingRecord _toRecord(ReadRecordRow row) => ReadingRecord(
    id: row.id,
    sourceUrl: row.sourceUrl,
    bookUrl: row.bookUrl,
    bookName: row.bookName,
    chapterUrl: row.chapterUrl,
    chapterName: row.chapterName,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    durationSeconds: row.durationSeconds,
  );
}
