import 'package:flutter_reader/features/book_source/domain/entities/book_source_list_view.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_view_store.dart';

/// In-memory [BookSourceViewStore] for the list-page tests (`docs/dev/testing.md` §4).
///
/// It keeps the value it was handed, exactly like the `shared_preferences` implementation: a test
/// that picks a sort key and then reads the store back must see that key (ADR-0045 §决策 4).
final class FakeBookSourceViewStore implements BookSourceViewStore {
  /// Creates the double with [initial] view state.
  FakeBookSourceViewStore({BookSourceListView? initial})
    : view = initial ?? BookSourceListView.defaults;

  /// The stored view state, for assertions.
  BookSourceListView view;

  /// Whether [load] throws (the page's error path).
  bool failLoads = false;

  @override
  Future<BookSourceListView> load() async {
    if (failLoads) {
      throw Exception('the view store is unavailable');
    }

    return view;
  }

  @override
  Future<void> save(BookSourceListView next) async => view = next;
}
