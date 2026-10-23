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
        isAutoDispose: false,
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
    r'3ecd37d01f723401a48df8ed049d7f0bb3d20900';

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
        isAutoDispose: false,
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

String _$importBookSourcesHash() => r'df8a22019b3996ae60946c6ccb241c8f33e1756e';

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
        isAutoDispose: false,
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

String _$bookshelfWriterHash() => r'e16cb76446a358f2d2ffca62d6fa0820fcc26815';

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
        isAutoDispose: false,
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

String _$ruleEngineHash() => r'efef60215a5a91151b038adb01a6dfcab6ba7f60';

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
        isAutoDispose: false,
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

String _$pageFetchServiceHash() => r'468d712869d464c9328f014cebea12126c981668';

/// Provides the WebView capability for `,{webView:…}` rules (ADR-0056).
///
/// The default is unsupported; the composition root binds `InAppWebViewPageFetcher`, so host
/// tests keep using the plain HTTP path and a platform without WebView2 degrades instead of
/// failing the source.

@ProviderFor(webPageFetcher)
final webPageFetcherProvider = WebPageFetcherProvider._();

/// Provides the WebView capability for `,{webView:…}` rules (ADR-0056).
///
/// The default is unsupported; the composition root binds `InAppWebViewPageFetcher`, so host
/// tests keep using the plain HTTP path and a platform without WebView2 degrades instead of
/// failing the source.

final class WebPageFetcherProvider
    extends $FunctionalProvider<WebPageFetcher, WebPageFetcher, WebPageFetcher>
    with $Provider<WebPageFetcher> {
  /// Provides the WebView capability for `,{webView:…}` rules (ADR-0056).
  ///
  /// The default is unsupported; the composition root binds `InAppWebViewPageFetcher`, so host
  /// tests keep using the plain HTTP path and a platform without WebView2 degrades instead of
  /// failing the source.
  WebPageFetcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webPageFetcherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webPageFetcherHash();

  @$internal
  @override
  $ProviderElement<WebPageFetcher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WebPageFetcher create(Ref ref) {
    return webPageFetcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebPageFetcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebPageFetcher>(value),
    );
  }
}

String _$webPageFetcherHash() => r'4be83e008ee67f3bbf57ec2c27db20cbc8490129';

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
        isAutoDispose: false,
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

String _$searchBooksHash() => r'6d7cbf5b3183d483361c7bf200494aaf0eebe805';

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
        isAutoDispose: false,
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

String _$fetchBookInfoHash() => r'e1d6e447dd0b7856306d39f542b7e472b31a73ba';

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
        isAutoDispose: false,
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

String _$fetchTocHash() => r'd725d39896df190f4073285f957df865f3acf86e';

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
        isAutoDispose: false,
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

String _$contentCacheHash() => r'5e08d495d2c3fe5ee30bffb08be83d8f66cd34c9';

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
        isAutoDispose: false,
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

String _$fetchContentHash() => r'ff2400b9199601c795ec64f858569ad2bb2ec8af';

/// Provides the use case that reads a manga chapter's image list
/// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053).

@ProviderFor(fetchMangaPages)
final fetchMangaPagesProvider = FetchMangaPagesProvider._();

/// Provides the use case that reads a manga chapter's image list
/// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053).

final class FetchMangaPagesProvider
    extends
        $FunctionalProvider<FetchMangaPages, FetchMangaPages, FetchMangaPages>
    with $Provider<FetchMangaPages> {
  /// Provides the use case that reads a manga chapter's image list
  /// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053).
  FetchMangaPagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fetchMangaPagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fetchMangaPagesHash();

  @$internal
  @override
  $ProviderElement<FetchMangaPages> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FetchMangaPages create(Ref ref) {
    return fetchMangaPages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FetchMangaPages value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FetchMangaPages>(value),
    );
  }
}

String _$fetchMangaPagesHash() => r'e6f3da185aacb0be6493fb63af1e906fb74a9609';

/// Provides the audio-track reader (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 2).

@ProviderFor(fetchAudioTracks)
final fetchAudioTracksProvider = FetchAudioTracksProvider._();

/// Provides the audio-track reader (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 2).

