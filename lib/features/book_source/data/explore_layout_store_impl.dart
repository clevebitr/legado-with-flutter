import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/explore_layout_store.dart';

/// `shared_preferences` keys of the discover layout (`docs/dev/roadmap.md` §3.12).
///
/// Keys are private to this file: the storage layout is an implementation detail, and a key
/// spelled anywhere else would be a second source for it (`docs/dev/roadmap.md` §6 #9).
const String _isGridKey = 'bookSource.exploreIsGrid';
const String _portraitColumnsKey = 'bookSource.explorePortraitColumns';
const String _landscapeColumnsKey = 'bookSource.exploreLandscapeColumns';

/// [ExploreLayoutStore] on top of [PreferenceStore] (`DECISIONS.md` #77).
final class ExploreLayoutStoreImpl implements ExploreLayoutStore {
  /// Creates the store.
  const ExploreLayoutStoreImpl({required this._store});

  final PreferenceStore _store;

  @override
  Future<ExploreLayout> load() async {
    const ExploreLayout defaults = ExploreLayout.defaults;

    return defaults.copyWith(
      isGrid: _store.readBool(_isGridKey) ?? defaults.isGrid,
      portraitColumns:
          _store.readInt(_portraitColumnsKey) ?? defaults.portraitColumns,
      landscapeColumns:
          _store.readInt(_landscapeColumnsKey) ?? defaults.landscapeColumns,
    );
  }

  @override
  Future<void> save(ExploreLayout layout) async {
    await _store.writeBool(_isGridKey, layout.isGrid);
    await _store.writeInt(_portraitColumnsKey, layout.portraitColumns);
    await _store.writeInt(_landscapeColumnsKey, layout.landscapeColumns);
  }
}
