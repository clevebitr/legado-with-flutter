import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_results_notifier.freezed.dart';
part 'search_results_notifier.g.dart';

/// What the search form currently shows.
///
/// A state machine instead of an `AsyncValue`: "nothing searched yet" and "searched,
/// no match" are both successful and empty, and the form has to tell them apart.
@freezed
sealed class SearchResultsState with _$SearchResultsState {
  /// Nothing was searched yet in this session.
  const factory SearchResultsState.idle() = SearchResultsIdle;

  /// A search is in flight.
  const factory SearchResultsState.searching() = SearchResultsSearching;

  /// The source answered with [books]; an empty list means "no match".
  const factory SearchResultsState.loaded(List<Book> books) =
      SearchResultsLoaded;

  /// The source could not be searched; [kind] is the message the UI shows (C-ERR-7).
  const factory SearchResultsState.failed(ParseFailureKind kind) =
      SearchResultsFailed;
}

/// Runs one search of the selected book source.
@riverpod
class SearchResultsNotifier extends _$SearchResultsNotifier {
  @override
  SearchResultsState build() => const SearchResultsState.idle();

  /// Searches [source] for [keyword] and publishes the outcome.
  ///
  /// The use case answers with a [ParseResult] instead of throwing (C-ERR-1), so
  /// there is no failure channel to catch here; an unexpected throw would be a
  /// programming error and is left to surface (C-ERR-2).
  Future<void> search(BookSource source, String keyword) async {
    state = const SearchResultsState.searching();

    final ParseResult<List<Book>> result = await ref
        .read(searchBooksProvider)
        .execute(source, keyword);

    state = switch (result) {
      ParseSuccess<List<Book>>(:final List<Book> data) =>
        SearchResultsState.loaded(data),
      ParseFailure<List<Book>>(:final ParseFailureKind kind) =>
        SearchResultsState.failed(kind),
    };
  }
}
