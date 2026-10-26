import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/read_record_dao.dart';
import 'package:flutter_reader/features/reader/data/reading_record_repository_impl.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingRecordRepositoryImpl', () {
    late ReaderDatabase database;
    late ReadingRecordRepositoryImpl repository;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      repository = ReadingRecordRepositoryImpl(ReadRecordDao(database));
    });

    tearDown(() => database.close());

    /// A session of [seconds] starting at [startedAt].
    ReadingSession session({
      int seconds = 600,
      DateTime? startedAt,
      String bookUrl = 'https://source.test/book/1',
    }) {
      final DateTime start = startedAt ?? DateTime(2026, 10, 23, 20);

      return ReadingSession(
        sourceUrl: 'https://source.test',
        bookUrl: bookUrl,
        bookName: '剑来',
        chapterUrl: 'https://source.test/1.html',
        chapterName: '第1章 开端',
        startedAt: start,
        endedAt: start.add(Duration(seconds: seconds)),
      );
    }

    test('record_whenTheSessionIsLongEnough_storesIt', () async {
      await repository.record(session(seconds: 90));

      final ReadingRecord stored = (await repository.getRecent()).single;
      expect(stored.durationSeconds, 90);
      expect(stored.bookName, '剑来');
      expect(stored.chapterName, '第1章 开端');
    });

    test('record_whenTheSessionIsTooShort_dropsIt', () async {
      await repository.record(session(seconds: minimumRecordedSeconds - 1));

      expect(await repository.getRecent(), isEmpty);
    });

    test('record_whenTheSessionIsExactlyTheThreshold_storesIt', () async {
      await repository.record(session(seconds: minimumRecordedSeconds));

      expect(await repository.getRecent(), hasLength(1));
    });

    test('getRecent_answersSessionsNewestFirst', () async {
      await repository.record(session(startedAt: DateTime(2026, 10, 21, 8)));
      await repository.record(session(startedAt: DateTime(2026, 10, 23, 8)));

      expect(
        (await repository.getRecent()).map(
          (ReadingRecord record) => record.endedAt.day,
        ),
        <int>[23, 21],
      );
    });

    test('getRecent_whenTheLimitIsSmaller_answersTheNewestOnly', () async {
      await repository.record(session(startedAt: DateTime(2026, 10, 21, 8)));
      await repository.record(session(startedAt: DateTime(2026, 10, 23, 8)));

      expect(await repository.getRecent(limit: 1), hasLength(1));
    });

    test('getForBook_answersOnlyThatBook', () async {
      await repository.record(session());
      await repository.record(session(bookUrl: 'https://source.test/book/2'));

      final List<ReadingRecord> stored = await repository.getForBook(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/2',
      );
      expect(stored, hasLength(1));
      expect(stored.single.bookUrl, 'https://source.test/book/2');
    });

    test('getForBook_whenTheLimitIsSmaller_answersTheNewestOnly', () async {
      await repository.record(session(startedAt: DateTime(2026, 10, 21, 8)));
      await repository.record(session(startedAt: DateTime(2026, 10, 23, 8)));

      final List<ReadingRecord> stored = await repository.getForBook(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        limit: 1,
      );
      expect(stored.single.endedAt.day, 23);
    });
  });
}
