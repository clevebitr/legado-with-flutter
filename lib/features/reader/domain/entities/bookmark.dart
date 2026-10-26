// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookmark.freezed.dart';

/// One bookmark: a position in one chapter of one book (`docs/dev/roadmap.md` M19).
///
/// The reader owns this type; the table is `core/storage/bookmarks.dart` (ADR-0066 §决策 3).
/// `bookName` / `chapterName` are snapshots so the global list renders without the shelf or the
/// network, and [chapterIndex] is a convenience that may be stale after a source renumbers its
/// chapters — the jump path finds the chapter by [chapterUrl] first.
@freezed
abstract class Bookmark with _$Bookmark {
  /// Creates a bookmark.
  const factory Bookmark({
    required int id,
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    String? tocUrl,
    required String chapterUrl,
    String? chapterName,
    @Default(0) int chapterIndex,
    @Default(0) int charOffset,
    String? excerpt,
    required DateTime createdAt,
  }) = _Bookmark;
}

/// What the reader hands the store when the user marks a position.
///
/// It is separate from [Bookmark] because the id and the creation time are the store's
/// (`BookmarkDao`'s injected clock), and a draft that carried them would let one caller lie about
/// when a mark was made.
@freezed
abstract class BookmarkDraft with _$BookmarkDraft {
  /// Creates a bookmark draft.
  const factory BookmarkDraft({
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    String? tocUrl,
    required String chapterUrl,
    String? chapterName,
    @Default(0) int chapterIndex,
    @Default(0) int charOffset,
    String? excerpt,
  }) = _BookmarkDraft;
}
