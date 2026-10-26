import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:flutter_reader/features/reader/domain/reading_record_days.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupRecordsByDay', () {
    ReadingRecord record({
      required int id,
      required DateTime endedAt,
      int durationSeconds = 600,
      String bookName = '剑来',
    }) => ReadingRecord(
      id: id,
      sourceUrl: 'https://source.test',
      bookUrl: 'https://source.test/book/1',
      bookName: bookName,
      startedAt: endedAt.subtract(Duration(seconds: durationSeconds)),
      endedAt: endedAt,
      durationSeconds: durationSeconds,
    );

    test('groupRecordsByDay_whenNothingIsStored_answersNothing', () {
      expect(groupRecordsByDay(const <ReadingRecord>[]), isEmpty);
    });

    test('groupRecordsByDay_whenTwoSessionsShareADay_answersOneDay', () {
      final List<ReadingRecordDay> days = groupRecordsByDay(<ReadingRecord>[
        record(id: 1, endedAt: DateTime(2026, 10, 23, 8)),
        record(id: 2, endedAt: DateTime(2026, 10, 23, 21)),
      ]);

      expect(days, hasLength(1));
      expect(days.single.records, hasLength(2));
      expect(days.single.day, DateTime(2026, 10, 23));
    });

    test('groupRecordsByDay_answersTheNewestDayFirst', () {
      final List<ReadingRecordDay> days = groupRecordsByDay(<ReadingRecord>[
        record(id: 1, endedAt: DateTime(2026, 10, 21, 8)),
        record(id: 2, endedAt: DateTime(2026, 10, 23, 8)),
      ]);

      expect(days.map((ReadingRecordDay day) => day.day.day), <int>[23, 21]);
    });

    test(
      'groupRecordsByDay_whenASessionEndsAfterMidnight_groupsItOnTheEndDay',
      () {
        // 23:55 开始、00:20 结束：这一行属于「今天」（结束日），与表上的索引列一致。
        final List<ReadingRecordDay> days = groupRecordsByDay(<ReadingRecord>[
          record(id: 1, endedAt: DateTime(2026, 10, 24, 0, 20)),
        ]);

        expect(days.single.day, DateTime(2026, 10, 24));
      },
    );

    test(
      'ReadingRecordDay total_whenTwoSessionsAreGrouped_sumsTheirDurations',
      () {
        final List<ReadingRecordDay> days = groupRecordsByDay(<ReadingRecord>[
          record(
            id: 1,
            endedAt: DateTime(2026, 10, 23, 8),
            durationSeconds: 600,
          ),
          record(
            id: 2,
            endedAt: DateTime(2026, 10, 23, 21),
            durationSeconds: 300,
          ),
        ]);

        expect(days.single.total, const Duration(minutes: 15));
      },
    );
  });
}
