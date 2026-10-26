/// How a restore treats what is already in the database
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 3).
enum RestoreMode {
  /// Keep everything the archive does not mention (ADR-0073 §决策 3).
  merge,

  /// Clear the seven tables first, then write the archive: 「回到备份那天」.
  ///
  /// Destructive, so the flow writes a safety copy before it starts and aborts when that copy fails.
  overwrite,
}
