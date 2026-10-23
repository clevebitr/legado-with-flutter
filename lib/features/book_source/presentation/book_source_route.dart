import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_source_route.freezed.dart';

/// The typed routes of the book source feature.
///
/// Each route carries its arguments as a value object and owns the path it is served under.
@freezed
sealed class BookSourceRoute with _$BookSourceRoute {
  const BookSourceRoute._();

  /// Shows one book's detail page and chapter list.
  const factory BookSourceRoute.bookDetail({required Book book}) =
      BookDetailRoute;

  /// Shows the source's discover page.
  const factory BookSourceRoute.explore() = ExploreRoute;

  /// Lists the imported sources.
  const factory BookSourceRoute.importedSources() = BookSourceListRoute;

  /// Imports sources from pasted text or a URL.
  const factory BookSourceRoute.importSources() = BookSourceImportRoute;

  /// Runs the batch check over the imported sources.
  ///
  /// [sourceIds] and [group] narrow the target; both `null` means every source.
  const factory BookSourceRoute.checkSources({
    Set<int>? sourceIds,
    String? group,
  }) = BookSourceCheckRoute;

  /// Opens the debug console, optionally pinned to [sourceId].
  const factory BookSourceRoute.debugSource({int? sourceId}) =
      BookSourceDebugRoute;

  /// Edits one stored source.
  const factory BookSourceRoute.editSource({required int sourceId}) =
      BookSourceEditRoute;

  /// The path this route is served under.
  String get path => switch (this) {
    ExploreRoute() => _explorePath,
    BookDetailRoute() => _bookDetailPath,
    BookSourceListRoute() => _sourceListPath,
    BookSourceImportRoute() => _sourceImportPath,
    BookSourceCheckRoute() => _sourceCheckPath,
    BookSourceDebugRoute() => _sourceDebugPath,
    BookSourceEditRoute() => _sourceEditPath,
  };
}

const String _explorePath = '/explore';

const String _bookDetailPath = '/book';

const String _sourceListPath = '/sources';

const String _sourceImportPath = '/sources/import';

const String _sourceCheckPath = '/sources/check';

const String _sourceDebugPath = '/sources/debug';

const String _sourceEditPath = '/sources/edit';

/// Pushes [route] through the app's route table.
void pushBookSourceRoute(BuildContext context, BookSourceRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);
