import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_source_route.freezed.dart';

/// The typed routes of the book source feature (ADR-0011).
///
/// A route carries its arguments as a `freezed` value object and owns the path the
/// app's route table serves, so a page pushes a route instead of naming a next hop:
/// `pushBookSourceRoute(context, BookSourceRoute.bookDetail(book: book))`.
@freezed
sealed class BookSourceRoute with _$BookSourceRoute {
  const BookSourceRoute._();

  /// The route that shows one book's detail page and chapter list.
  const factory BookSourceRoute.bookDetail({required Book book}) =
      BookDetailRoute;

  /// The route that shows the source's discover page.
  const factory BookSourceRoute.explore() = ExploreRoute;

  /// The route that lists the imported sources (`docs/dev/roadmap.md` 5.1).
  const factory BookSourceRoute.importedSources() = BookSourceListRoute;

  /// The route that imports sources from pasted text or a URL (`docs/dev/roadmap.md` 5.1).
  const factory BookSourceRoute.importSources() = BookSourceImportRoute;

  /// The route that shows the text of one chapter.
  const factory BookSourceRoute.reader({required Chapter chapter}) =
      ReaderRoute;

  /// The route that runs the batch check over the imported sources (`docs/dev/roadmap.md` 5.10).
  const factory BookSourceRoute.checkSources() = BookSourceCheckRoute;

  /// The route that opens the debug console, optionally pinned to [sourceId]
  /// (`docs/dev/roadmap.md` 5.10).
  const factory BookSourceRoute.debugSource({int? sourceId}) =
      BookSourceDebugRoute;

  /// The path this route is served under.
  String get path => switch (this) {
    ExploreRoute() => _explorePath,
    BookDetailRoute() => _bookDetailPath,
    ReaderRoute() => _readerPath,
    BookSourceListRoute() => _sourceListPath,
    BookSourceImportRoute() => _sourceImportPath,
    BookSourceCheckRoute() => _sourceCheckPath,
    BookSourceDebugRoute() => _sourceDebugPath,
  };
}

/// Path of [ExploreRoute].
const String _explorePath = '/explore';

/// Path of [BookDetailRoute].
const String _bookDetailPath = '/book';

/// Path of [ReaderRoute].
const String _readerPath = '/reader';

/// Path of [BookSourceListRoute].
const String _sourceListPath = '/sources';

/// Path of [BookSourceImportRoute].
const String _sourceImportPath = '/sources/import';

/// Path of [BookSourceCheckRoute].
const String _sourceCheckPath = '/sources/check';

/// Path of [BookSourceDebugRoute].
const String _sourceDebugPath = '/sources/debug';

/// Pushes [route] through the app's route table (ADR-0011 §4).
void pushBookSourceRoute(BuildContext context, BookSourceRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);
