import 'package:flutter_reader/features/book_source/domain/repositories/explore_layout_store.dart';

/// In-memory [ExploreLayoutStore] for the discover-page tests (`docs/dev/testing.md` §4).
final class FakeExploreLayoutStore implements ExploreLayoutStore {
  /// Creates the double with [initial] layout.
  FakeExploreLayoutStore({ExploreLayout? initial})
    : layout = initial ?? ExploreLayout.defaults;

  /// The stored layout, for assertions.
  ExploreLayout layout;

  @override
  Future<ExploreLayout> load() async => layout;

  @override
  Future<void> save(ExploreLayout next) async => layout = next;
}
