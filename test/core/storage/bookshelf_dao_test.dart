import 'package:drift/native.dart';
import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
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
  group('BookshelfDao', () {
    late ReaderDatabase database;
    late _FixedClock clock;
    late BookshelfDao dao;

    setUp(() {
      database = ReaderDatabase(NativeDatabase.memory());
      clock = _FixedClock(DateTime(2026, 10, 21));
      dao = BookshelfDao(database, clock: clock);
    });

    tearDown(() => database.close());

    /// Inserts one shelf row, defaulting everything but the identity.
    Future<int> insert({
      String sourceUrl = 'https://source.test',
      String bookUrl = 'https://source.test/book/1',
      String? tocUrl = 'https://source.test/book/1/toc',
      String name = '剑来',
      String? author = '烽火戏诸侯',
      String? lastChapter = '第1279章',
    }) => dao.insertNew(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      tocUrl: tocUrl,
      name: name,
      author: author,
      kind: '玄幻',
      coverUrl: null,
      intro: null,
      lastChapter: lastChapter,
    );

    test('findAll_whenNothingWasAdded_returnsNothing', () async {
      expect(await dao.findAll(), isEmpty);
    });

    test('insertNew_whenCalled_keepsThePageSnapshot', () async {
      await insert();

      final BookshelfRow row = (await dao.findAll()).single;

      expect(row.book.name, '剑来');
      expect(row.book.author, '烽火戏诸侯');
      expect(row.book.kind, '玄幻');
      expect(row.book.status, 0);
      expect(row.book.isPinned, isFalse);
      expect(row.book.addedAt, clock.now());
      expect(row.progress, isNull);
    });

    test('findIdentity_givenTheSameSource_findsTheRow', () async {
      final int id = await insert();

      final BookRow? row = await dao.findIdentity(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
      );

      expect(row?.id, id);
    });

    test('findIdentity_givenAnotherSource_returnsNothing', () async {
      await insert();

      expect(
        await dao.findIdentity(
          sourceUrl: 'https://other.test',
          bookUrl: 'https://source.test/book/1',
        ),
        isNull,
      );
    });

    test('insertNew_whenCalled_keepsTheTocUrl', () async {
      await insert();

      expect(
        (await dao.findAll()).single.book.tocUrl,
        'https://source.test/book/1/toc',
      );
    });

    test('migrateIdentity_whenCalled_rewritesTheIdentityInPlace', () async {
      // ADR-0051 §决策 3：换源改的是身份，不是行 —— `addedAt` / 状态 / 置顶都要留住。
      final int id = await insert();

      await dao.migrateIdentity(
        id: id,
        sourceUrl: 'https://other.test',
        bookUrl: 'https://other.test/book/9',
        tocUrl: 'https://other.test/book/9/toc',
        name: '剑来（新源）',
        author: '烽火戏诸侯',
        coverUrl: 'https://other.test/c.jpg',
        lastChapter: '第1300章',
      );

      final BookshelfRow row = (await dao.findAll()).single;
      expect(row.book.id, id);
      expect(row.book.sourceUrl, 'https://other.test');
      expect(row.book.bookUrl, 'https://other.test/book/9');
      expect(row.book.addedAt, isNotNull);
    });

    test(
      'refreshDetails_givenNoRenamePermission_keepsTheStoredTitle',
      () async {
        // ADR-0044 §决策 5：没声明 `canReName` 的源不得改写用户已看到的书名 / 作者，
        // 但封面、简介、最新章节这些页面派生的字段照样刷新。
        final int id = await insert();

        await dao.refreshDetails(
          id: id,
          tocUrl: 'https://source.test/book/1/toc2',
          name: '别的名字',
          author: '别的作者',
          kind: '武侠',
          coverUrl: 'https://source.test/c.jpg',
          intro: '新简介',
          lastChapter: '第1281章',
          rewritesTitle: false,
        );

        final BookRow row = (await dao.findAll()).single.book;
        expect(row.name, '剑来');
        expect(row.author, '烽火戏诸侯');
        expect(row.kind, '武侠');
        expect(row.coverUrl, 'https://source.test/c.jpg');
        expect(row.intro, '新简介');
        expect(row.lastChapter, '第1281章');
        expect(row.tocUrl, 'https://source.test/book/1/toc2');
      },
    );

    test('refreshDetails_whenCalled_keepsTheUserState', () async {
      final int id = await insert();
      await dao.updateUserState(id: id, status: 1, isPinned: true);
      clock.advance(const Duration(minutes: 1));

      await dao.refreshDetails(
        id: id,
        tocUrl: 'https://source.test/book/1/toc',
        rewritesTitle: true,
        name: '剑来（修订）',
        author: '烽火戏诸侯',
        kind: '玄幻',
        coverUrl: null,
        intro: null,
        lastChapter: '第1280章',
      );

      final BookshelfRow entry = (await dao.findAll()).single;
      final BookRow row = entry.book;
      expect(row.name, '剑来（修订）');
      expect(row.lastChapter, '第1280章');
      // 用户态列由 `updateUserState` 拥有，重新抓详情不得把它重置（ADR-0040 §决策 3 的同一条规则）。
      expect(row.status, 1);
      expect(row.isPinned, isTrue);
      expect(row.updatedAt, clock.now());
    });

    test('updateUserState_whenCalled_writesBothColumns', () async {
      final int id = await insert();

      await dao.updateUserState(id: id, status: 1, isPinned: true);

      final BookshelfRow entry = (await dao.findAll()).single;
      final BookRow row = entry.book;
      expect(row.status, 1);
      expect(row.isPinned, isTrue);
    });

    test(
      'restoreUserState_givenATocUrl_fillsItWhenTheLocalRowHasNone',
      () async {
        // 恢复只在本地没有目录地址时补（ADR-0073 §决策 3）：有值说明本机已解析过，不该被改回去。
        final int id = await insert(tocUrl: null);

        await dao.restoreUserState(
          id: id,
          status: 1,
          isPinned: true,
          groupId: null,
          customCoverPath: '/covers/x.jpg',
          tocUrl: 'https://source.test/book/1/toc',
        );

        final BookRow row = (await dao.findAll()).single.book;
        expect(row.tocUrl, 'https://source.test/book/1/toc');
        expect(row.customCoverPath, '/covers/x.jpg');
        expect(row.isPinned, isTrue);
      },
    );

    test('findAll_whenTwoRows_ordersPinnedFirst', () async {
      final int first = await insert(bookUrl: 'https://source.test/book/1');
      final int second = await insert(
        bookUrl: 'https://source.test/book/2',
        name: '雪中悍刀行',
      );
      clock.advance(const Duration(minutes: 5));
      await dao.updateUserState(id: first, status: 0, isPinned: true);

      final List<BookshelfRow> rows = await dao.findAll();

      expect(rows.map((BookshelfRow row) => row.book.id), <int>[first, second]);
    });

    test('findAll_whenProgressExists_ordersByRecentlyRead', () async {
      final int older = await insert(bookUrl: 'https://source.test/book/1');
      final int newer = await insert(bookUrl: 'https://source.test/book/2');
      clock.advance(const Duration(minutes: 1));
      await dao.upsertProgress(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        chapterUrl: 'https://source.test/book/1/9.html',
        chapterName: '第九章',
        charOffset: 120,
      );
      clock.advance(const Duration(minutes: 1));
      await dao.upsertProgress(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/2',
        chapterUrl: 'https://source.test/book/2/3.html',
        chapterName: '第三章',
        charOffset: 0,
      );

      final List<BookshelfRow> rows = await dao.findAll();

      // 最近读过的排前面，未读的（无进度行）排在它们之后。
      expect(rows.map((BookshelfRow row) => row.book.id), <int>[newer, older]);
      expect(rows.first.progress?.chapterName, '第三章');
    });

    test('upsertProgress_whenCalledTwice_replacesThePosition', () async {
      await insert();
      await dao.upsertProgress(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        chapterUrl: 'https://source.test/book/1/9.html',
        chapterName: '第九章',
        charOffset: 120,
      );

      await dao.upsertProgress(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        chapterUrl: 'https://source.test/book/1/10.html',
        chapterName: '第十章',
        charOffset: 0,
      );

      final ReadingProgressRow? progress = await dao.findProgress(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
      );
      expect(progress?.chapterName, '第十章');
    });

    test('deleteIdentity_whenCalled_removesTheProgressToo', () async {
      await insert();
      await dao.upsertProgress(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        chapterUrl: 'https://source.test/book/1/9.html',
        chapterName: '第九章',
        charOffset: 0,
      );

      await dao.deleteIdentity(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
      );

      expect(await dao.findAll(), isEmpty);
      expect(
        await dao.findProgress(
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/1',
        ),
        isNull,
      );
    });

    test('deleteAll_whenCalled_removesBooksAndProgress', () async {
      await insert();
      await dao.upsertProgress(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        chapterUrl: 'https://source.test/book/1/9.html',
        chapterName: '第九章',
        charOffset: 0,
      );

      expect(await dao.deleteAll(), 1);
      expect(await dao.findAll(), isEmpty);
    });

    test('deleteById_givenAnUnknownId_reportsNothingDeleted', () async {
      expect(await dao.deleteById(42), 0);
    });

    test('deleteByIds_whenNoIdIsChosen_deletesNothing', () async {
      await insert();

      expect(await dao.deleteByIds(const <int>[]), 0);
      expect(await dao.findAll(), hasLength(1));
    });

    test(
      'deleteByIds_whenTwoRowsAreChosen_removesThemAndTheirProgress',
      () async {
        final int first = await insert();
        final int second = await insert(bookUrl: 'https://source.test/book/2');
        await insert(bookUrl: 'https://source.test/book/3');
        await dao.upsertProgress(
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/1',
          chapterUrl: 'https://source.test/1.html',
          chapterName: '第1章',
          charOffset: 0,
        );

        expect(await dao.deleteByIds(<int>[first, second]), 2);
        expect(await dao.findAll(), hasLength(1));
        expect(
          await dao.findProgress(
            sourceUrl: 'https://source.test',
            bookUrl: 'https://source.test/book/1',
          ),
          isNull,
        );
      },
    );

    test('setCustomCover_whenCalled_writesThePath', () async {
      final int id = await insert();

      await dao.setCustomCover(id: id, path: '/covers/a.jpg');

      expect(
        (await dao.findAll()).single.book.customCoverPath,
        '/covers/a.jpg',
      );
    });
  });
}
