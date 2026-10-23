import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/search_source_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// One stored source with the fields the resolver looks at.
StoredBookSource _row({
  String name = 'src',
  String? url,
  String? group,
  String searchUrl = 'https://x.test/s?q={{key}}',
  bool isEnabled = true,
  BookSourceType type = BookSourceType.text,
}) => StoredBookSource(
  id: name.hashCode,
  source: BookSource.fromLegadoJson(<String, Object?>{
    'bookSourceName': name,
    'bookSourceUrl': url ?? 'https://$name.test',
    'searchUrl': searchUrl,
    'ruleSearch': <String, Object?>{'bookList': 'class.item'},
    'ruleToc': <String, Object?>{'chapterList': 'class.c'},
    'ruleContent': <String, Object?>{'content': 'class.body'},
    'bookSourceType': type.index,
  }),
  isEnabled: isEnabled,
  customOrder: 0,
  importedAt: DateTime(2026, 10, 21),
  groupName: group,
);

void main() {
  group('resolveSearchSources', () {
    test('resolve_givenAll_answersEveryEnabledTextSource', () {
      final SearchSourceResolution resolution = resolveSearchSources(
        rows: <StoredBookSource>[
          _row(name: 'a'),
          _row(name: 'b', isEnabled: false),
          _row(name: 'c', type: BookSourceType.audio),
        ],
        scope: const BookSearchScope.all(),
      );

      expect(
        resolution.sources.map((BookSource source) => source.name),
        <String>['a'],
      );
      // `all` / `groups` 范围在选候选时就已经把禁用源排除掉了；`sources` 范围才会记
      // 「这条被禁用了」，因为那是用户点名要的源。
      expect(resolution.skipped.containsKey('https://b.test'), isFalse);
      expect(
        resolution.skipped['https://c.test'],
        SearchSourceSkip.typeFiltered,
      );
      expect(resolution.scopeFellBack, isFalse);
    });

    test('resolve_givenGroups_answersTheSourcesOfThoseGroups', () {
      final SearchSourceResolution resolution = resolveSearchSources(
        rows: <StoredBookSource>[
          _row(name: 'a', group: '精选, 玄幻'),
          _row(name: 'b', group: '玄幻'),
          _row(name: 'c', group: '其他'),
        ],
        scope: const BookSearchScope.groups(<String>{'精选'}),
      );

      expect(
        resolution.sources.map((BookSource source) => source.name),
        <String>['a'],
      );
    });

    test('resolve_givenSources_answersThemInTheScopeOrder', () {
      final SearchSourceResolution resolution = resolveSearchSources(
        rows: <StoredBookSource>[
          _row(name: 'a'),
          _row(name: 'b'),
        ],
        scope: const BookSearchScope.sources(<ScopeSource>[
          ScopeSource(name: 'b', url: 'https://b.test'),
          ScopeSource(name: 'a', url: 'https://a.test'),
        ]),
      );

      expect(
        resolution.sources.map((BookSource source) => source.name),
        <String>['b', 'a'],
      );
    });

    test('resolve_givenASourcesScopeWithAGoneUrl_recordsItAsMissing', () {
      final SearchSourceResolution resolution = resolveSearchSources(
        rows: <StoredBookSource>[_row(name: 'a')],
        scope: const BookSearchScope.sources(<ScopeSource>[
          ScopeSource(name: 'a', url: 'https://a.test'),
          ScopeSource(name: 'gone', url: 'https://gone.test'),
        ]),
      );

      expect(resolution.sources, hasLength(1));
      expect(resolution.skipped['https://gone.test'], SearchSourceSkip.missing);
    });

    test('resolve_givenAGroupNobodyCarries_fallsBackToEverything', () {
      // 分组被改名 / 删源后不再存在：回落「全部启用」，而不是给一个空搜索页（ADR-0046 §决策 1）。
      final SearchSourceResolution resolution = resolveSearchSources(
        rows: <StoredBookSource>[
          _row(name: 'a'),
          _row(name: 'b', isEnabled: false),
        ],
        scope: const BookSearchScope.groups(<String>{'已删除的分组'}),
      );

      expect(
        resolution.sources.map((BookSource source) => source.name),
        <String>['a'],
      );
      expect(resolution.scopeFellBack, isTrue);
    });

    test(
      'resolve_givenASourcesScopeWhereEveryUrlIsGone_fallsBackToEverything',
      () {
        // 点名的源全被删掉：范围本身已经不在了，回落与分组同一条规则（ADR-0058）。
        final SearchSourceResolution resolution = resolveSearchSources(
          rows: <StoredBookSource>[_row(name: 'a')],
          scope: const BookSearchScope.sources(<ScopeSource>[
            ScopeSource(name: 'gone', url: 'https://gone.test'),
          ]),
        );

        expect(
          resolution.sources.map((BookSource source) => source.name),
          <String>['a'],
        );
        expect(resolution.scopeFellBack, isTrue);
      },
    );

    test('resolve_givenAGroupWhoseSourcesAreAllDisabled_doesNotFallBack', () {
      // 范围还在（有行带着这个 token），只是里面没有能搜的源：如实回答「没得搜」，
      // 不得静默扩大成全库（ADR-0058）。
      final SearchSourceResolution resolution = resolveSearchSources(
        rows: <StoredBookSource>[
          _row(name: 'a', group: '精选', isEnabled: false),
          _row(name: 'b'),
        ],
        scope: const BookSearchScope.groups(<String>{'精选'}),
      );

      expect(resolution.sources, isEmpty);
      expect(resolution.scopeFellBack, isFalse);
    });

    test(
      'resolve_givenAllAndEveryRowDisabled_answersNothingWithoutFallback',
      () {
        // 「全部」不是一个会消失的范围：一条都搜不到就是如实回答，不存在回落（ADR-0058）。
        final SearchSourceResolution resolution = resolveSearchSources(
          rows: <StoredBookSource>[_row(name: 'a', isEnabled: false)],
          scope: const BookSearchScope.all(),
        );

        expect(resolution.sources, isEmpty);
        expect(resolution.scopeFellBack, isFalse);
      },
    );

    test('resolve_givenAWidenedTypeSet_keepsTheAudioSource', () {
      final SearchSourceResolution resolution = resolveSearchSources(
        rows: <StoredBookSource>[_row(name: 'a', type: BookSourceType.audio)],
        scope: const BookSearchScope.all(),
        types: const <BookSourceType>{
          BookSourceType.text,
          BookSourceType.audio,
        },
      );

      expect(resolution.sources, hasLength(1));
    });

    test('resolve_givenANamedSourceThatIsDisabled_recordsIt', () {
      final SearchSourceResolution resolution = resolveSearchSources(
        rows: <StoredBookSource>[_row(name: 'a', isEnabled: false)],
        scope: const BookSearchScope.sources(<ScopeSource>[
          ScopeSource(name: 'a', url: 'https://a.test'),
        ]),
      );

      expect(resolution.sources, isEmpty);
      expect(resolution.skipped['https://a.test'], SearchSourceSkip.disabled);
      // 用户点名的源全军覆没时也不回落：他明确说了只要这一条。
      expect(resolution.scopeFellBack, isFalse);
    });

    test('resolve_givenASourceWithoutSearchUrl_skipsIt', () {
      final SearchSourceResolution resolution = resolveSearchSources(
        rows: <StoredBookSource>[_row(name: 'a', searchUrl: '   ')],
        scope: const BookSearchScope.all(),
      );

      expect(resolution.sources, isEmpty);
      expect(
        resolution.skipped['https://a.test'],
        SearchSourceSkip.noSearchUrl,
      );
    });
  });

  group('supportsSearchPage', () {
    test('supportsSearchPage_givenAPagePlaceholder_isTrue', () {
      expect(
        supportsSearchPage('https://x.test/s?q={{key}}&p={{page}}'),
        isTrue,
      );
    });

    test('supportsSearchPage_givenAPageWordInsideAScript_isTrue', () {
      expect(
        supportsSearchPage('https://x.test/s?q={{key}}&p={{page+1}}'),
        isTrue,
      );
      expect(
        supportsSearchPage('https://x.test/s?q={{key}}@js:page+1'),
        isTrue,
      );
    });

    test('supportsSearchPage_givenAPageGroupInTheStaticUrl_isTrue', () {
      expect(
        supportsSearchPage('https://x.test/s/{{key}}/<1,2,3>.html'),
        isTrue,
      );
    });

    test(
      'supportsSearchPage_givenAScriptWordThatOnlyLooksLikePage_isFalse',
      () {
        // `pagename` 不是独立的 `page` 词：不能因为子串就声称支持翻页。
        expect(
          supportsSearchPage('https://x.test/s?q={{key}}&p={{pagename}}'),
          isFalse,
        );
      },
    );

    test('supportsSearchPage_givenNothingPageLike_isFalse', () {
      expect(supportsSearchPage('https://x.test/s?q={{key}}'), isFalse);
      expect(supportsSearchPage(null), isFalse);
      expect(supportsSearchPage('  '), isFalse);
    });
  });
}
