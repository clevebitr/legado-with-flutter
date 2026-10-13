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

  /// The route that shows the text of one chapter.
  const factory BookSourceRoute.reader({required Chapter chapter}) =
      ReaderRoute;

  /// The path this route is served under.
  String get path => switch (this) {
    ExploreRoute() => _explorePath,
    BookDetailRoute() => _bookDetailPath,
    ReaderRoute() => _readerPath,
  };
}

/// Path of [ExploreRoute].
const String _explorePath = '/explore';

/// Path of [BookDetailRoute].
const String _bookDetailPath = '/book';

/// Path of [ReaderRoute].
const String _readerPath = '/reader';

/// Pushes [route] through the app's route table (ADR-0011 §4).
void pushBookSourceRoute(BuildContext context, BookSourceRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);
