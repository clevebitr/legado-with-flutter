// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_results_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs one search of the selected book source.

@ProviderFor(SearchResultsNotifier)
final searchResultsProvider = SearchResultsNotifierProvider._();

/// Runs one search of the selected book source.
final class SearchResultsNotifierProvider
    extends $NotifierProvider<SearchResultsNotifier, SearchResultsState> {
  /// Runs one search of the selected book source.
  SearchResultsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchResultsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchResultsNotifierHash();

  @$internal
  @override
  SearchResultsNotifier create() => SearchResultsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchResultsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchResultsState>(value),
    );
  }
}

String _$searchResultsNotifierHash() =>
    r'1dc569802730a7a3d245fef4f2efad93941ccb0c';

/// Runs one search of the selected book source.

abstract class _$SearchResultsNotifier extends $Notifier<SearchResultsState> {
  SearchResultsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SearchResultsState, SearchResultsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SearchResultsState, SearchResultsState>,
              SearchResultsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
