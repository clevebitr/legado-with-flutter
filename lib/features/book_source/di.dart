import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/js_bridge_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
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
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_explore_categories.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/run_source_debug.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides the persistence of the imported book sources (`docs/dev/roadmap.md` 5.1, ADR-0040).
///
/// This is the feature's first `data/` consumer; the review note of ADR-0021 records why it
/// consumes the `domain/` model directly instead of a DTO.
@riverpod
BookSourceRepository bookSourceRepository(Ref ref) => BookSourceRepositoryImpl(
  dao: ref.watch(bookSourceDaoProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the import use case (pasted text or a URL, `docs/dev/roadmap.md` 5.1, ADR-0040 §决策 9).
@riverpod
ImportBookSources importBookSources(Ref ref) => ImportBookSources(
  repository: ref.watch(bookSourceRepositoryProvider),
  http: ref.watch(httpClientProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the shelf writer the detail page uses (`docs/dev/roadmap.md` 5.4)。
///
/// The default is the **unbound** port: the composition root overrides it with the shelf's real
/// writer (ADR-0041 §决策 2), which is why this feature names no shelf type at all — 「加入书架」
/// 是一个端口，而不是一次 `features/bookshelf` 的 import（C-ARCH-2）。
@riverpod
BookshelfWriter bookshelfWriter(Ref ref) =>
    UnboundBookshelfWriter(logger: ref.watch(appLoggerProvider));

/// Provides the rule engine every book source use case shares.
@riverpod
RuleEngine ruleEngine(Ref ref) => RuleEngine(
  logger: ref.watch(appLoggerProvider),
  jsBridge: ref.watch(jsBridgeProvider),
  variables: ref.watch(jsVariableStoreProvider),
);

/// Provides the page fetch + rule reading service the use cases are built on.
@riverpod
PageFetchService pageFetchService(Ref ref) => PageFetchService(
  engine: ref.watch(ruleEngineProvider),
  http: ref.watch(httpClientProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the search use case.
@riverpod
SearchBooks searchBooks(Ref ref) =>
    SearchBooks(pages: ref.watch(pageFetchServiceProvider));

/// Provides the book detail use case.
@riverpod
FetchBookInfo fetchBookInfo(Ref ref) =>
    FetchBookInfo(pages: ref.watch(pageFetchServiceProvider));

/// Provides the table of contents use case.
@riverpod
FetchToc fetchToc(Ref ref) =>
    FetchToc(pages: ref.watch(pageFetchServiceProvider));

/// Provides the chapter body cache (`docs/dev/roadmap.md` 5.2, C-NET-6).
///
/// It reuses `CacheDao`, whose first production consumer was the charset cache: the key shape and
/// the expiry column were already there, so 5.2 adds no column and no table.
@riverpod
ContentCache contentCache(Ref ref) => CacheDaoContentCache(
  ref.watch(cacheDaoProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the chapter body use case.
@riverpod
FetchContent fetchContent(Ref ref) => FetchContent(
  pages: ref.watch(pageFetchServiceProvider),
  cache: ref.watch(contentCacheProvider),
);

/// Provides the use case that reads a source's discover-page categories.
@riverpod
FetchExploreCategories fetchExploreCategories(Ref ref) =>
    FetchExploreCategories(
      engine: ref.watch(ruleEngineProvider),
      pages: ref.watch(pageFetchServiceProvider),
    );

/// Provides the use case that opens one discover-page category.
@riverpod
ExploreBooks exploreBooks(Ref ref) =>
    ExploreBooks(pages: ref.watch(pageFetchServiceProvider));

/// Provides the batch check of `docs/dev/roadmap.md` §5.10.
///
/// It composes the same five use cases the pages use, so a check can never disagree with what
/// "search" or "read the body" means — the only new thing here is the order and the group
/// vocabulary (ADR-0043).
@riverpod
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

/// Provides the single-source debug console of `docs/dev/roadmap.md` §5.10.
@riverpod
RunSourceDebug runSourceDebug(Ref ref) => RunSourceDebug(
  pages: ref.watch(pageFetchServiceProvider),
  searchBooks: ref.watch(searchBooksProvider),
  exploreBooks: ref.watch(exploreBooksProvider),
  bookInfo: ref.watch(fetchBookInfoProvider),
  toc: ref.watch(fetchTocProvider),
  content: ref.watch(fetchContentProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the list's own view state store (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).
@riverpod
Future<BookSourceViewStore> bookSourceViewStore(Ref ref) async =>
    BookSourceViewStoreImpl(
      store: await ref.watch(preferenceStoreProvider.future),
    );

/// Provides the aggregate search of `docs/dev/roadmap.md` 3.8 (ADR-0046).
@riverpod
AggregateSearchBooks aggregateSearchBooks(Ref ref) => AggregateSearchBooks(
  search: ref.watch(searchBooksProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the stored search scope (ADR-0046 §决策 1).
@riverpod
Future<SearchScopeStore> searchScopeStore(Ref ref) async =>
    SearchScopeStoreImpl(
      store: await ref.watch(preferenceStoreProvider.future),
    );
