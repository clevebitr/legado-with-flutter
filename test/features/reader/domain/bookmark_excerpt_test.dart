import 'package:flutter_reader/features/reader/domain/bookmark_excerpt.dart';
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bookmarkExcerpt', () {
    test('bookmarkExcerpt_whenTheBodyIsEmpty_answersEmpty', () {
      expect(bookmarkExcerpt('', 0), '');
    });

    test('bookmarkExcerpt_whenTheLengthIsZero_answersEmpty', () {
      expect(bookmarkExcerpt('正文', 0, maxLength: 0), '');
    });

    test('bookmarkExcerpt_whenTheOffsetIsNegative_startsAtTheBeginning', () {
      expect(bookmarkExcerpt('甲乙丙丁', -5, maxLength: 2), '甲乙');
    });

    test('bookmarkExcerpt_whenTheOffsetIsPastTheEnd_answersEmpty', () {
      expect(bookmarkExcerpt('甲乙丙丁', 10), '');
    });

    test('bookmarkExcerpt_whenTheOffsetIsExactlyTheLength_answersEmpty', () {
      expect(bookmarkExcerpt('甲乙丙丁', 4), '');
    });

    test('bookmarkExcerpt_whenTheBodyIsLonger_answersAtMostTheLength', () {
      final String body = '甲' * 200;

      expect(bookmarkExcerpt(body, 0).length, bookmarkExcerptLength);
      expect(bookmarkExcerpt(body, 0, maxLength: 5), '甲甲甲甲甲');
    });

    test('bookmarkExcerpt_whenTheTailIsShort_answersWhatIsLeft', () {
      expect(bookmarkExcerpt('甲乙丙丁', 2, maxLength: 10), '丙丁');
    });

    test('bookmarkExcerpt_whenTheSliceStartsOnALowSurrogate_dropsIt', () {
      // '😀' 是一个代理对：从它的第二个 code unit 开始切，半个字符必须被丢掉。
      const String body = '😀甲乙';
      final String excerpt = bookmarkExcerpt(body, 1, maxLength: 3);

      expect(excerpt, '甲乙');
    });

    test('bookmarkExcerpt_whenTheSliceEndsOnAHighSurrogate_dropsIt', () {
      const String body = '甲乙😀';
      final String excerpt = bookmarkExcerpt(body, 2, maxLength: 1);

      expect(excerpt, '');
    });

    test('bookmarkExcerpt_whenTheSliceIsAllWhitespace_answersEmpty', () {
      expect(bookmarkExcerpt('    正文', 0, maxLength: 4), '');
    });

    test('bookmarkExcerpt_whenTheBodyStartsOnAPlainCharacter_keepsIt', () {
      expect(bookmarkExcerpt('正文内容', 1, maxLength: 2), '文内');
    });
  });

  group('isBookmarkedAt', () {
    Bookmark mark({int charOffset = 0, String chapterUrl = 'https://a/1'}) =>
        Bookmark(
          id: 1,
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/1',
          bookName: '剑来',
          chapterUrl: chapterUrl,
          charOffset: charOffset,
          createdAt: DateTime(2026, 10, 23),
        );

    test('isBookmarkedAt_whenThePositionIsStored_answersTrue', () {
      expect(
        isBookmarkedAt(
          <Bookmark>[mark(charOffset: 12)],
          chapterUrl: 'https://a/1',
          charOffset: 12,
        ),
        isTrue,
      );
    });

    test('isBookmarkedAt_whenTheOffsetDiffers_answersFalse', () {
      expect(
        isBookmarkedAt(
          <Bookmark>[mark(charOffset: 12)],
          chapterUrl: 'https://a/1',
          charOffset: 13,
        ),
        isFalse,
      );
    });

    test('isBookmarkedAt_whenTheChapterDiffers_answersFalse', () {
      expect(
        isBookmarkedAt(
          <Bookmark>[mark()],
          chapterUrl: 'https://a/2',
          charOffset: 0,
        ),
        isFalse,
      );
    });

    test('isBookmarkedAt_whenNothingIsStored_answersFalse', () {
      expect(
        isBookmarkedAt(
          const <Bookmark>[],
          chapterUrl: 'https://a/1',
          charOffset: 0,
        ),
        isFalse,
      );
    });
  });
}
