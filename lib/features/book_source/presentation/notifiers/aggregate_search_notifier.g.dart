// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aggregate_search_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The stored search scope; the only place that changes it.

@ProviderFor(SearchScopeSelection)
final searchScopeSelectionProvider = SearchScopeSelectionProvider._();

/// The stored search scope; the only place that changes it.
final class SearchScopeSelectionProvider
    extends $AsyncNotifierProvider<SearchScopeSelection, BookSearchScope> {
  /// The stored search scope; the only place that changes it.
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

/// The stored search scope; the only place that changes it.

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

/// Runs the aggregate search and publishes its progress.
///
/// Kept alive so a long run survives leaving the page and coming back.

@ProviderFor(AggregateSearch)
final aggregateSearchProvider = AggregateSearchProvider._();

/// Runs the aggregate search and publishes its progress.
///
/// Kept alive so a long run survives leaving the page and coming back.
final class AggregateSearchProvider
    extends $NotifierProvider<AggregateSearch, AggregateSearchState> {
  /// Runs the aggregate search and publishes its progress.
  ///
  /// Kept alive so a long run survives leaving the page and coming back.
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

/// Runs the aggregate search and publishes its progress.
///
/// Kept alive so a long run survives leaving the page and coming back.

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
