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

    /// Whether the source marked the chapter VIP-only (`chapter.isVip`, M25/S3b).
    ///
    /// The reader itself only needs the title and the address, but the content stage's rules read
    /// the chapter as `chapter.*` upstream, so the flags have to reach the adapter that builds them.
    @Default(false) bool isVip,

    /// Whether the source marked the chapter as bought (`chapter.isPay`).
    @Default(false) bool isPay,

    /// Whether this entry is a volume heading rather than a chapter (`chapter.isVolume`).
    @Default(false) bool isVolume,

    /// The display-only update time the source had, or `null`.
    String? updateTime,
  }) = _ReadingChapter;
}
