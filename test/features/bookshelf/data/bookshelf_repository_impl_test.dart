import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/shelf_group_dao.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/bookshelf/data/bookshelf_repository_impl.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_group.dart';
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
        groups: ShelfGroupDao(database, clock: clock),
      );
    });

    tearDown(() => database.close());

    /// A candidate for one book.
    ShelfCandidate candidate({
      String sourceUrl = 'https://source.test',
      String bookUrl = 'https://source.test/book/1',
      String? tocUrl = 'https://source.test/book/1/toc',
      String name = '剑来',
      String? author = '烽火戏诸侯',
      bool canReName = false,
      String? coverUrl = 'https://source.test/cover.jpg',
      String? intro = '简介',
    }) => ShelfCandidate(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      tocUrl: tocUrl,
      canReName: canReName,
      name: name,
      author: author,
      kind: '玄幻',
      coverUrl: coverUrl,
      intro: intro,
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

      // 快照刷新（含改名）只在源声明 `canReName` 时发生，用户态任何时候都不动
      // （ADR-0044 §决策 5）。
      await repository.add(candidate(name: '剑来（全本）', canReName: true));

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

    test('add_whenNew_keepsTheTocUrl', () async {
      // ADR-0044 §决策 3：目录地址随加入书架一起入库，书架打开阅读器时不必猜。
      await repository.add(candidate());

      expect(
        (await repository.getAll()).single.tocUrl,
        'https://source.test/book/1/toc',
      );
    });

    test('add_givenNoRenamePermission_keepsTheStoredTitleAndAuthor', () async {
      await repository.add(candidate());

      await repository.add(
        candidate(
          name: '剑来（修订）',
          author: '别的作者',
          coverUrl: 'https://source.test/cover2.jpg',
        ),
      );

      final ShelvedBook row = (await repository.getAll()).single;
      // ADR-0044 §决策 5：没声明 canReName 的源不得改名，但页面派生字段照常刷新。
      expect(row.name, '剑来');
      expect(row.author, '烽火戏诸侯');
      expect(row.coverUrl, 'https://source.test/cover2.jpg');
    });

    test('add_givenRenamePermission_overwritesTheTitleAndAuthor', () async {
      await repository.add(candidate());

      await repository.add(
        candidate(name: '剑来（修订）', author: '烽火戏诸侯', canReName: true),
      );

      final ShelvedBook row = (await repository.getAll()).single;
      expect(row.name, '剑来（修订）');
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

    test('removeMany_whenCalled_deletesEveryChosenEntry', () async {
      await repository.add(candidate());
      await repository.add(candidate(bookUrl: 'https://source.test/book/2'));
      await repository.add(candidate(bookUrl: 'https://source.test/book/3'));
      final List<ShelvedBook> stored = await repository.getAll();
      await repository.saveProgress(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        chapterUrl: 'https://source.test/1.html',
      );

      await repository.removeMany(<int>[stored.first.id, stored.last.id]);

      final List<ShelvedBook> left = await repository.getAll();
      expect(left, hasLength(1));
      // 进度跟着行一起删：留下的那本才有进度查询的意义（M19 的批量删除）。
      expect(
        await repository.findProgress(
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/1',
        ),
        isNull,
      );
    });

    test('createGroup_whenTheNameIsNew_answersTheGroup', () async {
      final ShelfGroup? group = await repository.createGroup('  仙侠 ');

      expect(group?.name, '仙侠');
      expect(await repository.getGroups(), hasLength(1));
    });

    test('createGroup_whenTheNameIsBlank_answersNull', () async {
      expect(await repository.createGroup('   '), isNull);
      expect(await repository.getGroups(), isEmpty);
    });

    test('createGroup_whenTheNameIsTaken_answersNull', () async {
      await repository.createGroup('仙侠');

      expect(await repository.createGroup('仙侠'), isNull);
      expect(await repository.getGroups(), hasLength(1));
    });

    test('renameGroup_whenTheNameIsTakenByAnother_answersFalse', () async {
      await repository.createGroup('仙侠');
      final ShelfGroup other = (await repository.createGroup('历史'))!;

      expect(await repository.renameGroup(id: other.id, name: '仙侠'), isFalse);
      expect(
        (await repository.getGroups()).map((ShelfGroup g) => g.name),
        containsAll(<String>['仙侠', '历史']),
      );
    });

    test('renameGroup_whenOnlyTheCaseDiffers_answersTrue', () async {
      final ShelfGroup group = (await repository.createGroup('仙侠'))!;

      expect(await repository.renameGroup(id: group.id, name: ' 修真 '), isTrue);
      expect((await repository.getGroups()).single.name, '修真');
    });

    test('renameGroup_whenTheNameIsBlank_answersFalse', () async {
      final ShelfGroup group = (await repository.createGroup('仙侠'))!;

      expect(await repository.renameGroup(id: group.id, name: ' '), isFalse);
    });

    test('deleteGroup_whenTheGroupHasBooks_movesThemToUngrouped', () async {
      await repository.add(candidate());
      final ShelfGroup group = (await repository.createGroup('仙侠'))!;
      final ShelvedBook book = (await repository.getAll()).single;
      await repository.setGroupFor(ids: <int>[book.id], groupId: group.id);

      await repository.deleteGroup(group.id);

      expect(await repository.getGroups(), isEmpty);
      expect((await repository.getAll()).single.groupId, isNull);
    });

    test('reorderGroups_whenCalled_keepsTheGivenOrder', () async {
      final ShelfGroup first = (await repository.createGroup('仙侠'))!;
      final ShelfGroup second = (await repository.createGroup('历史'))!;

      await repository.reorderGroups(<int>[second.id, first.id]);

      expect(
        (await repository.getGroups()).map((ShelfGroup g) => g.name),
        <String>['历史', '仙侠'],
      );
    });

    test('setPinnedFor_whenCalled_pinsEveryChosenEntry', () async {
      await repository.add(candidate());
      final ShelvedBook book = (await repository.getAll()).single;

      await repository.setPinnedFor(ids: <int>[book.id], isPinned: true);

      expect((await repository.getAll()).single.isPinned, isTrue);
    });

    test('setStatusFor_whenCalled_setsEveryChosenEntry', () async {
      await repository.add(candidate());
      final ShelvedBook book = (await repository.getAll()).single;

      await repository.setStatusFor(
        ids: <int>[book.id],
        status: ShelfStatus.read,
      );

      expect((await repository.getAll()).single.status, ShelfStatus.read);
    });

    test('saveCustomCover_whenCalled_keepsThePathAndCanClearIt', () async {
      await repository.add(candidate());
      final ShelvedBook book = (await repository.getAll()).single;

      await repository.saveCustomCover(id: book.id, path: '/covers/abc.jpg');
      expect(
        (await repository.getAll()).single.customCoverPath,
        '/covers/abc.jpg',
      );

      await repository.saveCustomCover(id: book.id, path: null);
      expect((await repository.getAll()).single.customCoverPath, isNull);
    });

    test('updateDetails_whenCalled_writesTitleAuthorAndCustomIntro', () async {
      // 用户改过的三项：书名 / 作者 / 自己的简介（M33，ADR-0092）。
      await repository.add(candidate());
      final ShelvedBook book = (await repository.getAll()).single;

      await repository.updateDetails(
        id: book.id,
        name: '朝花夕拾',
        author: '鲁迅',
        customIntro: '我自己写的简介',
      );

      final ShelvedBook updated = (await repository.getAll()).single;
      expect(updated.name, '朝花夕拾');
      expect(updated.author, '鲁迅');
      expect(updated.customIntro, '我自己写的简介');
      // 书源快照那一列不动：改的是「用户的副本」，不是把来源改掉。
      expect(updated.intro, book.intro);
    });

    test(
      'updateDetails_whenTheIntroIsCleared_fallsBackToTheSnapshot',
      () async {
        await repository.add(candidate());
        final ShelvedBook book = (await repository.getAll()).single;
        await repository.updateDetails(
          id: book.id,
          name: book.name,
          author: book.author,
          customIntro: '草稿',
        );

        await repository.updateDetails(
          id: book.id,
          name: book.name,
          author: book.author,
          customIntro: null,
        );

        expect((await repository.getAll()).single.customIntro, isNull);
      },
    );

    test('findByUrl_whenTheBookIsOnTheShelf_answersItsRow', () async {
      await repository.add(candidate());

      final ShelvedBook? found = await repository.findByUrl(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
      );

      expect(found?.name, '剑来');
    });

    test('findByUrl_whenTheBookIsNotOnTheShelf_answersNull', () async {
      expect(
        await repository.findByUrl(
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/9',
        ),
        isNull,
      );
    });
  });
}
