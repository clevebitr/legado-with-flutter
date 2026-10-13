import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three parse-result entities of the book source pipeline.
///
/// They are plain immutable values (C-ARCH-5) with no JSON form of their own
/// (ADR-0021 §决策 3), so this file pins the value semantics the use cases rely on:
/// structural equality and `copyWith`. It also carries the correctness argument for
/// `book.dart`'s coverage exemption — the file holds nothing but generated
/// declaration lines (see `tool/coverage_allowlist.txt`).
void main() {
  group('Book', () {
    test('Book_givenTheSameFields_isEqual', () {
      const Book one = Book(name: '书名一', url: 'https://a.test/1');
      const Book two = Book(name: '书名一', url: 'https://a.test/1');

      expect(one, two);
      expect(one.hashCode, two.hashCode);
    });

    test('Book_givenAChangedField_isNotEqual', () {
      const Book one = Book(name: '书名一', url: 'https://a.test/1');

      expect(one, isNot(one.copyWith(name: '书名二')));
    });

    test('Book_copyWith_givenOnlyOneField_keepsTheOthers', () {
      const Book one = Book(
        name: '书名一',
        url: 'https://a.test/1',
        author: '作者甲',
        kind: '玄幻',
        coverUrl: 'https://a.test/1.jpg',
        intro: '简介',
        lastChapter: '第3章',
        wordCount: '1000',
      );

      final Book updated = one.copyWith(name: '书名二');

      expect(updated.name, '书名二');
      expect(updated.url, one.url);
      expect(updated.author, one.author);
      expect(updated.kind, one.kind);
      expect(updated.coverUrl, one.coverUrl);
      expect(updated.intro, one.intro);
      expect(updated.lastChapter, one.lastChapter);
      expect(updated.wordCount, one.wordCount);
    });
  });

  group('BookInfo', () {
    test('BookInfo_givenTheSameFields_isEqual', () {
      const BookInfo one = BookInfo(
        name: '书名一',
        url: 'https://a.test/1',
        tocUrl: 'https://a.test/1',
      );
      const BookInfo two = BookInfo(
        name: '书名一',
        url: 'https://a.test/1',
        tocUrl: 'https://a.test/1',
      );

      expect(one, two);
      expect(one.hashCode, two.hashCode);
    });

    test('BookInfo_copyWith_givenANewTocUrl_replacesOnlyThatField', () {
      const BookInfo one = BookInfo(
        name: '书名一',
        url: 'https://a.test/1',
        tocUrl: 'https://a.test/1',
        author: '作者甲',
        kind: '玄幻',
        coverUrl: 'https://a.test/1.jpg',
        intro: '简介',
        lastChapter: '第3章',
        wordCount: '1000',
      );

      final BookInfo updated = one.copyWith(tocUrl: 'https://a.test/1/toc');

      expect(updated.tocUrl, 'https://a.test/1/toc');
      expect(updated.name, one.name);
      expect(updated.author, one.author);
      expect(updated.kind, one.kind);
      expect(updated.coverUrl, one.coverUrl);
      expect(updated.intro, one.intro);
      expect(updated.lastChapter, one.lastChapter);
      expect(updated.wordCount, one.wordCount);
    });
  });

  group('Chapter', () {
    test('Chapter_givenTheSameFields_isEqual', () {
      const Chapter one = Chapter(name: '第1章', url: 'https://a.test/1.html');
      const Chapter two = Chapter(name: '第1章', url: 'https://a.test/1.html');

      expect(one, two);
      expect(one.hashCode, two.hashCode);
    });

    test('Chapter_copyWith_givenANewUrl_replacesOnlyThatField', () {
      const Chapter one = Chapter(name: '第1章', url: 'https://a.test/1.html');

      expect(one.copyWith(url: 'https://a.test/2.html'), isNot(one));
      expect(one.copyWith(url: 'https://a.test/2.html').name, '第1章');
    });

    test('Chapter_givenNoIsVip_defaultsToNonVip', () {
      const Chapter chapter = Chapter(
        name: '第1章',
        url: 'https://a.test/1.html',
      );

      expect(chapter.isVip, isFalse);
      expect(chapter.copyWith(isVip: true).isVip, isTrue);
    });

    test('Chapter_givenNoUpdateTime_readsAsNull', () {
      // `updateTime` 是展示用字符串（book-source.md §2）：未声明就是 null，没有默认值。
      const Chapter chapter = Chapter(
        name: '第1章',
        url: 'https://a.test/1.html',
      );

      expect(chapter.updateTime, isNull);
      expect(
        chapter.copyWith(updateTime: '2026/10/13 09:05').updateTime,
        '2026/10/13 09:05',
      );
    });
  });
}
