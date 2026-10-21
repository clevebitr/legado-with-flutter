/// How a hit is matched against the keyword (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 3).
///
/// It is **bucket ordering, not filtering**: [defaultMode] keeps every hit and sorts the exact ones
/// first, while [exact] keeps only the hits whose name or author equals the keyword — upstream's
/// `MatchMode`, whose `EXACT` drops the `tags` / `contains` / `other` buckets.
enum SearchMatchMode {
  /// Everything the sources returned; exact name/author first, then category, then substring.
  defaultMode,

  /// Only the hits whose name or author equals the keyword.
  exact,
}
