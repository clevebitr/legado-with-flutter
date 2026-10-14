// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'di.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the persistence of the imported book sources (`PLAN.md` 5.1, ADR-0040).
///
/// This is the feature's first `data/` consumer; the review note of ADR-0021 records why it
/// consumes the `domain/` model directly instead of a DTO.

@ProviderFor(bookSourceRepository)
final bookSourceRepositoryProvider = BookSourceRepositoryProvider._();

/// Provides the persistence of the imported book sources (`PLAN.md` 5.1, ADR-0040).
///
/// This is the feature's first `data/` consumer; the review note of ADR-0021 records why it
/// consumes the `domain/` model directly instead of a DTO.

final class BookSourceRepositoryProvider
    extends
        $FunctionalProvider<
          BookSourceRepository,
          BookSourceRepository,
          BookSourceRepository
        >
    with $Provider<BookSourceRepository> {
  /// Provides the persistence of the imported book sources (`PLAN.md` 5.1, ADR-0040).
  ///
  /// This is the feature's first `data/` consumer; the review note of ADR-0021 records why it
  /// consumes the `domain/` model directly instead of a DTO.
  BookSourceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceRepositoryHash();

  @$internal
  @override
  $ProviderElement<BookSourceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookSourceRepository create(Ref ref) {
    return bookSourceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookSourceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookSourceRepository>(value),
    );
  }
}

String _$bookSourceRepositoryHash() =>
    r'52294acdca35c53c8abc4c34afc3628eecbe7554';

/// Provides the import use case (pasted text or a URL, `PLAN.md` 5.1, ADR-0040 §决策 9).

@ProviderFor(importBookSources)
final importBookSourcesProvider = ImportBookSourcesProvider._();

/// Provides the import use case (pasted text or a URL, `PLAN.md` 5.1, ADR-0040 §决策 9).

final class ImportBookSourcesProvider
    extends
        $FunctionalProvider<
          ImportBookSources,
          ImportBookSources,
          ImportBookSources
        >
    with $Provider<ImportBookSources> {
  /// Provides the import use case (pasted text or a URL, `PLAN.md` 5.1, ADR-0040 §决策 9).
  ImportBookSourcesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importBookSourcesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importBookSourcesHash();

  @$internal
  @override
  $ProviderElement<ImportBookSources> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImportBookSources create(Ref ref) {
    return importBookSources(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportBookSources value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportBookSources>(value),
    );
  }
}

String _$importBookSourcesHash() => r'e7e4eeefd10c4f2e40171a1809a46e56d3a6eb32';

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

String _$ruleEngineHash() => r'ca7f7326492927765c60c2210a2f972e4328d04d';

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

/// Provides the chapter body cache (`PLAN.md` 5.2, C-NET-6).
///
/// It reuses `CacheDao`, whose first production consumer was the charset cache: the key shape and
/// the expiry column were already there, so 5.2 adds no column and no table.

@ProviderFor(contentCache)
final contentCacheProvider = ContentCacheProvider._();

/// Provides the chapter body cache (`PLAN.md` 5.2, C-NET-6).
///
/// It reuses `CacheDao`, whose first production consumer was the charset cache: the key shape and
/// the expiry column were already there, so 5.2 adds no column and no table.

final class ContentCacheProvider
    extends $FunctionalProvider<ContentCache, ContentCache, ContentCache>
    with $Provider<ContentCache> {
  /// Provides the chapter body cache (`PLAN.md` 5.2, C-NET-6).
  ///
  /// It reuses `CacheDao`, whose first production consumer was the charset cache: the key shape and
  /// the expiry column were already there, so 5.2 adds no column and no table.
  ContentCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentCacheProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentCacheHash();

  @$internal
  @override
  $ProviderElement<ContentCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ContentCache create(Ref ref) {
    return contentCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContentCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContentCache>(value),
    );
  }
}

String _$contentCacheHash() => r'2f1a62a958994768b915678dbd0bc914c864b921';

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

String _$fetchContentHash() => r'f778bcebf4143d26704370a08269f10212a1c2a0';

/// Provides the use case that reads a source's discover-page categories.

@ProviderFor(fetchExploreCategories)
final fetchExploreCategoriesProvider = FetchExploreCategoriesProvider._();

/// Provides the use case that reads a source's discover-page categories.

final class FetchExploreCategoriesProvider
    extends
        $FunctionalProvider<
          FetchExploreCategories,
          FetchExploreCategories,
          FetchExploreCategories
        >
    with $Provider<FetchExploreCategories> {
  /// Provides the use case that reads a source's discover-page categories.
  FetchExploreCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fetchExploreCategoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fetchExploreCategoriesHash();

  @$internal
  @override
  $ProviderElement<FetchExploreCategories> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FetchExploreCategories create(Ref ref) {
    return fetchExploreCategories(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FetchExploreCategories value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FetchExploreCategories>(value),
    );
  }
}

String _$fetchExploreCategoriesHash() =>
    r'066872b260152d04964c630b72583af2748ce896';

/// Provides the use case that opens one discover-page category.

@ProviderFor(exploreBooks)
final exploreBooksProvider = ExploreBooksProvider._();

/// Provides the use case that opens one discover-page category.

final class ExploreBooksProvider
    extends $FunctionalProvider<ExploreBooks, ExploreBooks, ExploreBooks>
    with $Provider<ExploreBooks> {
  /// Provides the use case that opens one discover-page category.
  ExploreBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exploreBooksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exploreBooksHash();

  @$internal
  @override
  $ProviderElement<ExploreBooks> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExploreBooks create(Ref ref) {
    return exploreBooks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExploreBooks value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExploreBooks>(value),
    );
  }
}

String _$exploreBooksHash() => r'85b8bacec5fa339e01b4afc0d3e18c4fc42c9989';
