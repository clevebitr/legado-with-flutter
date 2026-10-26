import 'package:flutter_reader/features/reader/domain/entities/reading_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingSession', () {
    /// A session bounded by two fixed instants.
    ReadingSession session({required Duration length}) {
      final DateTime start = DateTime(2026, 10, 23, 20);

      return ReadingSession(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        bookName: '剑来',
        startedAt: start,
        endedAt: start.add(length),
      );
    }

    test('durationSeconds_whenTheSessionLastedAMinute_answersSixty', () {
      expect(session(length: const Duration(seconds: 60)).durationSeconds, 60);
    });

    test('durationSeconds_whenTheClockWentBackwards_answersZero', () {
      expect(session(length: const Duration(seconds: -30)).durationSeconds, 0);
    });

    test(
      'shouldRecord_whenTheSessionIsShorterThanTheThreshold_answersFalse',
      () {
        expect(
          session(length: const Duration(seconds: minimumRecordedSeconds - 1))
              .shouldRecord,
          isFalse,
        );
      },
    );

    test('shouldRecord_whenTheSessionIsExactlyTheThreshold_answersTrue', () {
      expect(
        session(length: const Duration(seconds: minimumRecordedSeconds))
            .shouldRecord,
        isTrue,
      );
    });

    test('shouldRecord_whenTheClockWentBackwards_answersFalse', () {
      expect(
        session(length: const Duration(seconds: -600)).shouldRecord,
        isFalse,
      );
    });
  });
}
