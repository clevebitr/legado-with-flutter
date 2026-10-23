import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter_request.freezed.dart';

/// What one chapter-body fetch knows about the book and the chapter
/// (`docs/dev/book-source.md` §6, ADR-0049).
///
/// It exists because a `@js:` rule may read two **built-in** values upstream intercepts before
/// its variable lookup — `java.get('bookName')` and `java.get('title')` (`AnalyzeRule.get`,
/// `AnalyzeRule.kt:812-821`) — and only the caller knows them: the engine sees a URL.
///
/// `bookName` and `title` are therefore **context**, not rules: they travel into the
/// page's `JsPageContext` and from there onto every job the page produces. Both may be empty (a
/// debug console that only has a URL), in which case the read falls through to the source's
/// variables.
@freezed
abstract class ChapterRequest with _$ChapterRequest {
  /// Creates a chapter request.
  const factory ChapterRequest({
    /// The chapter page URL — the same value that used to be the whole argument.
    required String url,

    /// The chapter title, when the caller knows it (`java.get('title')`).
    @Default('') String title,

    /// The book title, when the caller knows it (`java.get('bookName')`).
    @Default('') String bookName,

    /// The book's detail URL, when the caller knows it (`book.bookUrl`, ADR-0060 P2).
    @Default('') String bookUrl,

    /// The book's table-of-contents URL (`book.tocUrl`, ADR-0060 P2).
    @Default('') String tocUrl,

    /// The author, when the caller knows it (`book.author`, ADR-0060 P2).
    @Default('') String author,

    /// The category, when the caller knows it (`book.kind`, ADR-0060 P2).
    @Default('') String kind,

    /// The introduction, when the caller knows it (`book.intro`, ADR-0060 P2).
    @Default('') String intro,
  }) = _ChapterRequest;
}
