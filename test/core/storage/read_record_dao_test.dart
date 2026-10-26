import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/read_record_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadRecordDao', () {
    late ReaderDatabase database;
    late ReadRecordDao dao;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      dao = ReadRecordDao(database);
    });

    tearDown(() => database.close());

    /// Inserts one session ending at [endedAt].
    Future<int> insert({
      String sourceUrl = 'https://source.test',
      String bookUrl = 'https://source.test/book/1',
      String bookName = '剑来',
      DateTime? endedAt,
      int durationSeconds = 600,
    }) {
      final DateTime end = endedAt ?? DateTime(2026, 10, 23, 12);
      final DateTime start = end.subtract(Duration(seconds: durationSeconds));

      return dao.insertNew(
        sourceUrl: sourceUrl,
        bookUrl: bookUrl,
        bookName: bookName,
        chapterUrl: 'https://source.test/1.html',
        chapterName: '第1章 开端',
        startedAt: start,
        endedAt: end,
        durationSeconds: durationSeconds,
      );
    }

    test('findRecent_whenNothingWasRecorded_returnsNothing', () async {
      expect(await dao.findRecent(limit: 10), isEmpty);
    });

    test('findRecent_ordersByEndNewestFirst', () async {
      await insert(endedAt: DateTime(2026, 10, 21, 9));
      await insert(endedAt: DateTime(2026, 10, 23, 9));
      await insert(endedAt: DateTime(2026, 10, 22, 9));

      final List<ReadRecordRow> rows = await dao.findRecent(limit: 10);
      expect(rows.map((ReadRecordRow row) => row.endedAt.day), <int>[
        23,
        22,
        21,
      ]);
    });

    test('findRecent_whenTheLimitIsSmaller_answersTheNewestOnly', () async {
      await insert(endedAt: DateTime(2026, 10, 21, 9));
      await insert(endedAt: DateTime(2026, 10, 23, 9));

      final List<ReadRecordRow> rows = await dao.findRecent(limit: 1);
      expect(rows.single.endedAt.day, 23);
    });

    test('findForBook_answersOnlyThatBook', () async {
      await insert();
      await insert(bookUrl: 'https://source.test/book/2');

      final List<ReadRecordRow> rows = await dao.findForBook(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/2',
        limit: 10,
      );
      expect(rows, hasLength(1));
      expect(rows.single.bookUrl, 'https://source.test/book/2');
    });

    test('insertNew_whenCalled_keepsTheDurationAndTitles', () async {
      await insert(durationSeconds: 125);

      final ReadRecordRow row = (await dao.findRecent(limit: 1)).single;
      expect(row.durationSeconds, 125);
      expect(row.bookName, '剑来');
      expect(row.chapterName, '第1章 开端');
      expect(row.startedAt.isBefore(row.endedAt), isTrue);
    });
  });
}
