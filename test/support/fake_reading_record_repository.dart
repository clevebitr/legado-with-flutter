import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_session.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_record_repository.dart';

/// In-memory [ReadingRecordRepository] for the tests (`docs/dev/testing.md` §4).
///
/// It stores **every** session it is handed, including the short ones the real implementation
/// drops: that is what lets a test tell "the page never handed the session over" apart from "the
/// store decided it was too short".
final class FakeReadingRecordRepository implements ReadingRecordRepository {
  /// The sessions handed to [record], in order.
  final List<ReadingSession> sessions = <ReadingSession>[];

  /// The records [getRecent] and [getForBook] answer with.
  List<ReadingRecord> records = <ReadingRecord>[];

  @override
  Future<void> record(ReadingSession session) async {
    sessions.add(session);
  }

  @override
  Future<List<ReadingRecord>> getRecent({
    int limit = readingRecordPageLimit,
  }) async => records.take(limit).toList();

  @override
  Future<List<ReadingRecord>> getForBook({
    required String sourceUrl,
    required String bookUrl,
    int limit = readingRecordPageLimit,
  }) async => records
      .where(
        (ReadingRecord record) =>
            record.sourceUrl == sourceUrl && record.bookUrl == bookUrl,
      )
      .take(limit)
      .toList();
}
