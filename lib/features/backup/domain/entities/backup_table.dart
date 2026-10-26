/// One JSON file inside a backup archive (`docs/dev/roadmap.md` M22, ADR-0073 §决策 2).
///
/// The order of the values is the order the files are written in; the restore does not depend on it.
enum BackupTable {
  /// `book_sources` — payload plus the user state that hangs off it.
  bookSources('bookSources.json'),

  /// `books` — the shelf, with the group as a name.
  books('books.json'),

  /// `reading_progress` — where the reader stopped in each book.
  readingProgress('readingProgress.json'),

  /// `book_groups` — the shelf groups.
  bookGroups('bookGroups.json'),

  /// `bookmarks`.
  bookmarks('bookmarks.json'),

  /// `read_records` — the reading sessions.
  readRecords('readRecords.json'),

  /// `rules` — the four rule kinds, distinguished by `kind`.
  rules('rules.json');

  const BackupTable(this.fileName);

  /// The file name inside the archive.
  final String fileName;
}
