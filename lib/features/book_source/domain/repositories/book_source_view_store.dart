import 'package:flutter_reader/features/book_source/domain/entities/book_source_list_view.dart';

/// Remembers the list's sort key and group filter (`docs/dev/roadmap.md` 5.5, C-NET-9).
///
/// The port is **total**, like the other preference ports: a missing or unknown stored value
/// answers with the default instead of a failure, because "the list opens with the manual order and
/// every group" is exactly what a fresh install should do (ADR-0045 §决策 4).
abstract interface class BookSourceViewStore {
  /// The stored view state.
  ///
  /// The sort key is validated here (an unknown name falls back to the manual order, because the
  /// enum is the store's own vocabulary). The **group** is not: whether a group still exists
  /// depends on the rows, which the store does not see — the list drops a stale filter while it
  /// renders (ADR-0045 §决策 4) instead of writing a correction from a `build`.
  Future<BookSourceListView> load();

  /// Stores [view].
  Future<void> save(BookSourceListView view);
}
