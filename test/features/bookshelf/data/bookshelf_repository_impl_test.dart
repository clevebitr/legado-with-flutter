import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/bookshelf/data/bookshelf_repository_impl.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
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
  group('BookshelfRepositoryImpl', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late BookshelfRepositoryImpl repository;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime(2026, 10, 21));
      repository = BookshelfRepositoryImpl(
        dao: BookshelfDao(database, clock: clock),
      );
    });

    tearDown(() => database.close());

    /// A candidate for one book.
    ShelfCandidate candidate({
      String sourceUrl = 'https://source.test',
      String bookUrl = 'https://source.test/book/1',
      String name = '剑来',
      String? author = '烽火戏诸侯',
    }) => ShelfCandidate(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      name: name,
      author: author,
      kind: '玄幻',
      coverUrl: 'https://source.test/cover.jpg',
      intro: '简介',
      lastChapter: '第1279章',
    );

    test('getAll_whenEmpty_answersNothing', () async {
      expect(await repository.getAll(), isEmpty);
    });

    test('add_whenNew_storesTheWholeSnapshot', () async {
      await repository.add(candidate());

      final ShelvedBook book = (await repository.getAll()).single;

      expect(book.name, '剑来');
      expect(book.author, '烽火戏诸侯');
      expect(book.kind, '玄幻');
      expect(book.coverUrl, 'https://source.test/cover.jpg');
      expect(book.intro, '简介');
      expect(book.lastChapter, '第1279章');
      expect(book.status, ShelfStatus.tracking);
      expect(book.isPinned, isFalse);
      expect(book.progress, isNull);
      expect(book.addedAt, clock.now());
    });

    test('add_givenTheSameIdentityTwice_refreshesButKeepsUserState', () async {
      // 「已在书架」的口径是 (sourceUrl, bookUrl)：重复加入是刷新快照，不是重置用户态。
      await repository.add(candidate());
      final ShelvedBook added = (await repository.getAll()).single;
      await repository.updateUserState(
        id: added.id,
        status: ShelfStatus.read,
        isPinned: true,
      );

      await repository.add(candidate(name: '剑来（全本）'));

      final List<ShelvedBook> books = await repository.getAll();
      expect(books, hasLength(1));
      expect(books.single.name, '剑来（全本）');
      expect(books.single.status, ShelfStatus.read);
      expect(books.single.isPinned, isTrue);
    });

    test('add_givenASecondSource_keepsTwoEntries', () async {
      await repository.add(candidate());
      await repository.add(candidate(sourceUrl: 'https://other.test'));

      expect(await repository.getAll(), hasLength(2));
    });

    test('updateUserState_whenCalled_isVisibleInTheNextRead', () async {
      await repository.add(candidate());
      final ShelvedBook added = (await repository.getAll()).single;

      await repository.updateUserState(
        id: added.id,
        status: ShelfStatus.read,
        isPinned: true,
      );

      final ShelvedBook updated = (await repository.getAll()).single;
      expect(updated.status, ShelfStatus.read);
      expect(updated.isPinned, isTrue);
    });

    test('remove_whenCalled_dropsTheEntry', () async {
      await repository.add(candidate());
      final ShelvedBook added = (await repository.getAll()).single;

      await repository.remove(added.id);

      expect(await repository.getAll(), isEmpty);
    });

    test('saveProgress_whenCalled_showsUpOnTheShelfEntry', () async {
      await repository.add(candidate());
      clock.advance(const Duration(minutes: 2));

      await repository.saveProgress(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        chapterUrl: 'https://source.test/book/1/9.html',
        chapterName: '第九章',
        charOffset: 42,
      );

      final ReadingProgressPosition? progress =
          (await repository.getAll()).single.progress;
      expect(progress?.chapterUrl, 'https://source.test/book/1/9.html');
      expect(progress?.chapterName, '第九章');
      expect(progress?.charOffset, 42);
      expect(progress?.updatedAt, clock.now());
    });
  });
}
