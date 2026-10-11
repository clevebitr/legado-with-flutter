// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';

/// One search hit of a book source (matrix #8, `docs/dev/book-source.md` §2).
///
/// These are plain domain entities: unlike the book source models they carry **no**
/// JSON annotations, because their JSON form is not part of the domain language
/// (ADR-0021 §决策 3 — the exception does not spread).
@freezed
abstract class Book with _$Book {
  /// Creates a search hit.
  ///
  /// [name] and [url] are required on the entity, but only [url] decides whether a
  /// hit survives: a hit without a usable URL is dropped with a warning instead of
  /// failing the whole search (`book-source.md` §9), while a `name` rule that matched
  /// nothing falls back to an **empty string**.
  const factory Book({
    required String name,
    required String url,
    String? author,
    String? kind,
    String? coverUrl,
    String? intro,
    String? lastChapter,
    String? wordCount,
  }) = _Book;
}

/// The detail page of one book (`ruleBookInfo`).
@freezed
abstract class BookInfo with _$BookInfo {
  /// Creates a book detail.
  ///
  /// [name] falls back to an empty string when the `name` rule matched nothing;
  /// every other field stays `null` in that case, because an absent cover or intro is
  /// not fatal (`book-source.md` §7).
  ///
  /// [tocUrl] is already resolved to an absolute URL; when the source declares no
  /// `tocUrl` rule it is the book URL itself, which is where upstream expects the
  /// chapter list to live.
  const factory BookInfo({
    required String name,
    required String url,
    required String tocUrl,
    String? author,
    String? kind,
    String? coverUrl,
    String? intro,
    String? lastChapter,
    String? wordCount,
  }) = _BookInfo;
}

/// One entry of a table of contents (`ruleToc`).
@freezed
abstract class Chapter with _$Chapter {
  /// Creates a chapter entry.
  ///
  /// [name] falls back to an empty string when the `chapterName` rule matched nothing;
  /// a chapter without a usable URL is dropped with a warning instead of failing the
  /// whole table of contents (`book-source.md` §9).
  ///
  /// [url] is already resolved to an absolute URL.
  const factory Chapter({required String name, required String url}) = _Chapter;
}
