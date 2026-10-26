import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/presentation/pages/book_reading_records_page.dart';
import 'package:flutter_reader/features/reader/presentation/pages/bookmark_list_page.dart';
import 'package:flutter_reader/features/reader/presentation/pages/reader_page.dart';
import 'package:flutter_reader/features/reader/presentation/pages/reading_records_page.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reader_route.freezed.dart';

/// The typed routes of the reader feature (ADR-0011, ADR-0041 §决策 5, ADR-0066 §决策 7).
///
/// It lives here — not in `book_source` — because 5.3 moved the page: `book_source` and
/// `bookshelf` open the reader through this type, and the composition root owns the page table.
/// The argument is the reader's own value object, so nothing outside this feature has to expose its
/// entities to make the reader openable.
///
/// M19 added three sibling routes (bookmarks / records / one book's records) because those pages
/// belong to the same feature and a second route file would have made the page table read like two
/// features.
@freezed
sealed class ReaderRoute with _$ReaderRoute {
  const ReaderRoute._();

  /// Opens [book], at [chapterUrl] when given and at its remembered position otherwise.
  ///
  /// [charOffset] is only meaningful together with [chapterUrl]: it is how a bookmark lands on the
  /// sentence it marked instead of the chapter's first line.
  const factory ReaderRoute.read({
    required ReaderBook book,
    String? chapterUrl,
    @Default(0) int charOffset,
  }) = ReaderReadRoute;

  /// Every bookmark across books.
  const factory ReaderRoute.bookmarks() = ReaderBookmarksRoute;

  /// Every reading session, grouped by day.
  const factory ReaderRoute.records() = ReaderRecordsRoute;

  /// The reading sessions of one book.
  const factory ReaderRoute.bookRecords({
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
  }) = ReaderBookRecordsRoute;

  /// The path this route is served under.
  String get path => switch (this) {
    ReaderReadRoute() => _readerPath,
    ReaderBookmarksRoute() => _bookmarksPath,
    ReaderRecordsRoute() => _recordsPath,
    ReaderBookRecordsRoute() => _bookRecordsPath,
  };
}

/// Path of [ReaderReadRoute].
const String _readerPath = '/reader';

/// Path of [ReaderBookmarksRoute].
const String _bookmarksPath = '/reader/bookmarks';

/// Path of [ReaderRecordsRoute].
const String _recordsPath = '/reader/records';

/// Path of [ReaderBookRecordsRoute].
const String _bookRecordsPath = '/reader/records/book';

/// Pushes [route] through the app's route table (ADR-0011 §4).
void pushReaderRoute(BuildContext context, ReaderRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);

/// The page for a reader route (the composition root's page table calls this).
Widget readerPageFor(ReaderRoute route) => switch (route) {
  ReaderReadRoute(
    :final ReaderBook book,
    :final String? chapterUrl,
    :final int charOffset,
  ) =>
    ReaderPage(book: book, chapterUrl: chapterUrl, charOffset: charOffset),
  ReaderBookmarksRoute() => const BookmarkListPage(),
  ReaderRecordsRoute() => const ReadingRecordsPage(),
  ReaderBookRecordsRoute(
    :final String sourceUrl,
    :final String bookUrl,
    :final String bookName,
  ) =>
    BookReadingRecordsPage(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      bookName: bookName,
    ),
};
