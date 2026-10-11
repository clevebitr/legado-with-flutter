import 'package:flutter_reader/core/di/logger_provider.dart';
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
  /// The use case answers with a [ParseResult] instead of throwing (C-ERR-1), so a
  /// normal failure is a value that needs no catch. A collaborator that breaks that
  /// contract with an [Exception] is still degraded to
  /// [ParseFailureKind.parseFailed] — with a log line that carries the source, never
  /// the keyword (C-ERR-8) — because the alternative, a state stuck in
  /// [SearchResultsSearching], is a hung screen with no way out.
  ///
  /// An [Error] is **not** caught: `avoid_catching_errors` is error-level (C-ERR-2)
  /// because it means a programming mistake that has to be fixed rather than handled
  /// here. That case leaves the state loading while the error surfaces in the logs,
  /// which is the signal to fix it.
  Future<void> search(BookSource source, String keyword) async {
    state = const SearchResultsState.searching();

    try {
      final ParseResult<List<Book>> result = await ref
          .read(searchBooksProvider)
          .execute(source, keyword);

      state = switch (result) {
        ParseSuccess<List<Book>>(:final List<Book> data) =>
          SearchResultsState.loaded(data),
        ParseFailure<List<Book>>(:final ParseFailureKind kind) =>
          SearchResultsState.failed(kind),
      };
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error(
            'Book source search failed: source=${source.url}',
            error,
            stackTrace,
          );

      state = const SearchResultsState.failed(ParseFailureKind.parseFailed);
    }
  }
}
