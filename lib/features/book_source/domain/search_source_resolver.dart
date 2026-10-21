import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';

/// The source types an aggregate search may cover (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 2).
///
/// The default is **text only**: the app reads text chapters, so pulling audio / image / file
/// sources into a search result would offer rows that cannot be opened (ADR-0046 §决策 2).
const Set<BookSourceType> defaultSearchSourceTypes = <BookSourceType>{
  BookSourceType.text,
};

/// Why a candidate source did not take part in a search, for the log and for the UI
/// (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1/2).
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

/// The result of resolving a scope into the sources an aggregate search will run
/// (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1/2).
///
/// Both halves travel together: a skipped candidate must never be silent (C-SRC-4's spirit), and the
/// search page shows how many sources were searched while the log names what was dropped and why.
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

/// Resolves [scope] over [rows] into the sources to search (`docs/dev/roadmap.md` 3.8).
///
/// The order of the checks is the point: the scope selects **candidates**, then [types] filters them,
/// then a source without `searchUrl` or a disabled one is dropped. A scope that names nothing that
/// still exists falls back to "every enabled source" — the same fallback upstream's
/// `SearchScope.getBookSourceParts` performs, so a deleted group never yields an empty search screen
/// (ADR-0046 §决策 1).
///
/// [rows] must already be in the display order (the list's sort); this function never sorts.
SearchSourceResolution resolveSearchSources({
  required List<StoredBookSource> rows,
  required BookSearchScope scope,
  Set<BookSourceType> types = defaultSearchSourceTypes,
}) {
  final List<StoredBookSource> candidates = _candidates(rows, scope);
  // 回落只在「这个范围里一条能用的都没有」时发生；`all` 本身就是全集，不需要回落。
  final bool fellBack = candidates.isEmpty && scope is! SearchScopeAll;
  final List<StoredBookSource> scoped = fellBack
      ? rows.where((StoredBookSource row) => row.isEnabled).toList()
      : candidates;
  final List<BookSource> sources = <BookSource>[];
  final Map<String, SearchSourceSkip> skipped = <String, SearchSourceSkip>{};
  final Set<String> named = <String>{
    for (final ScopeSource source in scope.sourcesOrEmpty) source.url,
  };

  if (scope is SearchScopeSources) {
    // `sources` 范围里被删掉的行：记下来，日志/界面可以说「这一条不见了」。
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
  // 其余两种范围也要求启用：禁用源永远不参与搜索（ADR-0046 §决策 1）。
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

/// Whether the source of [searchUrl] can answer a search page beyond the first
/// (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 7).
///
/// It is a **declaration check**, not a request: upstream's `supportsSearchPage()` looks for an
/// independent `page` word inside a `{{…}}` / `<js>` / `@js:` fragment, or for a `<…>` page group in
/// the static part of the URL. A source that declares neither gets skipped from page 2 on instead of
/// being asked for the same page again and reported as failing.
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

/// `{{…}}` / `<js>…</js>` / `@js:…` fragments of a URL template (`book-source.md` §4).
final RegExp _scriptFragment = RegExp(
  r'\{\{[\s\S]*?\}\}|<js>[\s\S]*?</js>|@js:[\s\S]*',
  caseSensitive: false,
);

/// A standalone `page` word, not part of a longer identifier.
final RegExp _pageWord = RegExp(r'(?<![A-Za-z0-9_])page(?![A-Za-z0-9_])');

/// A `<1,2,3>`-style page group in the static URL part.
final RegExp _pageGroup = RegExp(r'<[^<>]+>');
