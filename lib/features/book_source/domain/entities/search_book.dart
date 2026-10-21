import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_book.freezed.dart';

/// One book of an aggregate search, plus the sources that found it
/// (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 4).
///
/// The identity is `(name, author)` — that is what makes "the same book in six sources" one row
/// instead of six. [origins] are the `bookSourceUrl`s that produced it, in the order they were
/// seen; [url] belongs to the **first** origin, which is the one the row opens.
@freezed
abstract class SearchBook with _$SearchBook {
  /// Creates a merged hit.
  const factory SearchBook({
    /// The title as the first origin spelled it.
    required String name,

    /// The author as the first origin spelled it; `null` when the rule matched nothing.
    String? author,

    /// The detail URL of the first origin.
    required String url,

    /// The `bookSourceUrl`s that found this book, de-duplicated, in discovery order.
    @Default(<String>[]) List<String> origins,

    /// The category as the first origin spelled it.
    String? kind,

    /// The cover URL as the first origin spelled it.
    String? coverUrl,

    /// The introduction as the first origin spelled it.
    String? intro,

    /// The latest chapter as the first origin spelled it.
    String? lastChapter,

    /// The update time as the first origin spelled it (display string, `book-source.md` §2).
    String? updateTime,
  }) = _SearchBook;

  /// The book [book] as a single-origin hit from [sourceUrl].
  factory SearchBook.fromHit(Book book, {required String sourceUrl}) =>
      SearchBook(
        name: book.name,
        author: book.author,
        url: book.url,
        origins: <String>[sourceUrl],
        kind: book.kind,
        coverUrl: book.coverUrl,
        intro: book.intro,
        lastChapter: book.lastChapter,
        updateTime: book.updateTime,
      );
}

/// The de-duplication key of a [SearchBook] (ADR-0046 §决策 4).
///
/// `(name, author)` rather than the URL: the same book in two sources has two URLs, and merging
/// those two rows is the whole point of an aggregate search.
typedef SearchBookKey = ({String name, String author});

/// The key of [book], with a missing author normalised to an empty string.
SearchBookKey searchBookKeyOf(SearchBook book) =>
    (name: mergeKeyOf(book.name), author: mergeKeyOf(book.author ?? ''));

/// Trims and folds case, the way the merger compares names and authors.
///
/// Case folding is the only normalisation: the corpus has `剑来` and `剑 来` as different books, and
/// inventing space/pinyin rules would make two unrelated rows merge (ADR-0046 §决策 3).
String mergeKeyOf(String value) => value.trim().toLowerCase();
