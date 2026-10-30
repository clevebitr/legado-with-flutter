import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/search_book.dart';
import 'package:flutter_reader/features/book_source/domain/search_match_mode.dart';
import 'package:flutter_reader/features/book_source/domain/search_result_merger.dart';
import 'package:flutter_test/flutter_test.dart';

/// A hit with just enough fields to be classified.
Book _hit(
  String name, {
  String? author,
  String? kind,
  String url = 'https://a.test/1',
}) => Book(name: name, author: author, kind: kind, url: url);

/// The names of [books], in order.
List<String> _names(List<SearchBook> books) =>
    books.map((SearchBook book) => book.name).toList();

void main() {
  group('searchBucketOf', () {
    test('searchBucketOf_givenAnExactName_answersEqual', () {
      expect(
        searchBucketOf(_hit('剑来'), '剑来', SearchMatchMode.defaultMode),
        SearchHitBucket.equal,
      );
    });

    test('searchBucketOf_givenAnExactAuthorInAnotherCase_answersEqual', () {
      // 大小写归一化是唯一的归一化（ADR-0046 §决策 3）。
      expect(
        searchBucketOf(
          _hit('x', author: 'ABC'),
          'abc',
          SearchMatchMode.defaultMode,
        ),
        SearchHitBucket.equal,
      );
    });

    test('searchBucketOf_givenAMatchingCategory_answersTags', () {
      expect(
        searchBucketOf(
          _hit('x', kind: '东方玄幻'),
          '玄幻',
          SearchMatchMode.defaultMode,
        ),
        SearchHitBucket.tags,
      );
    });

    test('searchBucketOf_givenASubstring_answersContains', () {
      expect(
        searchBucketOf(_hit('剑来最新章节'), '剑来', SearchMatchMode.defaultMode),
        SearchHitBucket.contains,
      );
    });

    test('searchBucketOf_givenNothingMatching_answersOther', () {
      expect(
        searchBucketOf(_hit('无关'), '剑来', SearchMatchMode.defaultMode),
        SearchHitBucket.other,
      );
    });

    test('searchBucketOf_givenExactMode_dropsTheThreeLooseBuckets', () {
      // 上游 `classifyBucket` 在 EXACT 下把 tags / contains / other 全部丢弃 —— 容易误读，
      // 所以单独钉一条。
      expect(
        searchBucketOf(_hit('x', kind: '玄幻'), '玄幻', SearchMatchMode.exact),
        isNull,
      );
      expect(
        searchBucketOf(_hit('剑来最新章节'), '剑来', SearchMatchMode.exact),
        isNull,
      );
      expect(searchBucketOf(_hit('无关'), '剑来', SearchMatchMode.exact), isNull);
    });

    test('searchBucketOf_givenABlankKeyword_answersNull', () {
      // 空关键词没有匹配语义：`''.contains('')` 会让一切命中，所以先挡住。
      // 聚合用例也会先拒绝空关键词，这里让分类函数自身也是安全的。
      expect(
        searchBucketOf(_hit('x'), '  ', SearchMatchMode.defaultMode),
        isNull,
      );
    });

    test('searchBucketOf_givenABlankAuthor_doesNotLetItMatch', () {
      expect(
        searchBucketOf(_hit('无关'), '剑来', SearchMatchMode.defaultMode),
        SearchHitBucket.other,
      );
    });
  });

  group('SearchResultMerger', () {
    test('add_givenOneSource_answersItsHitsWithOneOrigin', () {
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );

      merger.add(<Book>[_hit('剑来')], sourceUrl: 'https://a.test');

      expect(merger.count, 1);
      expect(merger.books.single.origins, <String>['https://a.test']);
    });

    test('add_givenTheSameBookInTwoSources_mergesTheOrigins', () {
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );

      merger.add(<Book>[_hit('剑来')], sourceUrl: 'https://a.test');
      merger.add(<Book>[
        _hit('剑来', url: 'https://b.test/9'),
      ], sourceUrl: 'https://b.test');

      expect(merger.count, 1);
      expect(merger.books.single.origins, <String>[
        'https://a.test',
        'https://b.test',
      ]);
      // URL 留第一次那一条：它才是列表点开时要用的地址。
      expect(merger.books.single.url, 'https://a.test/1');
    });

    test('add_givenTheSameSourceTwice_doesNotDuplicateOrigins', () {
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );

      merger.add(<Book>[_hit('剑来')], sourceUrl: 'https://a.test');
      final bool changed = merger.add(<Book>[
        _hit('剑来'),
      ], sourceUrl: 'https://a.test');

      expect(changed, isFalse);
      expect(merger.books.single.origins, <String>['https://a.test']);
    });

    test('books_givenEveryBucket_ordersEqualTagsContainsOther', () {
      // 桶间顺序就是显示顺序：精确 → 分类命中 → 子串命中 → 其它（ADR-0046 §决策 3）。
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );

      merger.add(<Book>[
        _hit('无关的书', url: 'https://a.test/4'),
        _hit('剑来前传', url: 'https://a.test/3'),
        _hit('玄幻大全', kind: '剑来同人', url: 'https://a.test/2'),
        _hit('剑来', url: 'https://a.test/1'),
      ], sourceUrl: 'https://a.test');

      expect(_names(merger.books), <String>['剑来', '玄幻大全', '剑来前传', '无关的书']);
    });

    test('books_givenMoreOrigins_sortsThatBookFirstInsideItsBucket', () {
      // 多源命中 = 更可靠，桶内按 origins 数降序（上游 getSortedList）。
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );
      merger.add(<Book>[_hit('剑来甲')], sourceUrl: 'https://a.test');
      merger.add(<Book>[_hit('剑来乙')], sourceUrl: 'https://a.test');
      merger.add(<Book>[
        _hit('剑来甲', url: 'https://b.test/1'),
      ], sourceUrl: 'https://b.test');

      expect(_names(merger.books), <String>['剑来甲', '剑来乙']);
    });

    test('books_givenExactMode_keepsOnlyTheEqualBucket', () {
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.exact,
      );

      merger.add(<Book>[
        _hit('剑来', kind: '玄幻'),
        _hit('剑来前传'),
        _hit('无关的书'),
      ], sourceUrl: 'https://a.test');

      expect(_names(merger.books), <String>['剑来']);
    });

    test('add_givenMoreThanTheCap_evictsAndFlagsTheLimit', () {
      // 上限 1000（ADR-0046 §决策 7）：超了要淘汰「最不值」的行，并让 hasMore 关掉。
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );
      merger.add(<Book>[
        _hit('剑来'),
        for (var index = 0; index < maxRetainedSearchBooks; index++)
          _hit('无关$index', url: 'https://a.test/$index'),
      ], sourceUrl: 'https://a.test');

      expect(merger.count, maxRetainedSearchBooks);
      expect(merger.resultLimitReached, isTrue);
      // 精确命中的那本不能被淘汰：它是用户真正要找的。
      expect(_names(merger.books), contains('剑来'));
    });

    test('bucketOf_whenCalled_answersWhereTheBookIsFiled', () {
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );
      merger.add(<Book>[
        _hit('剑来', url: 'https://a.test/1'),
        _hit('剑来前传', url: 'https://a.test/2'),
        _hit('玄幻大全', kind: '剑来', url: 'https://a.test/3'),
        _hit('无关', url: 'https://a.test/4'),
      ], sourceUrl: 'https://a.test');

      expect(merger.books.map(merger.bucketOf).toList(), <SearchHitBucket>[
        SearchHitBucket.equal,
        SearchHitBucket.tags,
        SearchHitBucket.contains,
        SearchHitBucket.other,
      ]);
    });

    test('add_givenOnlyLooseBucketsOverTheCap_evictsThemFirst', () {
      // 上限淘汰顺序：other → tags → 来源最少的 contains → 来源最少的 equal
      // （上游 trimSearchBooks，ADR-0046 §决策 7）。
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );
      // 全是 contains（名字包含关键词）——没有 other / tags 可淘汰。
      merger.add(<Book>[
        for (var index = 0; index < maxRetainedSearchBooks + 5; index++)
          _hit('剑来$index', url: 'https://a.test/$index'),
      ], sourceUrl: 'https://a.test');

      expect(merger.count, maxRetainedSearchBooks);
      expect(merger.resultLimitReached, isTrue);
    });

    test('add_givenOnlyExactMatchesOverTheCap_stillKeepsTheCap', () {
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );
      merger.add(<Book>[
        for (var index = 0; index < maxRetainedSearchBooks + 2; index++)
          _hit('剑来', url: 'https://a.test/$index', author: '作者$index'),
      ], sourceUrl: 'https://a.test');

      expect(merger.count, maxRetainedSearchBooks);
    });

    test('add_givenAHitOnlyInALooseBucket_keepsItUnderTheDefaultMode', () {
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );

      final bool changed = merger.add(<Book>[
        _hit('无关的书'),
      ], sourceUrl: 'https://a.test');

      expect(changed, isTrue);
      expect(merger.books, hasLength(1));
    });
  });

  group('SearchBook.fromHit', () {
    test('fromHit_whenCalled_carriesTheFirstOriginAndTheDisplayFields', () {
      final SearchBook book = SearchBook.fromHit(
        _hit('剑来', author: '作者', kind: '玄幻', url: 'https://a.test/1'),
        sourceUrl: 'https://a.test',
      );

      expect(book.name, '剑来');
      expect(book.author, '作者');
      expect(book.kind, '玄幻');
      expect(book.url, 'https://a.test/1');
      expect(book.origins, <String>['https://a.test']);
    });

    test('fromHit_whenCalled_keepsThatOriginSnapshot', () {
      final SearchBook book = SearchBook.fromHit(
        _hit('剑来', author: '作者', url: 'https://a.test/1'),
        sourceUrl: 'https://a.test',
      );

      expect(book.hits.single.sourceUrl, 'https://a.test');
      expect(book.hits.single.url, 'https://a.test/1');
      expect(book.hits.single.author, '作者');
    });

    test('mergeKeyOf_whenCalled_trimsAndFoldsCase', () {
      expect(mergeKeyOf('  剑来 ABC '), '剑来 abc');
    });
  });

  group('SearchResultMerger source snapshots', () {
    test('add_givenTheSameBookInTwoSources_keepsBothSnapshots', () {
      // 「4 个来源」要能按任意一个源打开：合并行必须保留每源自己的地址（ADR-0091 §决策 6）。
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '剑来',
        mode: SearchMatchMode.defaultMode,
      );

      merger.add(<Book>[
        _hit('剑来', author: '作者', url: 'https://a.test/1'),
      ], sourceUrl: 'https://a.test');
      merger.add(<Book>[
        _hit('剑来', author: '作者', url: 'https://b.test/2'),
      ], sourceUrl: 'https://b.test');

      final SearchBook merged = merger.books.single;
      expect(merged.origins, <String>['https://a.test', 'https://b.test']);
      expect(merged.hits.map((OriginHit hit) => hit.url), <String>[
        'https://a.test/1',
        'https://b.test/2',
      ]);
    });

    test('add_givenTwoNamelessHits_keepsThemApart', () {
      // 空书名的合并键曾经是 `('','')`，不同源的无名书会叠成一行（DECISIONS #75）。
      final SearchResultMerger merger = SearchResultMerger(
        keyword: '无关',
        mode: SearchMatchMode.defaultMode,
      );

      merger.add(<Book>[
        _hit('', url: 'https://a.test/1'),
      ], sourceUrl: 'https://a.test');
      merger.add(<Book>[
        _hit('', url: 'https://b.test/2'),
      ], sourceUrl: 'https://b.test');

      expect(merger.books, hasLength(2));
      expect(searchBookKeyOf(merger.books.first).url, 'https://a.test/1');
    });
  });
}
