import 'package:flutter_reader/core/storage/cache_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cacheKeyFor', () {
    test('cacheKeyFor_whenCalledTwiceWithTheSameRequest_isStable', () {
      expect(
        cacheKeyFor(
          sourceId: 'source-1',
          ruleField: 'searchUrl',
          url: 'https://example.com/s?q=1',
          page: 1,
        ),
        cacheKeyFor(
          sourceId: 'source-1',
          ruleField: 'searchUrl',
          url: 'https://example.com/s?q=1',
          page: 1,
        ),
      );
    });

    test('cacheKeyFor_whenAnyPartDiffers_changesTheKey', () {
      final String base = cacheKeyFor(
        sourceId: 'source-1',
        ruleField: 'searchUrl',
        url: 'https://example.com/s?q=1',
        page: 1,
      );

      expect(
        cacheKeyFor(
          sourceId: 'source-2',
          ruleField: 'searchUrl',
          url: 'https://example.com/s?q=1',
          page: 1,
        ),
        isNot(base),
      );
      expect(
        cacheKeyFor(
          sourceId: 'source-1',
          ruleField: 'contentRule.content',
          url: 'https://example.com/s?q=1',
          page: 1,
        ),
        isNot(base),
      );
      expect(
        cacheKeyFor(
          sourceId: 'source-1',
          ruleField: 'searchUrl',
          url: 'https://example.com/s?q=2',
          page: 1,
        ),
        isNot(base),
      );
      expect(
        cacheKeyFor(
          sourceId: 'source-1',
          ruleField: 'searchUrl',
          url: 'https://example.com/s?q=1',
          page: 2,
        ),
        isNot(base),
      );
    });

    test('cacheKeyFor_whenPartsWouldCollide_keepsThemSeparate', () {
      // 分隔符必须是字段内不可能出现的字符，否则 ('ab','c') 与 ('a','bc') 会撞车。
      expect(
        cacheKeyFor(
          sourceId: 'ab',
          ruleField: 'c',
          url: 'https://example.com/',
          page: 1,
        ),
        isNot(
          cacheKeyFor(
            sourceId: 'a',
            ruleField: 'bc',
            url: 'https://example.com/',
            page: 1,
          ),
        ),
      );
    });

    test('cacheKeyFor_whenUrlCarriesASearchTerm_doesNotStoreItInCleartext', () {
      final String key = cacheKeyFor(
        sourceId: 'source-1',
        ruleField: 'searchUrl',
        url: 'https://example.com/search?q=secret-keyword',
        page: 1,
      );

      expect(key, isNot(contains('secret-keyword')));
      expect(key, isNot(contains('example.com')));
      expect(key, hasLength(64));
    });
  });
}
