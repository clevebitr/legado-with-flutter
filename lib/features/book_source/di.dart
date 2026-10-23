import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/js_bridge_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';
import 'package:flutter_reader/features/book_source/data/book_source_repository_impl.dart';
import 'package:flutter_reader/features/book_source/data/book_source_view_store_impl.dart';
import 'package:flutter_reader/features/book_source/data/cache_dao_content_cache.dart';
import 'package:flutter_reader/features/book_source/data/search_scope_store_impl.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_view_store.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/search_scope_store.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/aggregate_search_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/check_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/explore_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_audio_tracks.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_explore_categories.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_manga_pages.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/run_source_debug.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/switch_book_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides persistence for the imported book sources.
@Riverpod(keepAlive: true)
BookSourceRepository bookSourceRepository(Ref ref) => BookSourceRepositoryImpl(
  dao: ref.watch(bookSourceDaoProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the import use case (pasted text or a URL).
@Riverpod(keepAlive: true)
ImportBookSources importBookSources(Ref ref) => ImportBookSources(
  repository: ref.watch(bookSourceRepositoryProvider),
  http: ref.watch(httpClientProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the shelf writer the detail page uses; defaults to an unbound port.
@Riverpod(keepAlive: true)
BookshelfWriter bookshelfWriter(Ref ref) =>
    UnboundBookshelfWriter(logger: ref.watch(appLoggerProvider));

/// Provides the rule engine every book source use case shares.
@Riverpod(keepAlive: true)
RuleEngine ruleEngine(Ref ref) => RuleEngine(
  logger: ref.watch(appLoggerProvider),
  jsBridge: ref.watch(jsBridgeProvider),
  variables: ref.watch(jsVariableStoreProvider),
);

/// Provides the page fetch + rule reading service the use cases are built on.
@Riverpod(keepAlive: true)
PageFetchService pageFetchService(Ref ref) => PageFetchService(
  engine: ref.watch(ruleEngineProvider),
  http: ref.watch(httpClientProvider),
  logger: ref.watch(appLoggerProvider),
  webPages: ref.watch(webPageFetcherProvider),
);

/// Provides WebView support for `,{webView:…}` rules; unsupported by default.
///
/// Kept alive because the services that watch it are kept alive too.
@Riverpod(keepAlive: true)
WebPageFetcher webPageFetcher(Ref ref) => const UnsupportedWebPageFetcher();

/// Provides the search use case.
@Riverpod(keepAlive: true)
SearchBooks searchBooks(Ref ref) =>
    SearchBooks(pages: ref.watch(pageFetchServiceProvider));

/// Provides the book detail use case.
@Riverpod(keepAlive: true)
FetchBookInfo fetchBookInfo(Ref ref) =>
    FetchBookInfo(pages: ref.watch(pageFetchServiceProvider));

/// Provides the table of contents use case.
@Riverpod(keepAlive: true)
FetchToc fetchToc(Ref ref) =>
    FetchToc(pages: ref.watch(pageFetchServiceProvider));

/// Provides the chapter body cache over the shared cache table.
@Riverpod(keepAlive: true)
ContentCache contentCache(Ref ref) => CacheDaoContentCache(
  ref.watch(cacheDaoProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the chapter body use case.
@Riverpod(keepAlive: true)
FetchContent fetchContent(Ref ref) => FetchContent(
  pages: ref.watch(pageFetchServiceProvider),
  cache: ref.watch(contentCacheProvider),
);

/// Provides the use case that reads a manga chapter's image list.
@Riverpod(keepAlive: true)
FetchMangaPages fetchMangaPages(Ref ref) => FetchMangaPages(
  pages: ref.watch(pageFetchServiceProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the audio-track reader.
@riverpod
FetchAudioTracks fetchAudioTracks(Ref ref) =>
    FetchAudioTracks(pages: ref.watch(pageFetchServiceProvider));

/// Provides the use case that reads a source's discover-page categories.
@Riverpod(keepAlive: true)
FetchExploreCategories fetchExploreCategories(Ref ref) =>
    FetchExploreCategories(
      engine: ref.watch(ruleEngineProvider),
      pages: ref.watch(pageFetchServiceProvider),
    );

/// Provides the use case that opens one discover-page category.
@Riverpod(keepAlive: true)
ExploreBooks exploreBooks(Ref ref) =>
    ExploreBooks(pages: ref.watch(pageFetchServiceProvider));

/// Provides the batch check, composed from the same use cases the pages use.
@Riverpod(keepAlive: true)
CheckBookSource checkBookSource(Ref ref) => CheckBookSource(
  searchBooks: ref.watch(searchBooksProvider),
  exploreCategories: ref.watch(fetchExploreCategoriesProvider),
  exploreBooks: ref.watch(exploreBooksProvider),
  bookInfo: ref.watch(fetchBookInfoProvider),
  toc: ref.watch(fetchTocProvider),
  content: ref.watch(fetchContentProvider),
  clock: ref.watch(clockProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the single-source debug console.
@Riverpod(keepAlive: true)
RunSourceDebug runSourceDebug(Ref ref) => RunSourceDebug(
  pages: ref.watch(pageFetchServiceProvider),
  searchBooks: ref.watch(searchBooksProvider),
  exploreBooks: ref.watch(exploreBooksProvider),
  bookInfo: ref.watch(fetchBookInfoProvider),
  toc: ref.watch(fetchTocProvider),
  content: ref.watch(fetchContentProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the source switch of the reader.
@Riverpod(keepAlive: true)
SwitchBookSource switchBookSource(Ref ref) => SwitchBookSource(
  search: ref.watch(searchBooksProvider),
  bookInfo: ref.watch(fetchBookInfoProvider),
  toc: ref.watch(fetchTocProvider),
);

/// Provides the list's view state store (sort key and group filter).
@Riverpod(keepAlive: true)
Future<BookSourceViewStore> bookSourceViewStore(Ref ref) async =>
    BookSourceViewStoreImpl(
      store: await ref.watch(preferenceStoreProvider.future),
    );

/// Provides the aggregate search.
@Riverpod(keepAlive: true)
AggregateSearchBooks aggregateSearchBooks(Ref ref) => AggregateSearchBooks(
  search: ref.watch(searchBooksProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the stored search scope.
@Riverpod(keepAlive: true)
Future<SearchScopeStore> searchScopeStore(Ref ref) async =>
    SearchScopeStoreImpl(
      store: await ref.watch(preferenceStoreProvider.future),
    );
