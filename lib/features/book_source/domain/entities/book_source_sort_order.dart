/// How the book-source list is ordered (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 2).
///
/// Every key keeps the same fixed tie-breakers behind it — enabled first, then the manual order,
/// then the row id — so the same data always comes back in the same order and the list never
/// reshuffles itself between visits.
enum BookSourceSortOrder {
  /// The manual order (`customOrder`), which is also the order a drag writes.
  defaultOrder,

  /// `weight` descending: the weight the source declares, the heavier the earlier.
  weight,

  /// `respondTime` ascending: the fastest check first. A source that was never checked has no
  /// time, so it sorts **after** the measured ones instead of looking like `0 ms`.
  respondTime,

  /// The source name ascending, by code unit (no collation, no pinyin).
  name;

  /// The direction this key is first offered in (ADR-0045 §决策 2, ADR-0052 §决策 4).
  ///
  /// Weight is "the heavier the earlier", so its natural direction is descending; the other keys
  /// read naturally ascending. The view stores the **actual** direction, so this getter is only
  /// used when the user picks a key.
  bool get defaultAscending => this != BookSourceSortOrder.weight;
}
