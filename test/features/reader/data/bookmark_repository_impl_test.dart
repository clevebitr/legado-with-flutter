import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/bookmark_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/reader/data/bookmark_repository_impl.dart';
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clock a test can move by hand (`docs/dev/testing.md` §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  final DateTime _now;

  @override
  DateTime now() => _now;
}

void main() {
  group('BookmarkRepositoryImpl', () {
    late ReaderDatabase database;
    late BookmarkRepositoryImpl repository;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      repository = BookmarkRepositoryImpl(
        BookmarkDao(database, clock: _FixedClock(DateTime(2026, 10, 23, 8))),
      );
    });

    tearDown(() => database.close());

    /// The draft every case starts from.
    BookmarkDraft draft({int charOffset = 0}) => BookmarkDraft(
      sourceUrl: 'https://source.test',
      bookUrl: 'https://source.test/book/1',
      bookName: '剑来',
      tocUrl: 'https://source.test/book/1/toc',
      chapterUrl: 'https://source.test/1.html',
      chapterName: '第1章 开端',
      chapterIndex: 0,
      charOffset: charOffset,
      excerpt: '正文摘录',
    );

    test('getAll_whenNothingWasAdded_returnsNothing', () async {
      expect(await repository.getAll(), isEmpty);
    });

    test('toggle_whenThePositionIsFree_addsTheMarkAndAnswersTrue', () async {
      expect(await repository.toggle(draft(charOffset: 40)), isTrue);

      final Bookmark stored = (await repository.getAll()).single;
      expect(stored.charOffset, 40);
      expect(stored.tocUrl, 'https://source.test/book/1/toc');
      expect(stored.excerpt, '正文摘录');
      expect(stored.createdAt, DateTime(2026, 10, 23, 8));
    });

    test('toggle_whenThePositionIsMarked_removesItAndAnswersFalse', () async {
      await repository.toggle(draft(charOffset: 40));

      expect(await repository.toggle(draft(charOffset: 40)), isFalse);
      expect(await repository.getAll(), isEmpty);
    });

    test('toggle_whenAnotherOffsetIsUsed_keepsBothMarks', () async {
      await repository.toggle(draft(charOffset: 40));
      await repository.toggle(draft(charOffset: 80));

      expect(await repository.getAll(), hasLength(2));
    });

    test('getForBook_answersOnlyThatBook', () async {
      await repository.toggle(draft());
      await repository.toggle(
        draft().copyWith(bookUrl: 'https://source.test/book/2'),
      );

      final List<Bookmark> stored = await repository.getForBook(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
      );
      expect(stored, hasLength(1));
      expect(stored.single.bookUrl, 'https://source.test/book/1');
    });

    test('remove_whenTheMarkExists_deletesIt', () async {
      await repository.toggle(draft());
      final int id = (await repository.getAll()).single.id;

      await repository.remove(id);

      expect(await repository.getAll(), isEmpty);
    });
  });
}
