// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aggregate_search_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The stored scope and the only place that changes it (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).

@ProviderFor(SearchScopeSelection)
final searchScopeSelectionProvider = SearchScopeSelectionProvider._();

/// The stored scope and the only place that changes it (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).
final class SearchScopeSelectionProvider
    extends $AsyncNotifierProvider<SearchScopeSelection, BookSearchScope> {
  /// The stored scope and the only place that changes it (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).
  SearchScopeSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchScopeSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchScopeSelectionHash();

  @$internal
  @override
  SearchScopeSelection create() => SearchScopeSelection();
}

String _$searchScopeSelectionHash() =>
    r'5ca37913d5a246e30ab236984b94c5f8140719e1';

/// The stored scope and the only place that changes it (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).

abstract class _$SearchScopeSelection extends $AsyncNotifier<BookSearchScope> {
  FutureOr<BookSearchScope> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BookSearchScope>, BookSearchScope>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BookSearchScope>, BookSearchScope>,
              AsyncValue<BookSearchScope>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Runs the aggregate search and publishes its progress (`docs/dev/roadmap.md` 3.8).
///
/// It owns three things the domain does not:
///
/// * **the scope → sources step**: `resolveSearchSources` over the loaded rows, so the page only
///   hands in "what the list knows" and the answer is the same one the check page will use;
/// * **the pause latch and the cancellation token**: both are rebuilt per run, and pausing only
///   takes effect between sources (ADR-0046 §决策 6);
/// * **paging**: [loadMore] runs the same use case one page further and keeps the merged list, so
///   the page never merges two different result shapes itself.
///
/// It is `keepAlive`: a search of a hundred sources is minutes of work and must survive walking to a
/// book and back.

@ProviderFor(AggregateSearch)
final aggregateSearchProvider = AggregateSearchProvider._();

/// Runs the aggregate search and publishes its progress (`docs/dev/roadmap.md` 3.8).
///
/// It owns three things the domain does not:
///
/// * **the scope → sources step**: `resolveSearchSources` over the loaded rows, so the page only
///   hands in "what the list knows" and the answer is the same one the check page will use;
/// * **the pause latch and the cancellation token**: both are rebuilt per run, and pausing only
///   takes effect between sources (ADR-0046 §决策 6);
/// * **paging**: [loadMore] runs the same use case one page further and keeps the merged list, so
///   the page never merges two different result shapes itself.
///
/// It is `keepAlive`: a search of a hundred sources is minutes of work and must survive walking to a
/// book and back.
final class AggregateSearchProvider
    extends $NotifierProvider<AggregateSearch, AggregateSearchState> {
  /// Runs the aggregate search and publishes its progress (`docs/dev/roadmap.md` 3.8).
  ///
  /// It owns three things the domain does not:
  ///
  /// * **the scope → sources step**: `resolveSearchSources` over the loaded rows, so the page only
  ///   hands in "what the list knows" and the answer is the same one the check page will use;
  /// * **the pause latch and the cancellation token**: both are rebuilt per run, and pausing only
  ///   takes effect between sources (ADR-0046 §决策 6);
  /// * **paging**: [loadMore] runs the same use case one page further and keeps the merged list, so
  ///   the page never merges two different result shapes itself.
  ///
  /// It is `keepAlive`: a search of a hundred sources is minutes of work and must survive walking to a
  /// book and back.
  AggregateSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aggregateSearchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aggregateSearchHash();

  @$internal
  @override
  AggregateSearch create() => AggregateSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AggregateSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AggregateSearchState>(value),
    );
  }
}

String _$aggregateSearchHash() => r'2dea239f1ef8489e3e90c914f7fef46cea572d89';

/// Runs the aggregate search and publishes its progress (`docs/dev/roadmap.md` 3.8).
///
/// It owns three things the domain does not:
///
/// * **the scope → sources step**: `resolveSearchSources` over the loaded rows, so the page only
///   hands in "what the list knows" and the answer is the same one the check page will use;
/// * **the pause latch and the cancellation token**: both are rebuilt per run, and pausing only
///   takes effect between sources (ADR-0046 §决策 6);
/// * **paging**: [loadMore] runs the same use case one page further and keeps the merged list, so
///   the page never merges two different result shapes itself.
///
/// It is `keepAlive`: a search of a hundred sources is minutes of work and must survive walking to a
/// book and back.

abstract class _$AggregateSearch extends $Notifier<AggregateSearchState> {
  AggregateSearchState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AggregateSearchState, AggregateSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AggregateSearchState, AggregateSearchState>,
              AggregateSearchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
