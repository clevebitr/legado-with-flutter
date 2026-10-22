import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChapterRequest', () {
    test('ChapterRequest_givenOnlyAUrl_leavesTheContextEmpty', () {
      // 调试控制台只拿到一个 URL：书名 / 章节名默认空串，`java.get` 回落到书源变量
      // （book-source.md §6、ADR-0049）。
      const ChapterRequest request = ChapterRequest(
        url: 'https://a.test/1.html',
      );

      expect(request.url, 'https://a.test/1.html');
      expect(request.title, isEmpty);
      expect(request.bookName, isEmpty);
    });

    test('ChapterRequest_givenANameAndATitle_carriesBoth', () {
      const ChapterRequest request = ChapterRequest(
        url: 'https://a.test/1.html',
        title: '第一章',
        bookName: '示例书',
      );

      expect(request.title, '第一章');
      expect(request.bookName, '示例书');
    });
  });
}
