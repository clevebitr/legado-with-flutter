import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';

/// What the detail page hands to the shelf when the user adds a book (`docs/dev/roadmap.md` 5.4).
///
/// Primitives only: the shelf is another feature, so this port may not name `Book` or `BookInfo`
/// (C-ARCH-2). The mapping `BookInfo` → draft happens in `book_source`; the root then maps the
/// draft onto the shelf's own `ShelfCandidate` (ADR-0041 §决策 3).
final class ShelfBookDraft {
  /// Creates a draft.
  ///
  /// An empty [sourceUrl] or [bookUrl] is a programming error, not a recoverable failure
  /// (C-ERR-1): both come from entities that already required them.
  ShelfBookDraft({
    required this.sourceUrl,
    required this.bookUrl,
    required this.name,
    this.tocUrl,
    this.canReName = false,
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

  /// The book's detail page URL.
  final String bookUrl;

  /// The table-of-contents URL the detail stage resolved, so the shelf can open the reader
  /// without guessing the address (`docs/dev/roadmap.md` 5.3, ADR-0044 §决策 3).
  final String? tocUrl;

  /// Whether the source declares `ruleBookInfo.canReName`, i.e. whether an existing shelf entry's
  /// title and author may be overwritten (`book-source.md` §2, ADR-0044 §决策 5).
  final bool canReName;

  /// The title to show on the shelf.
  final String name;

  /// The author, when the detail page carried one.
  final String? author;

  /// The category, when the detail page carried one.
  final String? kind;

  /// The cover URL, when the detail page carried one.
  final String? coverUrl;

  /// The introduction, when the detail page carried one.
  final String? intro;

  /// The latest chapter, when the detail page carried one.
  final String? lastChapter;
}

/// The one shelf capability `book_source` needs: putting a book on the shelf (ADR-0041 §决策 2).
///
/// The port is declared by the **consumer** and bound by the composition root, so `book_source`
/// never imports the shelf feature. It answers [ParseResult] rather than throwing, because a
/// failure here is an ordinary outcome the page shows, not a crash.
abstract interface class BookshelfWriter {
  /// Puts [draft] on the shelf, or refreshes the stored entry when it is already there.
  Future<ParseResult<void>> addToShelf(ShelfBookDraft draft);
}

/// The answer when nothing bound [BookshelfWriter]: an observable failure, never a throw.
///
/// This is the default of `bookshelfWriterProvider`, so a forgotten binding in the composition
/// root shows up as a failure message plus one warning line instead of an exception in the UI
/// (ADR-0041 §决策 2). Its `rulePath` is pinned by a test, which is what keeps the failure
/// locatable (C-SRC-8).
final class UnboundBookshelfWriter implements BookshelfWriter {
  /// Creates the unbound port; `_logger` receives the warning.
  const UnboundBookshelfWriter({required this._logger});

  final AppLogger _logger;

  @override
  Future<ParseResult<void>> addToShelf(ShelfBookDraft draft) async {
    _logger.warning(
      'No BookshelfWriter is bound: the add-to-shelf action did nothing.',
    );

    return const ParseFailure<void>(
      kind: ParseFailureKind.unsupportedRule,
      rulePath: 'shelf.writer',
    );
  }
}
