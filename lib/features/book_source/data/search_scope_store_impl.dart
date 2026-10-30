import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/search_scope_store.dart';

/// `shared_preferences` key of the aggregate search scope (`docs/dev/roadmap.md` 3.8).
///
/// Keys are private to this file: the storage layout is an implementation detail, and a key
/// spelled anywhere else would be a second source for it (`docs/dev/roadmap.md` §6 #9).
const String defaultSearchScopeKey = 'bookSource.searchScope';

/// Key of the **change-source** scope (ADR-0091 §决策 5).
///
/// Separate from [defaultSearchScopeKey] on purpose: «search the whole library» and «switch this
/// book using the groups I trust» are different intents, and one preference must not overwrite the
/// other.
const String changeSourceScopeKey = 'bookSource.changeSourceScope';

/// [SearchScopeStore] on top of [PreferenceStore] (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 1).
///
/// The payload is the same JSON shape upstream writes (`{"type":"group",…}` / `{"type":"source",…}`),
/// so the codec lives on the entity and this class only moves bytes. `key` picks which stored
/// scope this instance answers (ADR-0091 §决策 5).
final class SearchScopeStoreImpl implements SearchScopeStore {
  /// Creates the store for `key`.
  const SearchScopeStoreImpl({
    required this._store,
    this._key = defaultSearchScopeKey,
  });

  final PreferenceStore _store;
  final String _key;

  @override
  Future<BookSearchScope> load() async =>
      BookSearchScope.decode(_store.readString(_key));

  @override
  Future<void> save(BookSearchScope scope) async {
    final String? encoded = scope.encode();
    if (encoded == null) {
      // `all` 就是「没有范围」：删键比存一个标记更不会过期。
      await _store.remove(_key);

      return;
    }
    await _store.writeString(_key, encoded);
  }
}
