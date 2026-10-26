// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_record.freezed.dart';

/// One finished reading session of one book (`docs/dev/roadmap.md` M19).
///
/// Granularity is one row per time the reader was opened (ADR-0066 §决策 4); switching chapters
/// inside a session does not split the row. Both the "by day" and "by book" views are projections
/// over this type.
@freezed
abstract class ReadingRecord with _$ReadingRecord {
  /// Creates a reading record.
  const factory ReadingRecord({
    required int id,
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    String? chapterUrl,
    String? chapterName,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
  }) = _ReadingRecord;
}
