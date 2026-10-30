import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/presentation/pages/bookshelf_page.dart';
import 'package:flutter_reader/features/bookshelf/presentation/pages/shelf_book_edit_page.dart';
import 'package:flutter_reader/features/bookshelf/presentation/pages/shelf_groups_page.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookshelf_route.freezed.dart';

/// The typed routes of the shelf feature (ADR-0011, ADR-0041 §决策 5).
///
/// Opening the shelf needs no arguments, but the route stays a typed object so the app's page
/// table keeps one shape for every pushed page (ADR-0011 §2).
@freezed
sealed class BookshelfRoute with _$BookshelfRoute {
  const BookshelfRoute._();

  /// The route that shows the shelf.
  const factory BookshelfRoute.shelf() = ShelfRoute;

  /// The route that shows the group management page (M19).
  const factory BookshelfRoute.groups() = ShelfGroupsRoute;

  /// The route that edits one shelf entry's own details (M33, ADR-0092).
  ///
  /// The whole [ShelvedBook] travels, not just its id: the editor needs the current title, author,
  /// cover and intro to seed its fields, and the shelf already has them.
  const factory BookshelfRoute.editBook({required ShelvedBook book}) =
      ShelfBookEditRoute;

  /// The path this route is served under.
  String get path => switch (this) {
    ShelfRoute() => _shelfPath,
    ShelfGroupsRoute() => _groupsPath,
    ShelfBookEditRoute() => _editPath,
  };
}

/// Path of [ShelfRoute].
const String _shelfPath = '/shelf';

/// Path of [ShelfGroupsRoute].
const String _groupsPath = '/shelf/groups';

/// Path of [ShelfBookEditRoute].
const String _editPath = '/shelf/edit';

/// The page for a shelf route (the composition root's page table calls this).
Widget bookshelfPageFor(BookshelfRoute route) => switch (route) {
  ShelfRoute() => const BookshelfPage(),
  ShelfGroupsRoute() => const ShelfGroupsPage(),
  final ShelfBookEditRoute edit => ShelfBookEditPage(book: edit.book),
};

/// Pushes [route] through the app's route table (ADR-0011 §4).
void pushBookshelfRoute(BuildContext context, BookshelfRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);
