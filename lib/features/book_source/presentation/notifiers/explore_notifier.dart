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
/// The state machine keeps "empty", "failed" and "not opened yet" distinguishable.
@freezed
sealed class ExploreState with _$ExploreState {
  /// No categories have been read yet.
  const factory ExploreState.idle() = ExploreIdle;

  /// The source's categories are known; an empty list means it has no discover page.
  const factory ExploreState.categories(List<ExploreCategory> categories) =
      ExploreCategories;

  /// `exploreUrl` could not be read; [kind] is the message the UI shows.
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

  /// [category] could not be read; the other categories are unaffected.
  const factory ExploreState.failedBooks(
    List<ExploreCategory> categories,
    ExploreCategory category,
    ParseFailureKind kind,
  ) = ExploreBooksFailed;
}

/// Drives the discover page: reads the categories once, then one category at a time.
@riverpod
class ExploreNotifier extends _$ExploreNotifier {
  // 分类行保存在这里，打开分类失败时整行不会消失。
  List<ExploreCategory> _categories = const <ExploreCategory>[];

  @override
  ExploreState build() => const ExploreState.idle();

  /// Reads [source]'s discover categories.
  ///
  /// Unexpected exceptions degrade to a failed state; [Error]s are not caught.
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
