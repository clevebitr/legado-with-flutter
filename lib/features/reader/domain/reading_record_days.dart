import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';

/// One day's reading: the sessions that ended that day and how long they took.
///
/// It exists so the 「阅读记录」 page can render day headers without the widget doing the grouping
/// (C-STATE-4: the page renders, the domain decides), and so the arithmetic is unit-testable.
final class ReadingRecordDay {
  /// Creates one day of reading.
  const ReadingRecordDay({required this.day, required this.records});

  /// Local date of the day (midnight, no time component).
  final DateTime day;

  /// That day's sessions, newest first.
  final List<ReadingRecord> records;

  /// Total time spent reading that day.
  Duration get total => Duration(
    seconds: records.fold<int>(
      0,
      (int sum, ReadingRecord record) => sum + record.durationSeconds,
    ),
  );
}

/// Groups [records] by the **local** date of each session's end.
///
/// `endedAt` rather than `startedAt`: a session that starts at 23:55 and ends at 00:20 is twenty
/// minutes of *yesterday's* evening reading, and `read_records` already indexes the end
/// (ADR-0066 §决策 4). Days are returned newest first; sessions inside a day keep the input order,
/// which is the query's (newest first).
List<ReadingRecordDay> groupRecordsByDay(List<ReadingRecord> records) {
  final Map<DateTime, List<ReadingRecord>> byDay =
      <DateTime, List<ReadingRecord>>{};
  for (final ReadingRecord record in records) {
    final DateTime local = record.endedAt.toLocal();
    final DateTime day = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(day, () => <ReadingRecord>[]).add(record);
  }
  final List<DateTime> days = byDay.keys.toList()
    ..sort((DateTime a, DateTime b) => b.compareTo(a));

  return days
      .map(
        (DateTime day) => ReadingRecordDay(
          day: day,
          records: byDay[day] ?? <ReadingRecord>[],
        ),
      )
      .toList();
}
