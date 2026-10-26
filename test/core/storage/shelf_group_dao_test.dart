import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/books.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/shelf_group_dao.dart';
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
  group('ShelfGroupDao', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late ShelfGroupDao dao;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime(2026, 10, 23));
      dao = ShelfGroupDao(database, clock: clock);
    });

    tearDown(() => database.close());

    /// Inserts one shelf row, defaulting everything but the identity.
    Future<int> insertBook({String bookUrl = 'https://source.test/book/1'}) =>
        database
            .into(database.books)
            .insert(
              BooksCompanion.insert(
                sourceUrl: 'https://source.test',
                bookUrl: bookUrl,
                name: '剑来',
                addedAt: clock.now(),
                updatedAt: clock.now(),
              ),
            );

    /// The stored group id of one shelf row.
    Future<int?> groupOf(String bookUrl) async =>
        (await (database.select(database.books)
                  ..where((Books table) => table.bookUrl.equals(bookUrl)))
                .getSingle())
            .groupId;

    test('findAll_whenNothingWasCreated_returnsNothing', () async {
      expect(await dao.findAll(), isEmpty);
    });

    test('findAll_ordersBySortOrderThenId', () async {
      await dao.insertNew(name: '仙侠', sortOrder: 2);
      await dao.insertNew(name: '历史', sortOrder: 0);
      await dao.insertNew(name: '玄幻', sortOrder: 1);

      expect(
        (await dao.findAll()).map((BookGroupRow row) => row.name),
        <String>['历史', '玄幻', '仙侠'],
      );
    });

    test('findByName_whenTheGroupExists_answersIt', () async {
      await dao.insertNew(name: '仙侠', sortOrder: 0);

      expect((await dao.findByName('仙侠'))?.name, '仙侠');
      expect(await dao.findByName('历史'), isNull);
    });

    test('rename_whenCalled_changesTheDisplayedName', () async {
      final int id = await dao.insertNew(name: '仙侠', sortOrder: 0);

      await dao.rename(id: id, name: '修真');

      expect((await dao.findAll()).single.name, '修真');
    });

    test('reorder_whenCalled_normalizesTheOrder', () async {
      final int first = await dao.insertNew(name: '仙侠', sortOrder: 0);
      final int second = await dao.insertNew(name: '历史', sortOrder: 1);

      await dao.reorder(<int>[second, first]);

      expect(
        (await dao.findAll()).map((BookGroupRow row) => row.name),
        <String>['历史', '仙侠'],
      );
    });

    test('deleteById_whenTheGroupHasBooks_movesThemToUngrouped', () async {
      final int id = await dao.insertNew(name: '仙侠', sortOrder: 0);
      final int book = await insertBook();
      await dao.setGroupFor(<int>[book], id);

      await dao.deleteById(id);

      expect(await dao.findAll(), isEmpty);
      expect(await groupOf('https://source.test/book/1'), isNull);
    });

    test('setGroupFor_whenCalled_movesEveryChosenRow', () async {
      final int group = await dao.insertNew(name: '仙侠', sortOrder: 0);
      final int first = await insertBook();
      final int second = await insertBook(
        bookUrl: 'https://source.test/book/2',
      );

      expect(await dao.setGroupFor(<int>[first, second], group), 2);
      expect(await groupOf('https://source.test/book/1'), group);
      expect(await groupOf('https://source.test/book/2'), group);
    });

    test('setGroupFor_whenNoIdIsChosen_writesNothing', () async {
      expect(await dao.setGroupFor(const <int>[], null), 0);
    });

    test('setPinnedFor_whenCalled_pinsTheChosenRows', () async {
      final int first = await insertBook();

      expect(await dao.setPinnedFor(<int>[first], true), 1);
      final BookRow row = await database.select(database.books).getSingle();
      expect(row.isPinned, isTrue);
    });

    test('setPinnedFor_whenNoIdIsChosen_writesNothing', () async {
      expect(await dao.setPinnedFor(const <int>[], true), 0);
    });

    test('setStatusFor_whenCalled_writesTheStatusValue', () async {
      final int first = await insertBook();

      expect(await dao.setStatusFor(<int>[first], 1), 1);
      final BookRow row = await database.select(database.books).getSingle();
      expect(row.status, 1);
    });

    test('setStatusFor_whenNoIdIsChosen_writesNothing', () async {
      expect(await dao.setStatusFor(const <int>[], 1), 0);
    });
  });
}
