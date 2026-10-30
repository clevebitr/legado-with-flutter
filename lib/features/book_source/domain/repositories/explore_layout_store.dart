import 'package:flutter/material.dart' show Orientation;

/// How many columns one orientation may show. Upstream clamps its slider to 1–10
/// (`ExploreShowScreen.kt`'s `SaveGridCount`), and 10 covers a desktop window.
const int minExploreGridColumns = 1;

/// The upper bound of the discover page's grid; see [minExploreGridColumns].
const int maxExploreGridColumns = 10;

/// The discover page's layout: a list or a grid, with one column count per orientation
/// (`docs/dev/roadmap.md` §3.12, `DECISIONS.md` #77).
///
/// Two counts rather than one because a phone in portrait and the same phone in landscape need
/// different grids, and upstream remembers the two separately.
final class ExploreLayout {
  /// Creates a layout.
  const ExploreLayout({
    required this.isGrid,
    required this.portraitColumns,
    required this.landscapeColumns,
  });

  /// The layout a fresh install starts with: a list.
  static const ExploreLayout defaults = ExploreLayout(
    isGrid: false,
    portraitColumns: 3,
    landscapeColumns: 7,
  );

  /// Whether the books are drawn as a grid.
  final bool isGrid;

  /// Grid columns in portrait; always within the bounds.
  final int portraitColumns;

  /// Grid columns in landscape; always within the bounds.
  final int landscapeColumns;

  /// The column count for [orientation].
  int columnsFor(Orientation orientation) =>
      orientation == Orientation.portrait ? portraitColumns : landscapeColumns;

  /// This layout with the given fields replaced, clamped into the allowed range.
  ///
  /// Clamping lives here rather than in the store: release builds have no asserts, so a stored
  /// `0` would otherwise make `GridView` throw (the same reason `ReaderSettings` clamps its axes).
  ExploreLayout copyWith({
    bool? isGrid,
    int? portraitColumns,
    int? landscapeColumns,
  }) => ExploreLayout(
    isGrid: isGrid ?? this.isGrid,
    portraitColumns: _clamp(portraitColumns ?? this.portraitColumns),
    landscapeColumns: _clamp(landscapeColumns ?? this.landscapeColumns),
  );

  static int _clamp(int value) =>
      value.clamp(minExploreGridColumns, maxExploreGridColumns);
}

/// Remembers the discover page's layout (`DECISIONS.md` #77).
///
/// Total like the other preference ports: a missing or hand-edited value answers
/// [ExploreLayout.defaults] instead of a failure — a layout is a preference, not data.
abstract interface class ExploreLayoutStore {
  /// The stored layout, already clamped.
  Future<ExploreLayout> load();

  /// Stores [layout].
  Future<void> save(ExploreLayout layout);
}
