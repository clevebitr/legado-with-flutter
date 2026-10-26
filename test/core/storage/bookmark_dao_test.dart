import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/bookmark_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clock a test can move by hand (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

void main() {
  group('BookmarkDao', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late BookmarkDao dao;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime(2026, 10, 23));
      dao = BookmarkDao(database, clock: clock);
    });

    tearDown(() => database.close());

    /// Inserts one bookmark, defaulting everything but the position.
    Future<int> insert({
      String sourceUrl = 'https://source.test',
      String bookUrl = 'https://source.test/book/1',
      String bookName = '剑来',
      String chapterUrl = 'https://source.test/1.html',
      String? chapterName = '第1章 开端',
      int chapterIndex = 0,
      int charOffset = 0,
      String? excerpt = '第一句',
    }) => dao.insertNew(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      bookName: bookName,
      tocUrl: 'https://source.test/book/1/toc',
      chapterUrl: chapterUrl,
      chapterName: chapterName,
      chapterIndex: chapterIndex,
      charOffset: charOffset,
      excerpt: excerpt,
    );

    test('findAll_whenNothingWasAdded_returnsNothing', () async {
      expect(await dao.findAll(), isEmpty);
    });

    test('insertNew_whenCalled_keepsEverySnapshotColumn', () async {
      await insert();

      final BookmarkRow row = (await dao.findAll()).single;
      expect(row.sourceUrl, 'https://source.test');
      expect(row.bookUrl, 'https://source.test/book/1');
      expect(row.bookName, '剑来');
      expect(row.tocUrl, 'https://source.test/book/1/toc');
      expect(row.chapterName, '第1章 开端');
      expect(row.excerpt, '第一句');
      expect(row.createdAt, clock.now());
    });

    test('findAll_whenTwoMarksShareATimestamp_ordersTheNewestFirst', () async {
      await insert(charOffset: 10);
      await insert(charOffset: 20);

      final List<BookmarkRow> rows = await dao.findAll();
      expect(rows.map((BookmarkRow row) => row.charOffset), <int>[20, 10]);
    });

    test('findForBook_ordersByChapterThenOffset', () async {
      await insert(chapterIndex: 1, chapterUrl: 'https://source.test/2.html');
      await insert(charOffset: 50);
      await insert(charOffset: 5);

      final List<BookmarkRow> rows = await dao.findForBook(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
      );
      expect(rows.map((BookmarkRow row) => row.charOffset), <int>[5, 50, 0]);
    });

    test('findForBook_whenAnotherBookIsStored_ignoresIt', () async {
      await insert();
      await insert(bookUrl: 'https://source.test/book/2');

      final List<BookmarkRow> rows = await dao.findForBook(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/2',
      );
      expect(rows, hasLength(1));
      expect(rows.single.bookUrl, 'https://source.test/book/2');
    });

    test('findAt_whenThePositionIsStored_answersThatRow', () async {
      await insert(charOffset: 42);

      final BookmarkRow? row = await dao.findAt(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        chapterUrl: 'https://source.test/1.html',
        charOffset: 42,
      );
      expect(row?.charOffset, 42);
    });

    test('findAt_whenTheOffsetDiffers_answersNull', () async {
      await insert(charOffset: 42);

      expect(
        await dao.findAt(
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/1',
          chapterUrl: 'https://source.test/1.html',
          charOffset: 43,
        ),
        isNull,
      );
    });

    test('insertNew_whenThePositionIsTaken_rejectsTheDuplicate', () async {
      await insert(charOffset: 7);

      await expectLater(insert(charOffset: 7), throwsA(anything));
      expect(await dao.findAll(), hasLength(1));
    });

    test('deleteById_whenTheRowExists_removesIt', () async {
      final int id = await insert();

      expect(await dao.deleteById(id), 1);
      expect(await dao.findAll(), isEmpty);
    });

    test('deleteById_whenTheRowIsGone_reportsNothing', () async {
      expect(await dao.deleteById(999), 0);
    });
  });
}
