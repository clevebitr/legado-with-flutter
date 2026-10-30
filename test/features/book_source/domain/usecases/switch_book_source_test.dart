import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/change_source_search.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/switch_book_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// The source the user picked.
BookSource _target() => const BookSource(
  name: '乙源',
  url: 'https://b.test',
  searchRule: SearchRule(bookList: 'class.result'),
  tocRule: TocRule(chapterList: 'class.chapter'),
  contentRule: ContentRule(content: 'class.body'),
);

/// One chapter value for the alignment helpers.
Chapter _chapter(String name, int index) =>
    Chapter(name: name, url: 'https://b.test/c/$index');

/// A selection of the [index]-th chapter of a three-chapter table of contents.
ChangeSourceSelection _selection({int index = 1, String? tocUrl}) =>
    ChangeSourceSelection(
      candidate: ChangeSourceCandidate(
        source: _target(),
        book: const Book(
          name: '剑来（精校版）',
          url: 'https://b.test/book/7',
          author: '烽火戏诸侯',
          coverUrl: 'https://b.test/cover.jpg',
          lastChapter: '第120章',
        ),
        match: ChangeSourceMatch.partial,
        tocUrl: tocUrl,
      ),
      chapters: <Chapter>[
        _chapter('第一章', 0),
        _chapter('第二章', 1),
        _chapter('第三章', 2),
      ],
      chapterIndex: index,
    );

void main() {
  group('SwitchBookSource withChapters', () {
    test('withChapters_givenASelection_answersTheNewIdentity', () {
      final SourceSwitchResult result = const SwitchBookSource().withChapters(
        target: _target(),
        selection: _selection(),
      );

      expect(result.sourceUrl, 'https://b.test');
      expect(result.sourceName, '乙源');
      expect(result.bookUrl, 'https://b.test/book/7');
      expect(result.bookName, '剑来（精校版）');
      expect(result.author, '烽火戏诸侯');
      expect(result.coverUrl, 'https://b.test/cover.jpg');
      expect(result.lastChapter, '第120章');
      // 章节来自用户选的那一条，不是对齐算法猜的。
      expect(result.chapterUrl, 'https://b.test/c/1');
      expect(result.chapterName, '第二章');
      expect(result.chapterIndex, 1);
    });

    test('withChapters_givenNoTocUrl_fallsBackToTheBookUrl', () {
      // 没开「加载详情」时候选没有 tocUrl：目录地址回落到书籍页（ADR-0069 G8 的同一口径）。
      final SourceSwitchResult result = const SwitchBookSource().withChapters(
        target: _target(),
        selection: _selection(),
      );

      expect(result.tocUrl, 'https://b.test/book/7');
    });

    test('withChapters_givenATocUrl_keepsIt', () {
      final SourceSwitchResult result = const SwitchBookSource().withChapters(
        target: _target(),
        selection: _selection(tocUrl: 'https://b.test/toc'),
      );

      expect(result.tocUrl, 'https://b.test/toc');
    });
  });

  group('SwitchBookSource alignment', () {
    final List<Chapter> chapters = <Chapter>[
      _chapter('第一章 少年', 0),
      _chapter('第二章 剑来', 1),
      _chapter('第三章 远方', 2),
    ];

    test('alignChapterIndex_givenTheSameName_findsThatChapter', () {
      expect(
        const SwitchBookSource().alignChapterIndex(
          chapters,
          '第二章 剑来',
          fallbackIndex: 0,
        ),
        1,
      );
    });

    test('alignChapterIndex_givenAContainedName_findsIt', () {
      expect(
        const SwitchBookSource().alignChapterIndex(
          chapters,
          '剑来',
          fallbackIndex: 0,
        ),
        1,
      );
    });

    test('alignChapterIndex_givenNoMatch_fallsBackToTheSameIndex', () {
      expect(
        const SwitchBookSource().alignChapterIndex(
          chapters,
          '不存在的章',
          fallbackIndex: 2,
        ),
        2,
      );
    });

    test('alignChapterIndex_givenAnIndexPastTheEnd_clampsIt', () {
      expect(
        const SwitchBookSource().alignChapterIndex(
          chapters,
          '',
          fallbackIndex: 99,
        ),
        2,
      );
      expect(
        const SwitchBookSource().alignChapterIndex(
          chapters,
          '',
          fallbackIndex: -5,
        ),
        0,
      );
    });
  });
}
