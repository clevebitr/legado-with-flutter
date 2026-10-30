import 'package:flutter/material.dart' show Orientation;
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/explore_layout_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'explore_layout_notifier.g.dart';

/// The discover page's layout, and the only place that changes it
/// (`docs/dev/roadmap.md` §3.12, `DECISIONS.md` #77).
@Riverpod(keepAlive: true)
class ExploreLayoutController extends _$ExploreLayoutController {
  @override
  Future<ExploreLayout> build() async =>
      (await ref.watch(exploreLayoutStoreProvider.future)).load();

  /// Switches between the list and the grid.
  Future<void> toggle() async {
    final ExploreLayout current = await _current;

    return _save(current.copyWith(isGrid: !current.isGrid));
  }

  /// Sets the grid column count of [orientation].
  Future<void> setColumns(Orientation orientation, int columns) async {
    final ExploreLayout current = await _current;

    return _save(
      orientation == Orientation.portrait
          ? current.copyWith(portraitColumns: columns)
          : current.copyWith(landscapeColumns: columns),
    );
  }

  /// The current layout; a store that has not answered yet means the stored one.
  Future<ExploreLayout> get _current async =>
      state.value ?? (await ref.read(exploreLayoutStoreProvider.future)).load();

  /// Writes [layout] through the store and publishes it.
  Future<void> _save(ExploreLayout layout) async {
    await (await ref.read(exploreLayoutStoreProvider.future)).save(layout);
    state = AsyncData<ExploreLayout>(layout);
  }
}
