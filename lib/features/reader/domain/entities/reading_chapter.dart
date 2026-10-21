// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_chapter.freezed.dart';

/// One entry of a book's table of contents, as the **reader** sees it
/// (`docs/dev/roadmap.md` 5.3, ADR-0041 §决策 3).
///
/// It is deliberately not `book_source.Chapter`: a feature may not import another feature's
/// entities (C-ARCH-2), and the reader needs less — a title to show and an address to fetch.
/// `isVip` / `updateTime` stay with `book_source`; the composition root maps one to the other.
@freezed
abstract class ReadingChapter with _$ReadingChapter {
  /// Creates one reader-facing chapter.
  const factory ReadingChapter({
    /// The title as the source spelled it; may be empty when the rule matched nothing.
    required String title,

    /// The absolute chapter URL.
    required String url,
  }) = _ReadingChapter;
}
