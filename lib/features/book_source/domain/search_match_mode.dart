/// How hits are matched against the keyword: bucket ordering, not filtering.
///
/// [exact] keeps only hits whose name or author equals the keyword.
enum SearchMatchMode {
  /// Everything the sources returned; exact name/author first, then category, then substring.
  defaultMode,

  /// Only the hits whose name or author equals the keyword.
  exact,
}
