import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_book.freezed.dart';

/// One origin's snapshot of a merged hit (`docs/dev/roadmap.md` 3.12, ADR-0091 §决策 6).
///
/// A merged row is opened **through the source the user picks**, so each origin's own address and
/// display fields have to survive the merge. Before this type existed the row only kept the first
/// origin's URL, and "4 sources" therefore only ever opened one of them (`DECISIONS.md` #76).
@freezed
abstract class OriginHit with _$OriginHit {
  /// Creates one origin snapshot.
  const factory OriginHit({
    /// The `bookSourceUrl` that produced this snapshot.
    required String sourceUrl,

    /// The book's detail URL inside that source — the address a pick opens.
    required String url,

    String? author,
    String? kind,
    String? coverUrl,
    String? lastChapter,

    /// The update time as that source spelled it (display string, `book-source.md` §2).
    String? updateTime,
  }) = _OriginHit;

  /// The snapshot of [book] found by [sourceUrl].
  factory OriginHit.fromHit(Book book, {required String sourceUrl}) =>
      OriginHit(
        sourceUrl: sourceUrl,
        url: book.url,
        author: book.author,
        kind: book.kind,
        coverUrl: book.coverUrl,
        lastChapter: book.lastChapter,
        updateTime: book.updateTime,
      );
}

/// One book of an aggregate search, plus the sources that found it
/// (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 4).
///
/// The identity is `(name, author)` — that is what makes "the same book in six sources" one row
/// instead of six. [origins] are the `bookSourceUrl`s that produced it, in the order they were
/// seen; [url] belongs to the **first** origin, which is the one a plain tap opens. [hits] keeps
/// **every** origin's own snapshot, which is what the "choose a source" sheet reads.
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

    /// One snapshot per origin, in the same order as [origins] (ADR-0091 §决策 6).
    @Default(<OriginHit>[]) List<OriginHit> hits,

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
        hits: <OriginHit>[OriginHit.fromHit(book, sourceUrl: sourceUrl)],
        kind: book.kind,
        coverUrl: book.coverUrl,
        intro: book.intro,
        lastChapter: book.lastChapter,
        updateTime: book.updateTime,
      );
}

/// The de-duplication key of a [SearchBook] (ADR-0046 §决策 4, ADR-0091 §决策 6).
///
/// `(name, author)` rather than the URL: the same book in two sources has two URLs, and merging
/// those two rows is the whole point of an aggregate search. Its `url` member is the fallback for a
/// row with **no title**: before it existed every nameless hit from every source shared the key
/// `('', '')` and they merged into one nonsense row (`DECISIONS.md` #75).
typedef SearchBookKey = ({String name, String author, String url});

/// The key of [book], with a missing author normalised to an empty string.
///
/// A nameless row is keyed by its own URL instead: two nameless hits from two sources are two
/// different books, and only the title can prove otherwise.
SearchBookKey searchBookKeyOf(SearchBook book) {
  final String name = mergeKeyOf(book.name);

  return (
    name: name,
    author: mergeKeyOf(book.author ?? ''),
    url: name.isEmpty ? book.url.trim() : '',
  );
}

/// Trims and folds case, the way the merger compares names and authors.
///
/// Case folding is the only normalisation: the corpus has `剑来` and `剑 来` as different books, and
/// inventing space/pinyin rules would make two unrelated rows merge (ADR-0046 §决策 3).
String mergeKeyOf(String value) => value.trim().toLowerCase();
