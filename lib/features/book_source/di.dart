import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides the rule engine every book source use case shares.
@riverpod
RuleEngine ruleEngine(Ref ref) =>
    RuleEngine(logger: ref.watch(appLoggerProvider));

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
