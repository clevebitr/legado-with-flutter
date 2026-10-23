import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_search_scope.freezed.dart';

/// One named source inside a [BookSearchScope.sources] scope (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).
///
/// The name is **display only** — every match is by URL, because a source can be renamed and a
/// stored scope must survive that. The pair is kept so the search page can say what it searched
/// without reading the source table again.
@freezed
abstract class ScopeSource with _$ScopeSource {
  /// Creates one scope entry.
  const factory ScopeSource({
    /// The name the source had when the scope was picked.
    required String name,

    /// `bookSourceUrl` — the identity the scope actually uses.
    required String url,
  }) = _ScopeSource;
}

/// Which sources take part in a search (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).
///
/// Three states, like upstream's `BookSearchScope`: everything enabled, a set of group tokens, or a
/// list of named sources. The scope decides **candidates only** — the source-type filter and the
/// match mode are separate inputs of the same request.
@freezed
sealed class BookSearchScope with _$BookSearchScope {
  const BookSearchScope._();

  /// Every enabled source.
  const factory BookSearchScope.all() = SearchScopeAll;

  /// The enabled sources that carry at least one of [groups] (`bookSourceGroup` tokens).
  const factory BookSearchScope.groups(Set<String> groups) = SearchScopeGroups;

  /// The sources named by [sources]; URLs that no longer exist are dropped by the resolver.
  const factory BookSearchScope.sources(List<ScopeSource> sources) =
      SearchScopeSources;

  /// The scope an empty store means: everything enabled.
  static const BookSearchScope defaults = BookSearchScope.all();

  /// Decodes what [encode] wrote, falling back to [defaults] for anything unrecognised.
  ///
  /// The shape is upstream's (`BookSearchScope.encode*`): `{"type":"group","groups":[…]}` or
  /// `{"type":"source","sources":[{"name":…,"url":…}]}`. A malformed or unknown payload is **not**
  /// an error — a scope is a preference, and the list of "what to search" must survive a hand-edited
  /// store (ADR-0046 §决策 1).
  factory BookSearchScope.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (decoded is! Map<String, Object?>) {
      return defaults;
    }

    return switch (decoded['type']) {
      'group' => BookSearchScope.groups(<String>{
        for (final Object? group in _list(decoded['groups']))
          if (group is String && group.trim().isNotEmpty) group.trim(),
      }),
      'source' => BookSearchScope.sources(<ScopeSource>[
        for (final Object? entry in _list(decoded['sources']))
          if (entry is Map<String, Object?> &&
              entry['url'] is String &&
              (entry['url']! as String).trim().isNotEmpty)
            ScopeSource(
              name: entry['name'] is String ? entry['name']! as String : '',
              url: (entry['url']! as String).trim(),
            ),
      ]),
      _ => defaults,
    };
  }

  /// The payload [BookSearchScope.decode] reads back; `null` for [SearchScopeAll].
  String? encode() => switch (this) {
    SearchScopeAll() => null,
    SearchScopeGroups(:final Set<String> groups) => jsonEncode(
      <String, Object?>{
        'type': 'group',
        'groups': groups.toList(growable: false)..sort(),
      },
    ),
    SearchScopeSources(:final List<ScopeSource> sources) => jsonEncode(
      <String, Object?>{
        'type': 'source',
        'sources': <Map<String, Object?>>[
          for (final ScopeSource source in sources)
            <String, Object?>{'name': source.name, 'url': source.url},
        ],
      },
    ),
  };

  /// The groups a [SearchScopeGroups] scope names, or an empty set for the other two states.
  Set<String> get groupsOrEmpty => switch (this) {
    SearchScopeGroups(:final Set<String> groups) => groups,
    SearchScopeAll() || SearchScopeSources() => const <String>{},
  };

  /// The sources a [SearchScopeSources] scope names, or an empty list for the other two states.
  List<ScopeSource> get sourcesOrEmpty => switch (this) {
    SearchScopeSources(:final List<ScopeSource> sources) => sources,
    SearchScopeAll() || SearchScopeGroups() => const <ScopeSource>[],
  };
}

/// Reads a JSON list, or an empty one when the value is not a list.
List<Object?> _list(Object? value) => value is List<Object?> ? value : const [];
