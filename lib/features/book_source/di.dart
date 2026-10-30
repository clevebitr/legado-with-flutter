import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/js_bridge_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/features/book_source/data/book_source_repository_impl.dart';
import 'package:flutter_reader/features/book_source/data/book_source_view_store_impl.dart';
import 'package:flutter_reader/features/book_source/data/cache_dao_content_cache.dart';
import 'package:flutter_reader/features/book_source/data/explore_layout_store_impl.dart';
import 'package:flutter_reader/features/book_source/data/search_scope_store_impl.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_reader/features/book_source/domain/content_purifier.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/purge_rules_port.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_view_store.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/explore_layout_store.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/search_scope_store.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/aggregate_search_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/change_source_search.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/check_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/explore_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/export_book_sources.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_audio_tracks.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_explore_categories.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_manga_pages.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/resolve_login_form.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/run_source_debug.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/sign_in.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/switch_book_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides persistence for the imported book sources.
@Riverpod(keepAlive: true)
BookSourceRepository bookSourceRepository(Ref ref) => BookSourceRepositoryImpl(
  dao: ref.watch(bookSourceDaoProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the `loginUi` form resolver (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
@Riverpod(keepAlive: true)
ResolveLoginForm resolveLoginForm(Ref ref) => ResolveLoginForm(
  js: ref.watch(jsBridgeProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the sign-in runner (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
@Riverpod(keepAlive: true)
SignIn signIn(Ref ref) => SignIn(
  js: ref.watch(jsBridgeProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the book-source export (`docs/dev/roadmap.md` 5.8, ADR-0071 §决策 3).
@Riverpod(keepAlive: true)
ExportBookSources exportBookSources(Ref ref) =>
    ExportBookSources(repository: ref.watch(bookSourceRepositoryProvider));

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
  // 每源持久变量（`source.getVariable`，ADR-0076 §决策 1）：引擎只负责把快照下发，
  // 写穿由桥做（它拿到 job 的结果）。
  sourceVariables: ref.watch(sourceVariableStoreProvider),
  // 书源自带的 JS 库（ADR-0078 S1）：规则执行前解析成可运行的脚本。
  jsLib: ref.watch(jsLibStoreProvider),
);

/// Provides the page fetch + rule reading service the use cases are built on.
@Riverpod(keepAlive: true)
PageFetchService pageFetchService(Ref ref) => PageFetchService(
  engine: ref.watch(ruleEngineProvider),
  http: ref.watch(httpClientProvider),
  logger: ref.watch(appLoggerProvider),
  webPages: ref.watch(webPageFetcherProvider),
  // 登录头（`source.putLoginHeader`，M25/S3b）：与桥看到的是同一个 store，所以登录脚本写下的
  // 头会在下一阶段的每个请求上生效。
  loginHeaders: ref.watch(sourceLoginHeaderStoreProvider),
);

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
  purifier: ref.watch(contentPurifierProvider),
);

/// Provides the purge-rule source, **unbound** by default.
///
/// The composition root overrides it with the rules feature's repository (ADR-0041 §决策 2), so
/// reading never imports `features/rules`. The default purges nothing.
@Riverpod(keepAlive: true)
PurgeRuleSource purgeRuleSource(Ref ref) =>
    UnboundPurgeRuleSource(logger: ref.watch(appLoggerProvider));

/// Provides the purifier the chapter body goes through after the source's `replaceRegex`.
///
/// It carries the JS sandbox because a purge rule's replacement may be a `@js:` script
/// (`docs/dev/roadmap.md` M23, ADR-0071 §决策 5); one job per rule per chapter.
@Riverpod(keepAlive: true)
ContentPurifier contentPurifier(Ref ref) => ContentPurifier(
  rules: ref.watch(purgeRuleSourceProvider),
  logger: ref.watch(appLoggerProvider),
  js: ref.watch(jsBridgeProvider),
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

/// Provides the candidate search of a source switch (ADR-0091).
///
/// It is its own provider because the switch page (M30) drives it directly: the progress
/// callbacks, the pause latch and the cancellation belong to that page, while the one-shot
/// [switchBookSourceProvider] keeps answering the reader's port.
@Riverpod(keepAlive: true)
ChangeSourceSearch changeSourceSearch(Ref ref) => ChangeSourceSearch(
  search: ref.watch(searchBooksProvider),
  bookInfo: ref.watch(fetchBookInfoProvider),
  toc: ref.watch(fetchTocProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the source switch: the last, pure step of the change-source flow (ADR-0091).
@Riverpod(keepAlive: true)
SwitchBookSource switchBookSource(Ref ref) => const SwitchBookSource();

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

/// Provides the stored discover layout (`DECISIONS.md` #77).
@Riverpod(keepAlive: true)
Future<ExploreLayoutStore> exploreLayoutStore(Ref ref) async =>
    ExploreLayoutStoreImpl(
      store: await ref.watch(preferenceStoreProvider.future),
    );

/// Provides the stored change-source scope (ADR-0091 §决策 5).
///
/// Same codec, different key: switching a book and searching the library are separate intents.
@Riverpod(keepAlive: true)
Future<SearchScopeStore> changeSourceScopeStore(Ref ref) async =>
    SearchScopeStoreImpl(
      store: await ref.watch(preferenceStoreProvider.future),
      key: changeSourceScopeKey,
    );
