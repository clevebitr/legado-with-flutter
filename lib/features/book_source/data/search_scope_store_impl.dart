import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/search_scope_store.dart';

/// `shared_preferences` key of the aggregate search scope (`docs/dev/roadmap.md` 3.8).
///
/// Keys are private to this file: the storage layout is an implementation detail, and a key
/// spelled anywhere else would be a second source for it (`docs/dev/roadmap.md` §6 #9).
const String _scopeKey = 'bookSource.searchScope';

/// [SearchScopeStore] on top of [PreferenceStore] (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).
///
/// The payload is the same JSON shape upstream writes (`{"type":"group",…}` / `{"type":"source",…}`),
/// so the codec lives on the entity and this class only moves bytes.
final class SearchScopeStoreImpl implements SearchScopeStore {
  /// Creates the store.
  const SearchScopeStoreImpl({required this._store});

  final PreferenceStore _store;

  @override
  Future<BookSearchScope> load() async =>
      BookSearchScope.decode(_store.readString(_scopeKey));

  @override
  Future<void> save(BookSearchScope scope) async {
    final String? encoded = scope.encode();
    if (encoded == null) {
      // `all` 就是「没有范围」：删键比存一个标记更不会过期。
      await _store.remove(_scopeKey);

      return;
    }
    await _store.writeString(_scopeKey, encoded);
  }
}
