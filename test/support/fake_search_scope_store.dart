import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/search_scope_store.dart';

/// In-memory [SearchScopeStore] for the search-page tests (`docs/dev/testing.md` §4).
final class FakeSearchScopeStore implements SearchScopeStore {
  /// Creates the double with [initial] scope.
  FakeSearchScopeStore({BookSearchScope? initial})
    : scope = initial ?? BookSearchScope.defaults;

  /// The stored scope, for assertions.
  BookSearchScope scope;

  @override
  Future<BookSearchScope> load() async => scope;

  @override
  Future<void> save(BookSearchScope next) async => scope = next;
}
