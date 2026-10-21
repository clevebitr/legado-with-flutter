// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'di.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the persistence of the imported book sources (`docs/dev/roadmap.md` 5.1, ADR-0040).
///
/// This is the feature's first `data/` consumer; the review note of ADR-0021 records why it
/// consumes the `domain/` model directly instead of a DTO.

@ProviderFor(bookSourceRepository)
final bookSourceRepositoryProvider = BookSourceRepositoryProvider._();

/// Provides the persistence of the imported book sources (`docs/dev/roadmap.md` 5.1, ADR-0040).
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
  /// Provides the persistence of the imported book sources (`docs/dev/roadmap.md` 5.1, ADR-0040).
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

/// Provides the import use case (pasted text or a URL, `docs/dev/roadmap.md` 5.1, ADR-0040 §决策 9).

@ProviderFor(importBookSources)
final importBookSourcesProvider = ImportBookSourcesProvider._();

/// Provides the import use case (pasted text or a URL, `docs/dev/roadmap.md` 5.1, ADR-0040 §决策 9).

final class ImportBookSourcesProvider
    extends
        $FunctionalProvider<
          ImportBookSources,
          ImportBookSources,
          ImportBookSources
        >
    with $Provider<ImportBookSources> {
  /// Provides the import use case (pasted text or a URL, `docs/dev/roadmap.md` 5.1, ADR-0040 §决策 9).
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

/// Provides the shelf writer the detail page uses (`docs/dev/roadmap.md` 5.4)。
///
/// The default is the **unbound** port: the composition root overrides it with the shelf's real
/// writer (ADR-0041 §决策 2), which is why this feature names no shelf type at all — 「加入书架」
/// 是一个端口，而不是一次 `features/bookshelf` 的 import（C-ARCH-2）。

@ProviderFor(bookshelfWriter)
final bookshelfWriterProvider = BookshelfWriterProvider._();

/// Provides the shelf writer the detail page uses (`docs/dev/roadmap.md` 5.4)。
///
/// The default is the **unbound** port: the composition root overrides it with the shelf's real
/// writer (ADR-0041 §决策 2), which is why this feature names no shelf type at all — 「加入书架」
/// 是一个端口，而不是一次 `features/bookshelf` 的 import（C-ARCH-2）。

final class BookshelfWriterProvider
    extends
        $FunctionalProvider<BookshelfWriter, BookshelfWriter, BookshelfWriter>
    with $Provider<BookshelfWriter> {
  /// Provides the shelf writer the detail page uses (`docs/dev/roadmap.md` 5.4)。
  ///
  /// The default is the **unbound** port: the composition root overrides it with the shelf's real
  /// writer (ADR-0041 §决策 2), which is why this feature names no shelf type at all — 「加入书架」
  /// 是一个端口，而不是一次 `features/bookshelf` 的 import（C-ARCH-2）。
  BookshelfWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookshelfWriterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookshelfWriterHash();

  @$internal
  @override
  $ProviderElement<BookshelfWriter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookshelfWriter create(Ref ref) {
    return bookshelfWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookshelfWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookshelfWriter>(value),
    );
  }
}

String _$bookshelfWriterHash() => r'3b48eee793c6708d8afb0bdcbeb73bbac8e71083';

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

/// Provides the chapter body cache (`docs/dev/roadmap.md` 5.2, C-NET-6).
///
/// It reuses `CacheDao`, whose first production consumer was the charset cache: the key shape and
/// the expiry column were already there, so 5.2 adds no column and no table.

@ProviderFor(contentCache)
final contentCacheProvider = ContentCacheProvider._();

/// Provides the chapter body cache (`docs/dev/roadmap.md` 5.2, C-NET-6).
///
/// It reuses `CacheDao`, whose first production consumer was the charset cache: the key shape and
/// the expiry column were already there, so 5.2 adds no column and no table.

final class ContentCacheProvider
    extends $FunctionalProvider<ContentCache, ContentCache, ContentCache>
    with $Provider<ContentCache> {
  /// Provides the chapter body cache (`docs/dev/roadmap.md` 5.2, C-NET-6).
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

/// Provides the batch check of `docs/dev/roadmap.md` §5.10.
///
/// It composes the same five use cases the pages use, so a check can never disagree with what
/// "search" or "read the body" means — the only new thing here is the order and the group
/// vocabulary (ADR-0043).

@ProviderFor(checkBookSource)
final checkBookSourceProvider = CheckBookSourceProvider._();

/// Provides the batch check of `docs/dev/roadmap.md` §5.10.
///
/// It composes the same five use cases the pages use, so a check can never disagree with what
/// "search" or "read the body" means — the only new thing here is the order and the group
/// vocabulary (ADR-0043).

final class CheckBookSourceProvider
    extends
        $FunctionalProvider<CheckBookSource, CheckBookSource, CheckBookSource>
    with $Provider<CheckBookSource> {
  /// Provides the batch check of `docs/dev/roadmap.md` §5.10.
  ///
  /// It composes the same five use cases the pages use, so a check can never disagree with what
  /// "search" or "read the body" means — the only new thing here is the order and the group
  /// vocabulary (ADR-0043).
  CheckBookSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkBookSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkBookSourceHash();

  @$internal
  @override
  $ProviderElement<CheckBookSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CheckBookSource create(Ref ref) {
    return checkBookSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CheckBookSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CheckBookSource>(value),
    );
  }
}

String _$checkBookSourceHash() => r'45cc1c9c289f7763c15ce9cecdff95ff88bc8d18';

/// Provides the single-source debug console of `docs/dev/roadmap.md` §5.10.

@ProviderFor(runSourceDebug)
final runSourceDebugProvider = RunSourceDebugProvider._();

/// Provides the single-source debug console of `docs/dev/roadmap.md` §5.10.

final class RunSourceDebugProvider
    extends $FunctionalProvider<RunSourceDebug, RunSourceDebug, RunSourceDebug>
    with $Provider<RunSourceDebug> {
  /// Provides the single-source debug console of `docs/dev/roadmap.md` §5.10.
  RunSourceDebugProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runSourceDebugProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runSourceDebugHash();

  @$internal
  @override
  $ProviderElement<RunSourceDebug> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RunSourceDebug create(Ref ref) {
    return runSourceDebug(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RunSourceDebug value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RunSourceDebug>(value),
    );
  }
}

String _$runSourceDebugHash() => r'62fea9b5a61629868734e88f23febc301eb3df3d';

/// Provides the list's own view state store (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).

@ProviderFor(bookSourceViewStore)
final bookSourceViewStoreProvider = BookSourceViewStoreProvider._();

/// Provides the list's own view state store (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).

final class BookSourceViewStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookSourceViewStore>,
          BookSourceViewStore,
          FutureOr<BookSourceViewStore>
        >
    with
        $FutureModifier<BookSourceViewStore>,
        $FutureProvider<BookSourceViewStore> {
  /// Provides the list's own view state store (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).
  BookSourceViewStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceViewStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceViewStoreHash();

  @$internal
  @override
  $FutureProviderElement<BookSourceViewStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookSourceViewStore> create(Ref ref) {
    return bookSourceViewStore(ref);
  }
}

String _$bookSourceViewStoreHash() =>
    r'ed684284448cfde53d9ac00ecd256368f3fd307d';
