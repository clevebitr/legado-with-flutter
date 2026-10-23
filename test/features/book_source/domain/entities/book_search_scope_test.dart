import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookSearchScope.decode', () {
    test('decode_givenNothing_answersAll', () {
      expect(BookSearchScope.decode(null), const BookSearchScope.all());
      expect(BookSearchScope.decode('   '), const BookSearchScope.all());
    });

    test('decode_givenMalformedJson_answersAll', () {
      // 范围是偏好：手改过的存储不能让搜索页崩掉（ADR-0046 §决策 1）。
      expect(BookSearchScope.decode('{'), const BookSearchScope.all());
      expect(BookSearchScope.decode('[]'), const BookSearchScope.all());
      expect(
        BookSearchScope.decode('{"type":"unknown"}'),
        const BookSearchScope.all(),
      );
    });

    test('decode_givenGroups_answersThemTrimmedAndDeduplicated', () {
      final BookSearchScope scope = BookSearchScope.decode(
        '{"type":"group","groups":[" 精选 ","精选","玄幻",""]}',
      );

      expect(scope, const BookSearchScope.groups(<String>{'精选', '玄幻'}));
    });

    test('decode_givenSources_answersThemWithNames', () {
      final BookSearchScope scope = BookSearchScope.decode(
        '{"type":"source","sources":[{"name":"A","url":"https://a.test"},'
        '{"name":"","url":"https://b.test"},{"url":"  "}]}',
      );

      expect(
        scope,
        const BookSearchScope.sources(<ScopeSource>[
          ScopeSource(name: 'A', url: 'https://a.test'),
          ScopeSource(name: '', url: 'https://b.test'),
        ]),
      );
    });

    test('decode_givenAGroupListThatIsNotAList_answersNoGroups', () {
      final BookSearchScope scope = BookSearchScope.decode(
        '{"type":"group","groups":"精选"}',
      );

      expect(scope, const BookSearchScope.groups(<String>{}));
    });
  });

  group('BookSearchScope.encode', () {
    test('encode_givenAll_answersNull', () {
      // `all` 是「不存」：清掉键比存一个 `{"type":"all"}` 更不容易过期。
      expect(const BookSearchScope.all().encode(), isNull);
    });

    test('encode_thenDecode_roundTripsGroups', () {
      const BookSearchScope scope = BookSearchScope.groups(<String>{
        '玄幻',
        '精选',
      });

      expect(BookSearchScope.decode(scope.encode()), scope);
    });

    test('encode_thenDecode_roundTripsSources', () {
      const BookSearchScope scope = BookSearchScope.sources(<ScopeSource>[
        ScopeSource(name: 'A', url: 'https://a.test'),
      ]);

      expect(BookSearchScope.decode(scope.encode()), scope);
    });

    test('encode_givenGroups_writesThemSorted', () {
      // 排序让同一份选择永远写出同一串字节，便于断言与排查。
      expect(
        const BookSearchScope.groups(<String>{'b', 'a'}).encode(),
        '{"type":"group","groups":["a","b"]}',
      );
    });
  });

  group('accessors', () {
    test('groupsOrEmpty_givenGroups_answersThem', () {
      expect(
        const BookSearchScope.groups(<String>{'a'}).groupsOrEmpty,
        <String>{'a'},
      );
      expect(const BookSearchScope.all().groupsOrEmpty, isEmpty);
    });

    test('sourcesOrEmpty_givenSources_answersThem', () {
      const List<ScopeSource> sources = <ScopeSource>[
        ScopeSource(name: 'A', url: 'https://a.test'),
      ];

      expect(const BookSearchScope.sources(sources).sourcesOrEmpty, sources);
      expect(
        const BookSearchScope.groups(<String>{'a'}).sourcesOrEmpty,
        isEmpty,
      );
    });
  });
}
