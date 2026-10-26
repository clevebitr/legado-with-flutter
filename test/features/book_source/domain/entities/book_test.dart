import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three parse-result entities of the book source pipeline.
///
/// They are plain immutable values (C-ARCH-5) with no JSON form of their own
/// (ADR-0021 §决策 3), so this file pins the **defaults the rules rely on** rather than the
/// `==` / `copyWith` bodies freezed generates (ADR-0077 §决策 2). It also carries the
/// correctness argument for `book.dart`'s coverage exemption — the file holds nothing but
/// generated declaration lines (see `tool/coverage_allowlist.txt`).
void main() {
  group('Book', () {
    test('Book_givenAChangedField_isNotEqual', () {
      const Book one = Book(name: '书名一', url: 'https://a.test/1');

      expect(one, isNot(one.copyWith(name: '书名二')));
    });
  });

  test('BookInfo_givenNoCanReName_defaultsToFalse', () {
    const BookInfo info = BookInfo(
      name: '书',
      url: 'https://a.test/1',
      tocUrl: 'https://a.test/1',
    );

    // 上游只在书源声明了 `canReName` 时才允许改名（book-source.md §2）。
    expect(info.canReName, isFalse);
    expect(info.copyWith(canReName: true).canReName, isTrue);
  });

  group('Chapter', () {
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
