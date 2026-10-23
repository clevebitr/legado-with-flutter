import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';

/// The typed route of the reader feature (ADR-0011, ADR-0041 §决策 5).
///
/// It lives here — not in `book_source` — because 5.3 moved the page: `book_source` and
/// `bookshelf` open the reader through this type, and the composition root owns the page table.
/// The argument is the reader's own value object, so nothing outside this feature has to expose
/// its entities to make the reader openable.
///
/// A hand-written immutable class rather than a `freezed` union: there is exactly **one** way to
/// open the reader, and a one-variant union only adds a generated layer between the caller and the
/// two fields. `docs/dev/naming.md` §3 allows `final` fields plus `copyWith`; there is nothing to
/// copy here, so only the fields.
final class ReaderRoute {
  /// Creates the route that opens [book], at [chapterUrl] when given and at its remembered
  /// position otherwise.
  const ReaderRoute({required this.book, this.chapterUrl});

  /// The book to read.
  final ReaderBook book;

  /// The chapter to open, or `null` to resume where the reader stopped.
  final String? chapterUrl;

  /// The path this route is served under.
  String get path => _readerPath;
}

/// Path of [ReaderRoute].
const String _readerPath = '/reader';

/// Pushes [route] through the app's route table (ADR-0011 §4).
void pushReaderRoute(BuildContext context, ReaderRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);
