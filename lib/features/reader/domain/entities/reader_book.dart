// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reader_book.freezed.dart';

/// What the reader needs to know about a book to open it (`docs/dev/roadmap.md` 5.3).
///
/// Primitives only, on purpose: the reader is reached from `book_source` (a search hit or a
/// detail page) and from `bookshelf` (a shelf row), and neither of those features' entities may
/// cross the boundary (C-ARCH-2). The composition root builds this value where it knows both
/// sides (ADR-0041 §决策 3).
///
/// [tocUrl] is where the chapter list lives. The shelf stores it (`books.tocUrl`, ADR-0044
/// §决策 3); a caller that does not have one passes [bookUrl], which is what `BookInfo.tocUrl`
/// falls back to as well.
@freezed
abstract class ReaderBook with _$ReaderBook {
  /// Creates the entry the reader opens.
  const factory ReaderBook({
    /// `bookSourceUrl` of the source the book came from.
    required String sourceUrl,

    /// The book's detail page URL — its identity inside [sourceUrl].
    required String bookUrl,

    /// The title to show while reading.
    required String name,

    /// The table-of-contents URL; the book page itself when the source declares no `tocUrl` rule.
    required String tocUrl,
  }) = _ReaderBook;
}
