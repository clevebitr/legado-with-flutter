import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/manga_pages.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal source of [type].
BookSource _source(BookSourceType type) => BookSource(
  name: '示例书源',
  url: 'https://a.test',
  sourceType: type,
  searchRule: const SearchRule(bookList: 'class.item'),
  tocRule: const TocRule(chapterList: 'class.c'),
  contentRule: const ContentRule(content: 'class.page@tag.img@src'),
);

void main() {
  group('isMangaSource', () {
    test('isMangaSource_givenAnImageSource_isTrue', () {
      expect(isMangaSource(_source(BookSourceType.image)), isTrue);
    });

    test('isMangaSource_givenATextSource_isFalse', () {
      expect(isMangaSource(_source(BookSourceType.text)), isFalse);
    });
  });

  group('MangaPages', () {
    test('MangaPages_whenBuilt_keepsTheUrlsAndHeaders', () {
      const MangaPages pages = MangaPages(
        urls: <String>['https://img.test/1.jpg'],
        headers: <String, String>{'Referer': 'https://a.test'},
      );

      expect(pages.urls.single, 'https://img.test/1.jpg');
      expect(pages.headers?['Referer'], 'https://a.test');
    });
  });
}
