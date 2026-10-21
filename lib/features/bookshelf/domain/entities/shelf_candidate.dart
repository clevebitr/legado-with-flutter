/// What the shelf needs to know about a book to put it there.
///
/// It is deliberately a value object of the **shelf's own** domain rather than a `Book` or a
/// `BookInfo`: those belong to `book_source`, and a feature may not import another feature's
/// entities (C-ARCH-2). The composition root maps one to the other when it binds
/// `BookshelfWriter` (ADR-0041 §决策 3).
final class ShelfCandidate {
  /// Creates a candidate.
  ///
  /// [sourceUrl] and [bookUrl] are the entry's identity, so an empty one is a programming
  /// error, not a recoverable failure (C-ERR-1): the caller always has both — the source it
  /// searched with and the detail URL the hit carried.
  ShelfCandidate({
    required this.sourceUrl,
    required this.bookUrl,
    required this.name,
    this.author,
    this.kind,
    this.coverUrl,
    this.intro,
    this.lastChapter,
  }) {
    if (sourceUrl.isEmpty) {
      throw ArgumentError.value(sourceUrl, 'sourceUrl', 'must not be empty');
    }
    if (bookUrl.isEmpty) {
      throw ArgumentError.value(bookUrl, 'bookUrl', 'must not be empty');
    }
  }

  /// `bookSourceUrl` of the source the book was found through.
  final String sourceUrl;

  /// The book's detail page URL — its identity inside one source.
  final String bookUrl;

  /// The title to show on the shelf.
  final String name;

  /// The author, when the rule matched.
  final String? author;

  /// The category, when the rule matched.
  final String? kind;

  /// The cover URL, when the source declared it.
  final String? coverUrl;

  /// The introduction, when the source declared it.
  final String? intro;

  /// The latest chapter, when the source declared it.
  final String? lastChapter;
}
