import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';

/// Remembers the aggregate search's scope (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).
///
/// The port is total like the other preference ports: a missing or hand-edited value answers with
/// [BookSearchScope.defaults] instead of a failure — "search everything enabled" is what a fresh
/// install should do, and a scope is a preference, not data.
abstract interface class SearchScopeStore {
  /// The stored scope, already decoded.
  Future<BookSearchScope> load();

  /// Stores [scope]; [BookSearchScope.all] clears the key instead of writing "all".
  Future<void> save(BookSearchScope scope);
}
