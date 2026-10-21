import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_list_view.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_view_store.dart';

/// `shared_preferences` key of the list's sort key.
///
/// Keys are private to this file: the storage layout is an implementation detail, and a key
/// spelled anywhere else would be a second source for it (`docs/dev/roadmap.md` §6 #9).
const String _orderKey = 'bookSource.listOrder';

/// `shared_preferences` key of the list's group filter.
const String _groupKey = 'bookSource.listGroup';

/// [BookSourceViewStore] on top of [PreferenceStore] (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).
///
/// The sort key is stored by **name** rather than index: an index would silently point at another
/// key the moment the enum grows, while an unknown name is an easy, explicit fallback.
final class BookSourceViewStoreImpl implements BookSourceViewStore {
  /// Creates the store.
  const BookSourceViewStoreImpl({required this._store});

  final PreferenceStore _store;

  @override
  Future<BookSourceListView> load() async => BookSourceListView(
    order: _orderOf(_store.readString(_orderKey)),
    group: _store.readString(_groupKey),
  );

  @override
  Future<void> save(BookSourceListView view) async {
    await _store.writeString(_orderKey, view.order.name);
    final String? group = view.group;
    if (group == null) {
      await _store.remove(_groupKey);
    } else {
      await _store.writeString(_groupKey, group);
    }
  }

  /// Maps a stored name onto [BookSourceSortOrder], defaulting when it names nothing.
  BookSourceSortOrder _orderOf(String? stored) {
    for (final BookSourceSortOrder order in BookSourceSortOrder.values) {
      if (order.name == stored) {
        return order;
      }
    }

    return BookSourceSortOrder.defaultOrder;
  }
}
