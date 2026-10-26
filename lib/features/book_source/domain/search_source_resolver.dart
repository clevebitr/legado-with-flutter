import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';

/// The source types an aggregate search covers by default: text only.
///
/// The app reads text chapters, so audio / image / file sources would offer rows that
/// cannot be opened.
const Set<BookSourceType> defaultSearchSourceTypes = <BookSourceType>{
  BookSourceType.text,
};

/// Why a candidate source did not take part in a search.
enum SearchSourceSkip {
  /// The row is disabled by the user.
  disabled,

  /// The source declares no `searchUrl`, so it cannot be searched at all.
  noSearchUrl,

  /// The source's `bookSourceType` is not in the requested set.
  typeFiltered,

  /// A `sources` scope named this URL but the row is gone.
  missing,
}

/// The sources an aggregate search will run, plus the candidates it skipped.
final class SearchSourceResolution {
  /// Creates a resolution.
  const SearchSourceResolution({
    required this.sources,
    required this.skipped,
    required this.scopeFellBack,
  });

  /// The sources to search, in the order the list shows them.
  final List<BookSource> sources;

  /// Why the other candidates were left out, keyed by source URL.
  final Map<String, SearchSourceSkip> skipped;

  /// Whether the scope named something that no longer exists and fell back to "all enabled".
  final bool scopeFellBack;
}

/// Resolves [scope] over [rows] into the sources to search.
///
/// The scope selects candidates, then [types] filters them, then disabled rows and rows
/// without `searchUrl` are dropped. A scope whose names match no row at all falls back to
/// every enabled source. [rows] must already be in display order.
SearchSourceResolution resolveSearchSources({
  required List<StoredBookSource> rows,
  required BookSearchScope scope,
  Set<BookSourceType> types = defaultSearchSourceTypes,
}) {
  final List<StoredBookSource> candidates = _candidates(rows, scope);
  // 只有范围本身已不存在才回落全库；范围里没有可搜的源要如实返回空。
  final bool fellBack = candidates.isEmpty && _scopeVanished(rows, scope);
  final List<StoredBookSource> scoped = fellBack
      ? rows.where((StoredBookSource row) => row.isEnabled).toList()
      : candidates;
  final List<BookSource> sources = <BookSource>[];
  final Map<String, SearchSourceSkip> skipped = <String, SearchSourceSkip>{};
  final Set<String> named = <String>{
    for (final ScopeSource source in scope.sourcesOrEmpty) source.url,
  };

  if (scope is SearchScopeSources) {
    // 点名但已被删除的源也记下来，日志和界面才能说明它不见了。
    for (final String url in named) {
      if (!rows.any((StoredBookSource row) => row.source.url == url)) {
        skipped[url] = SearchSourceSkip.missing;
      }
    }
  }

  for (final StoredBookSource row in scoped) {
    final String url = row.source.url;
    if (!row.isEnabled) {
      skipped[url] = SearchSourceSkip.disabled;
      continue;
    }
    if (!types.contains(row.source.sourceType)) {
      skipped[url] = SearchSourceSkip.typeFiltered;
      continue;
    }
    if ((row.source.searchUrl ?? '').trim().isEmpty) {
      skipped[url] = SearchSourceSkip.noSearchUrl;
      continue;
    }
    sources.add(row.source);
  }

  return SearchSourceResolution(
    sources: sources,
    skipped: skipped,
    scopeFellBack: fellBack,
  );
}

/// The rows a [scope] selects, before the type / enablement checks.
List<StoredBookSource> _candidates(
  List<StoredBookSource> rows,
  BookSearchScope scope,
) => switch (scope) {
  // 除 `sources` 外，范围都要求源已启用。
  SearchScopeAll() =>
    rows.where((StoredBookSource row) => row.isEnabled).toList(growable: false),
  SearchScopeGroups(:final Set<String> groups) =>
    rows
        .where(
          (StoredBookSource row) =>
              row.isEnabled &&
              splitGroups(row.groupName ?? row.source.group)
                  .any(groups.contains),
        )
        .toList(growable: false),
  SearchScopeSources(:final List<ScopeSource> sources) => <StoredBookSource>[
    for (final ScopeSource named in sources)
      for (final StoredBookSource row in rows)
        if (row.source.url == named.url) row,
  ],
};

// 只看名字是否还对得上，不看启用 / 类型 / searchUrl：后者回答的是「能不能搜」，
// 不是「这个范围还在不在」。
bool _scopeVanished(List<StoredBookSource> rows, BookSearchScope scope) =>
    switch (scope) {
      // 「全部」永远不算已消失的范围。
      SearchScopeAll() => false,
      SearchScopeGroups(:final Set<String> groups) => !rows.any(
        (StoredBookSource row) =>
            splitGroups(row.groupName ?? row.source.group).any(groups.contains),
      ),
      SearchScopeSources(:final List<ScopeSource> sources) => !rows.any(
        (StoredBookSource row) =>
            sources.any((ScopeSource named) => named.url == row.source.url),
      ),
    };

/// Whether [searchUrl] declares that it can answer a page beyond the first.
///
/// It is a declaration check: a `page` word inside a script fragment, or a `<…>` page group
/// in the static URL part.
bool supportsSearchPage(String? searchUrl) {
  final String url = searchUrl ?? '';
  if (url.trim().isEmpty) {
    return false;
  }
  for (final RegExpMatch match in _scriptFragment.allMatches(url)) {
    if (_pageWord.hasMatch(match.group(0) ?? '')) {
      return true;
    }
  }

  return _pageGroup.hasMatch(url.replaceAll(_scriptFragment, ''));
}

/// `{{…}}` / `<js>…</js>` / `@js:…` fragments of a URL template.
final RegExp _scriptFragment = RegExp(
  r'\{\{[\s\S]*?\}\}|<js>[\s\S]*?</js>|@js:[\s\S]*',
  caseSensitive: false,
);

/// A standalone `page` word, not part of a longer identifier.
final RegExp _pageWord = RegExp(r'(?<![A-Za-z0-9_])page(?![A-Za-z0-9_])');

/// A `<1,2,3>`-style page group in the static URL part.
final RegExp _pageGroup = RegExp(r'<[^<>]+>');
