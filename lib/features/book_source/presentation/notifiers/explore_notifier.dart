import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'explore_notifier.freezed.dart';
part 'explore_notifier.g.dart';

/// What the discover page currently shows.
///
/// A state machine rather than an `AsyncValue`, for the same reason the search form uses one:
/// “no categories” (a source without a discover page), “this category failed” and “nothing opened
/// yet” are three different screens, and they are all *successful* answers from the layers below.
@freezed
sealed class ExploreState with _$ExploreState {
  /// No categories have been read yet.
  const factory ExploreState.idle() = ExploreIdle;

  /// The source's categories are known; an empty list means it has no discover page.
  const factory ExploreState.categories(List<ExploreCategory> categories) =
      ExploreCategories;

  /// `exploreUrl` could not be read; [kind] is the message the UI shows (C-ERR-7).
  const factory ExploreState.failedCategories(ParseFailureKind kind) =
      ExploreCategoriesFailed;

  /// [category] is being opened; [categories] is the row the page keeps showing.
  const factory ExploreState.loadingBooks(
    List<ExploreCategory> categories,
    ExploreCategory category,
  ) = ExploreLoadingBooks;

  /// [category] listed [books]; an empty list means the page really had no entries.
  const factory ExploreState.books(
    List<ExploreCategory> categories,
    ExploreCategory category,
    List<Book> books,
  ) = ExploreBooksLoaded;

  /// [category] could not be read; the other categories are unaffected (`book-source.md` §9).
  const factory ExploreState.failedBooks(
    List<ExploreCategory> categories,
    ExploreCategory category,
    ParseFailureKind kind,
  ) = ExploreBooksFailed;
}

/// Drives the discover page: reads the categories once, then one category at a time.
@riverpod
class ExploreNotifier extends _$ExploreNotifier {
  /// The category row the page keeps showing while one category is open.
  ///
  /// It is held here, not in the page, so that opening a category can only change what is *below*
  /// the row: a failed category must not make the other categories disappear (`book-source.md` §9).
  List<ExploreCategory> _categories = const <ExploreCategory>[];

  @override
  ExploreState build() => const ExploreState.idle();

  /// Reads [source]'s discover categories.
  ///
  /// A collaborator that breaks its contract with an [Exception] is degraded to
  /// [ParseFailureKind.parseFailed] — with a log line that carries the source but no page content
  /// (C-ERR-8, C-SEC-4) — because a state stuck on “loading” is a hung screen with no way out.
  /// An [Error] is deliberately not caught: it is a programming mistake (ADR-0022).
  Future<void> loadCategories(BookSource source) async {
    state = const ExploreState.idle();

    try {
      final ParseResult<List<ExploreCategory>> result = await ref
          .read(fetchExploreCategoriesProvider)
          .execute(source);

      state = switch (result) {
        ParseSuccess<List<ExploreCategory>>(
          :final List<ExploreCategory> data,
        ) =>
          ExploreState.categories(_categories = data),
        ParseFailure<List<ExploreCategory>>(:final ParseFailureKind kind) =>
          ExploreState.failedCategories(kind),
      };
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error(
            'Reading the discover categories failed: source=${source.url}',
            error,
            stackTrace,
          );

      state = const ExploreState.failedCategories(ParseFailureKind.parseFailed);
    }
  }

  /// Opens [category] and publishes the books it lists.
  ///
  /// Only this category changes: a failure replaces the list with a message that keeps the chosen
  /// category visible, so the user can pick another one (`book-source.md` §9).
  Future<void> openCategory(
    BookSource source,
    ExploreCategory category, {
    int page = 1,
  }) async {
    state = ExploreState.loadingBooks(_categories, category);

    try {
      final ParseResult<List<Book>> result = await ref
          .read(exploreBooksProvider)
          .execute(source, category, page: page);

      state = switch (result) {
        ParseSuccess<List<Book>>(:final List<Book> data) => ExploreState.books(
          _categories,
          category,
          data,
        ),
        ParseFailure<List<Book>>(:final ParseFailureKind kind) =>
          ExploreState.failedBooks(_categories, category, kind),
      };
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error(
            'Opening a discover category failed: source=${source.url}',
            error,
            stackTrace,
          );

      state = ExploreState.failedBooks(
        _categories,
        category,
        ParseFailureKind.parseFailed,
      );
    }
  }
}
