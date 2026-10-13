import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/domain/explore_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseExploreString', () {
    test(
      'parseExploreString_givenAmpersandSeparatedEntries_readsThemInOrder',
      () {
        final ExploreCategoryParse parsed = parseExploreString(
          '玄幻::https://a.test/x&&都市::https://b.test/y',
        );

        expect(parsed.rejected, isEmpty);
        expect(parsed.categories, <ExploreCategory>[
          const ExploreCategory(title: '玄幻', url: 'https://a.test/x'),
          const ExploreCategory(title: '都市', url: 'https://b.test/y'),
        ]);
      },
    );

    test('parseExploreString_givenNewlinesAndStraySpaces_readsThemToo', () {
      // 分隔正则是 `(&&|\n)+`（上游 BookSourceExtensions.kt:90）：两种分隔都认、可混用。
      final ExploreCategoryParse parsed = parseExploreString(
        ' 玄幻 :: https://a.test/x \n\n 都市::https://b.test/y && ',
      );

      expect(parsed.rejected, isEmpty);
      expect(parsed.categories, hasLength(2));
      expect(parsed.categories.first.title, '玄幻');
      expect(parsed.categories.first.url, 'https://a.test/x');
    });

    test('parseExploreString_givenASingleAmpersandInAUrl_keepsItIntact', () {
      // 单个 `&` 是 URL 的一部分（只有 `&&` 才是分隔符）。
      final ExploreCategoryParse parsed = parseExploreString(
        '书::https://a.test/s?q=1&p=2',
      );

      expect(parsed.categories.single.url, 'https://a.test/s?q=1&p=2');
    });

    test('parseExploreString_givenABlankTitle_rejectsThatEntryOnly', () {
      final ExploreCategoryParse parsed = parseExploreString(
        '::https://a.test/x&&玄幻::https://a.test/y',
      );

      // ADR-0035 §决策 3：坏条目被拒并记录，其余条目照常（C-SRC-4）。
      expect(parsed.rejected, <String>['blank title']);
      expect(parsed.categories, hasLength(1));
      expect(parsed.categories.single.title, '玄幻');
    });

    test('parseExploreString_givenAMissingUrl_rejectsThatEntryOnly', () {
      final ExploreCategoryParse parsed = parseExploreString(
        '玄幻::&&都市::https://a.test/y',
      );

      expect(parsed.rejected, <String>['missing url (title=玄幻)']);
      expect(parsed.categories.single.title, '都市');
    });

    test('parseExploreString_givenNoSeparatorAtAll_rejectsTheEntry', () {
      final ExploreCategoryParse parsed = parseExploreString('玄幻');

      expect(parsed.rejected, <String>['missing "::" separator']);
      expect(parsed.categories, isEmpty);
    });
  });

  group('parseExploreSource', () {
    test('parseExploreSource_givenAJsonArrayString_readsTheJsonForm', () {
      final ExploreCategoryParse parsed = parseExploreSource(
        '[{"title":"玄幻","url":"https://a.test/x"},'
        '{"title":"都市","type":"url","url":"https://b.test/y"}]',
      );

      expect(parsed.rejected, isEmpty);
      expect(parsed.categories, hasLength(2));
      expect(parsed.categories.last.url, 'https://b.test/y');
    });

    test('parseExploreSource_givenAJsonArrayWithoutType_acceptsIt', () {
      // `type` 缺省与 `type == "url"` 都是 M1 支持的分类（ADR-0035 §决策 4）。
      final ExploreCategoryParse parsed = parseExploreSource(
        '[{"title":"玄幻"}]',
      );

      expect(parsed.rejected, <String>['missing url (title=玄幻)']);
      expect(parsed.categories, isEmpty);

      final ExploreCategoryParse urlOnly = parseExploreSource(
        '[{"title":"玄幻","url":"https://a.test/x"}]',
      );
      expect(
        urlOnly.categories.single,
        const ExploreCategory(title: '玄幻', url: 'https://a.test/x'),
      );
    });

    test('parseExploreSource_givenFormCategories_rejectsThemByName', () {
      final ExploreCategoryParse parsed = parseExploreSource(
        '[{"title":"搜索","type":"text"},{"title":"按钮","type":"button"},'
        '{"title":"开关","type":"toggle"},{"title":"选择","type":"select"}]',
      );

      // 表单型分类不在 M1（ADR-0035 §决策 4/6）：逐个按名拒绝 + 记录。
      expect(parsed.categories, isEmpty);
      expect(parsed.rejected, hasLength(4));
      expect(parsed.rejected.first, 'form category (type=text)');
    });

    test('parseExploreSource_givenMalformedJsonEntries_rejectsThem', () {
      final ExploreCategoryParse parsed = parseExploreSource(
        '[1,"x",{"title":"   ","url":"https://a.test/x"},'
        '{"title":"玄幻","url":""}]',
      );

      expect(parsed.categories, isEmpty);
      expect(parsed.rejected, <String>[
        'not an object (int)',
        'not an object (String)',
        'blank title',
        'missing url (title=玄幻)',
      ]);
    });

    test('parseExploreSource_givenAPlainString_readsTheSeparatedForm', () {
      final ExploreCategoryParse parsed = parseExploreSource(
        '玄幻::https://a.test/x',
      );

      expect(parsed.categories.single.title, '玄幻');
    });

    test('parseExploreSource_givenAJsonObject_fallsBackToTheSeparatedForm', () {
      // 只有**数组**才是 JSON 形态（上游 ExploreKind 的反序列化就是数组）。
      final ExploreCategoryParse parsed = parseExploreSource('{"title":"x"}');

      expect(parsed.categories, isEmpty);
      expect(parsed.rejected, <String>['missing "::" separator']);
    });

    test('parseExploreSource_givenBrokenJsonStartingWithBracket_fallsBack', () {
      final ExploreCategoryParse parsed = parseExploreSource('[not json');

      expect(parsed.categories, isEmpty);
      expect(parsed.rejected, <String>['missing "::" separator']);
    });
  });
}
