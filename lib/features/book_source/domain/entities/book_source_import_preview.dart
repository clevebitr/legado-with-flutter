/// Why one imported entry cannot be stored (`docs/dev/roadmap.md` §3.10 V5).
///
/// The reasons are the ones `ImportBookSources` already used when it skipped an entry silently:
/// the preview turns them into something the user can see and, where possible, fix in the file
/// (ADR-0052 §决策 5). They are **not** a second failure model — the file-level failures still
/// travel as `ParseResult`.
enum BookSourceImportRejection {
  /// `bookSourceUrl` is missing or blank.
  missingUrl,

  /// `bookSourceName` is missing or blank.
  missingName,

  /// A required rule object or another structural field could not be read (ADR-0022 checked mode).
  unreadable,

  /// The entry is not a JSON object at all.
  notAnObject,
}

/// One entry of an import file, as the preview shows it (`docs/dev/roadmap.md` §3.10 V5).
///
/// [entry] is the **raw JSON object** the import would store (already sanitised), so committing a
/// subset hands `saveAll` exactly the bytes that were previewed (ADR-0040 §决策 4). [isRefresh] is a
/// prediction made against the stored identities; the store decides again when the entry lands.
final class BookSourceImportEntry {
  /// Creates one previewed entry.
  const BookSourceImportEntry({
    required this.index,
    required this.entry,
    required this.isRefresh,
    required this.rejection,
    this.name,
    this.url,
    this.group,
  });

  /// The entry's position in the file, so the UI can name an entry that has no name.
  final int index;

  /// The raw object to store, or an empty map when [rejection] is set.
  final Map<String, Object?> entry;

  /// Whether the stored sources already contain this identity (a re-import refreshes it).
  final bool isRefresh;

  /// Why this entry cannot be stored, or `null` when it can.
  final BookSourceImportRejection? rejection;

  /// `bookSourceName` when it is readable.
  final String? name;

  /// `bookSourceUrl` when it is readable.
  final String? url;

  /// `bookSourceGroup` when it is readable.
  final String? group;

  /// Whether the entry can be committed.
  bool get isUsable => rejection == null;
}

/// What one import file contains, before anything is written (`docs/dev/roadmap.md` §3.10 V5).
///
/// The preview is a **pure value**: it never writes, which is what lets the page tick entries and
/// commit a subset (ADR-0052 §决策 5). The counts are derived, not stored, so they cannot disagree
/// with [entries].
final class BookSourceImportPreview {
  /// Creates a preview.
  const BookSourceImportPreview({required this.entries});

  /// One entry per element of the file, in file order (rejected ones included).
  final List<BookSourceImportEntry> entries;

  /// How many entries can be stored.
  int get usableCount =>
      entries.where((BookSourceImportEntry e) => e.isUsable).length;

  /// How many entries are rejected, i.e. what the import reports as `skipped`.
  int get rejectedCount => entries.length - usableCount;

  /// How many usable entries are new identities.
  int get newCount => entries
      .where((BookSourceImportEntry e) => e.isUsable && !e.isRefresh)
      .length;

  /// How many usable entries would refresh an existing row.
  int get refreshCount => entries
      .where((BookSourceImportEntry e) => e.isUsable && e.isRefresh)
      .length;
}

/// Reads the fields the preview shows from one raw entry, leaving unreadable ones `null`.
///
/// A function rather than a method on the preview so the use case keeps the "what is a valid
/// entry" decision in one place (`_missingRequiredField` / `_sanitise`) and this only projects.
({String? name, String? url, String? group}) previewFieldsOf(
  Map<String, Object?> entry,
) {
  final Object? name = entry['bookSourceName'];
  final Object? url = entry['bookSourceUrl'];
  final Object? group = entry['bookSourceGroup'];

  return (
    name: name is String && name.trim().isNotEmpty ? name : null,
    url: url is String && url.trim().isNotEmpty ? url : null,
    group: group is String && group.trim().isNotEmpty ? group : null,
  );
}