final class FetchAudioTracksProvider
    extends
        $FunctionalProvider<
          FetchAudioTracks,
          FetchAudioTracks,
          FetchAudioTracks
        >
    with $Provider<FetchAudioTracks> {
  /// Provides the audio-track reader (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 2).
  FetchAudioTracksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fetchAudioTracksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fetchAudioTracksHash();

  @$internal
  @override
  $ProviderElement<FetchAudioTracks> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FetchAudioTracks create(Ref ref) {
    return fetchAudioTracks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FetchAudioTracks value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FetchAudioTracks>(value),
    );
  }
}

String _$fetchAudioTracksHash() => r'76f5df3129241d5ddc03e924e7ea6e437280f7be';

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
        isAutoDispose: false,
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
    r'e652fb14178db5c4d49c29b7cd844fe9a0c25d2e';

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
        isAutoDispose: false,
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

String _$exploreBooksHash() => r'928c380bf90c3f429c82108f9953173894512931';

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
        isAutoDispose: false,
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

String _$checkBookSourceHash() => r'ab69116e6f88a184bb4f4b8ef353c2b95c9d62ed';

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
        isAutoDispose: false,
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

String _$runSourceDebugHash() => r'f8316970316911069d632a7f15cae460d02865ed';

/// Provides the source switch of the reader (`docs/dev/roadmap.md` §3.9-R3, ADR-0051).

@ProviderFor(switchBookSource)
final switchBookSourceProvider = SwitchBookSourceProvider._();

/// Provides the source switch of the reader (`docs/dev/roadmap.md` §3.9-R3, ADR-0051).

final class SwitchBookSourceProvider
    extends
        $FunctionalProvider<
          SwitchBookSource,
          SwitchBookSource,
          SwitchBookSource
        >
    with $Provider<SwitchBookSource> {
  /// Provides the source switch of the reader (`docs/dev/roadmap.md` §3.9-R3, ADR-0051).
  SwitchBookSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'switchBookSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$switchBookSourceHash();

  @$internal
  @override
  $ProviderElement<SwitchBookSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SwitchBookSource create(Ref ref) {
    return switchBookSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SwitchBookSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SwitchBookSource>(value),
    );
  }
}

String _$switchBookSourceHash() => r'bebcfcdb713f5f02695867ce8f9b4547ae7a1058';

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
        isAutoDispose: false,
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
    r'2b592e47dbd9797292135d1f24ec8df01d570519';

/// Provides the aggregate search of `docs/dev/roadmap.md` 3.8 (ADR-0046).

@ProviderFor(aggregateSearchBooks)
final aggregateSearchBooksProvider = AggregateSearchBooksProvider._();

/// Provides the aggregate search of `docs/dev/roadmap.md` 3.8 (ADR-0046).

final class AggregateSearchBooksProvider
    extends
        $FunctionalProvider<
          AggregateSearchBooks,
          AggregateSearchBooks,
          AggregateSearchBooks
        >
    with $Provider<AggregateSearchBooks> {
  /// Provides the aggregate search of `docs/dev/roadmap.md` 3.8 (ADR-0046).
  AggregateSearchBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aggregateSearchBooksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aggregateSearchBooksHash();

  @$internal
  @override
  $ProviderElement<AggregateSearchBooks> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AggregateSearchBooks create(Ref ref) {
    return aggregateSearchBooks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AggregateSearchBooks value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AggregateSearchBooks>(value),
    );
  }
}

String _$aggregateSearchBooksHash() =>
    r'6b6c637600f3cc09acdf5d63f9613523622699ce';

/// Provides the stored search scope (ADR-0046 §决策 1).

@ProviderFor(searchScopeStore)
final searchScopeStoreProvider = SearchScopeStoreProvider._();

/// Provides the stored search scope (ADR-0046 §决策 1).

final class SearchScopeStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<SearchScopeStore>,
          SearchScopeStore,
          FutureOr<SearchScopeStore>
        >
    with $FutureModifier<SearchScopeStore>, $FutureProvider<SearchScopeStore> {
  /// Provides the stored search scope (ADR-0046 §决策 1).
  SearchScopeStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchScopeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchScopeStoreHash();

  @$internal
  @override
  $FutureProviderElement<SearchScopeStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SearchScopeStore> create(Ref ref) {
    return searchScopeStore(ref);
  }
}

String _$searchScopeStoreHash() => r'40f0f99208f634a20ee3ee7b02b540e4c5fbf18e';
