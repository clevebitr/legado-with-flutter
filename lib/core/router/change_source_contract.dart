/// What a page hands the change-source flow when it wants the user to switch a book onto another
/// source (`docs/dev/roadmap.md` §3.12, ADR-0091).
///
/// Primitives only: the `core` port is the one place a feature may cross into another without
/// importing it (ADR-0042 §决策 2, C-ARCH-2), so the reader can offer 「换源」 without knowing that
/// the page lives in `book_source`.
final class ChangeSourceLaunch {
  /// Creates the launch data.
  const ChangeSourceLaunch({
    required this.sourceUrl,
    required this.bookUrl,
    required this.bookName,
    required this.chapterName,
    required this.chapterIndex,
    this.author,
  });

  /// The `bookSourceUrl` the book is parsed with today — the source the search excludes.
  final String sourceUrl;

  /// The book's detail URL inside [sourceUrl].
  final String bookUrl;

  /// The title used as the search keyword.
  final String bookName;

  /// The author, when the caller knows it: it is what lets a book whose title rule failed still
  /// find candidates (ADR-0091 §决策 3).
  final String? author;

  /// The chapter the reader is on — the alignment input.
  final String chapterName;

  /// That chapter's index; `-1` when the caller does not know it (the detail page).
  final int chapterIndex;
}

/// Where the reader continues after a source switch (ADR-0091, ADR-0051 §决策 3).
final class ChangeSourceOutcome {
  /// Creates the outcome.
  const ChangeSourceOutcome({
    required this.sourceUrl,
    required this.bookUrl,
    required this.tocUrl,
    required this.bookName,
    required this.chapterUrl,
    required this.chapterName,
    required this.chapterIndex,
  });

  /// The new source's URL.
  final String sourceUrl;

  /// The book's URL inside the new source — the new half of its shelf identity.
  final String bookUrl;

  /// The table-of-contents URL inside the new source.
  final String tocUrl;

  /// The title as the new source spells it.
  final String bookName;

  /// The chapter the caller should open.
  final String chapterUrl;

  /// That chapter's title.
  final String chapterName;

  /// That chapter's index in the new book.
  final int chapterIndex;
}
