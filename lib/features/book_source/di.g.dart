// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'di.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the rule engine every book source use case shares.

@ProviderFor(ruleEngine)
final ruleEngineProvider = RuleEngineProvider._();

/// Provides the rule engine every book source use case shares.

final class RuleEngineProvider
    extends $FunctionalProvider<RuleEngine, RuleEngine, RuleEngine>
    with $Provider<RuleEngine> {
  /// Provides the rule engine every book source use case shares.
  RuleEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ruleEngineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ruleEngineHash();

  @$internal
  @override
  $ProviderElement<RuleEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RuleEngine create(Ref ref) {
    return ruleEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RuleEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RuleEngine>(value),
    );
  }
}

String _$ruleEngineHash() => r'279fe28b7f360ede253cdb4ccdf08b388def2590';

/// Provides the page fetch + rule reading service the use cases are built on.

@ProviderFor(pageFetchService)
final pageFetchServiceProvider = PageFetchServiceProvider._();

/// Provides the page fetch + rule reading service the use cases are built on.

final class PageFetchServiceProvider
    extends
        $FunctionalProvider<
          PageFetchService,
          PageFetchService,
          PageFetchService
        >
    with $Provider<PageFetchService> {
  /// Provides the page fetch + rule reading service the use cases are built on.
  PageFetchServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pageFetchServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pageFetchServiceHash();

  @$internal
  @override
  $ProviderElement<PageFetchService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PageFetchService create(Ref ref) {
    return pageFetchService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PageFetchService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PageFetchService>(value),
    );
  }
}

String _$pageFetchServiceHash() => r'4b4736bb50ab5cb4aacc106f78e388157905a807';

/// Provides the search use case.

@ProviderFor(searchBooks)
final searchBooksProvider = SearchBooksProvider._();

/// Provides the search use case.

final class SearchBooksProvider
    extends $FunctionalProvider<SearchBooks, SearchBooks, SearchBooks>
    with $Provider<SearchBooks> {
  /// Provides the search use case.
  SearchBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchBooksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchBooksHash();

  @$internal
  @override
  $ProviderElement<SearchBooks> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SearchBooks create(Ref ref) {
    return searchBooks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchBooks value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchBooks>(value),
    );
  }
}

String _$searchBooksHash() => r'f4cdc87cec7d35a85234d6f93bfc160dc3f57931';

/// Provides the book detail use case.

@ProviderFor(fetchBookInfo)
final fetchBookInfoProvider = FetchBookInfoProvider._();

/// Provides the book detail use case.

final class FetchBookInfoProvider
    extends $FunctionalProvider<FetchBookInfo, FetchBookInfo, FetchBookInfo>
    with $Provider<FetchBookInfo> {
  /// Provides the book detail use case.
  FetchBookInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fetchBookInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fetchBookInfoHash();

  @$internal
  @override
  $ProviderElement<FetchBookInfo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FetchBookInfo create(Ref ref) {
    return fetchBookInfo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FetchBookInfo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FetchBookInfo>(value),
    );
  }
}

String _$fetchBookInfoHash() => r'605262c76e564274f7e44ba29b976bbeee8cf599';

/// Provides the table of contents use case.

@ProviderFor(fetchToc)
final fetchTocProvider = FetchTocProvider._();

/// Provides the table of contents use case.

final class FetchTocProvider
    extends $FunctionalProvider<FetchToc, FetchToc, FetchToc>
    with $Provider<FetchToc> {
  /// Provides the table of contents use case.
  FetchTocProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fetchTocProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fetchTocHash();

  @$internal
  @override
  $ProviderElement<FetchToc> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FetchToc create(Ref ref) {
    return fetchToc(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FetchToc value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FetchToc>(value),
    );
  }
}

String _$fetchTocHash() => r'8335386d48a19a74d44d8ce23c0940adc791c7e1';

/// Provides the chapter body use case.

@ProviderFor(fetchContent)
final fetchContentProvider = FetchContentProvider._();

/// Provides the chapter body use case.

final class FetchContentProvider
    extends $FunctionalProvider<FetchContent, FetchContent, FetchContent>
    with $Provider<FetchContent> {
  /// Provides the chapter body use case.
  FetchContentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fetchContentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fetchContentHash();

  @$internal
  @override
  $ProviderElement<FetchContent> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FetchContent create(Ref ref) {
    return fetchContent(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FetchContent value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FetchContent>(value),
    );
  }
}

String _$fetchContentHash() => r'4a48d6dd089853876a732c1e83fc2b61f1a34f56';
