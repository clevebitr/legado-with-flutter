import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/js_bridge_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/features/book_source/data/book_source_repository_impl.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/explore_books.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_explore_categories.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides the persistence of the imported book sources (`PLAN.md` 5.1, ADR-0040).
///
/// This is the feature's first `data/` consumer; the review note of ADR-0021 records why it
/// consumes the `domain/` model directly instead of a DTO.
@riverpod
BookSourceRepository bookSourceRepository(Ref ref) => BookSourceRepositoryImpl(
  dao: ref.watch(bookSourceDaoProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the import use case (pasted text or a URL, `PLAN.md` 5.1, ADR-0040 §决策 9).
@riverpod
ImportBookSources importBookSources(Ref ref) => ImportBookSources(
  repository: ref.watch(bookSourceRepositoryProvider),
  http: ref.watch(httpClientProvider),
  logger: ref.watch(appLoggerProvider),
);

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

/// Provides the chapter body use case.
@riverpod
FetchContent fetchContent(Ref ref) =>
    FetchContent(pages: ref.watch(pageFetchServiceProvider));

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
