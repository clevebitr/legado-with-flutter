import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';

/// The number of characters a bookmark excerpt keeps (ADR-0066 §决策 3).
///
/// Eighty characters is one comfortable line in the bookmark list; the number lives here rather
/// than in the table definition so the pure function below and its test do not import drift.
const int bookmarkExcerptLength = 80;

/// Builds the excerpt shown for a mark at [charOffset] inside [body].
///
/// The body is the **already rendered** chapter text (paging joined, `replaceRegex` applied), so
/// this is a cheap substring and never a second request. Two details matter:
///
/// * the offset is a UTF-16 index, exactly like `ReaderSessionState.charOffset`; a slice whose
///   boundary splits a surrogate pair (an emoji, a rare CJK extension character) drops the broken
///   half instead of rendering `U+FFFD`;
/// * the result is trimmed, because a mark made on a blank paragraph should still show the next
///   words rather than eighty spaces.
String bookmarkExcerpt(
  String body,
  int charOffset, {
  int maxLength = bookmarkExcerptLength,
}) {
  if (body.isEmpty || maxLength <= 0) {
    return '';
  }
  final int start = charOffset < 0
      ? 0
      : (charOffset > body.length ? body.length : charOffset);
  final int end = start + maxLength > body.length
      ? body.length
      : start + maxLength;
  String slice = body.substring(start, end);
  if (slice.isNotEmpty && _isLowSurrogate(slice.codeUnitAt(0))) {
    slice = slice.substring(1);
  }
  if (slice.isNotEmpty &&
      _isHighSurrogate(slice.codeUnitAt(slice.length - 1))) {
    slice = slice.substring(0, slice.length - 1);
  }

  return slice.trim();
}

/// Whether [unit] is the second half of a surrogate pair.
bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// Whether [unit] is the first half of a surrogate pair.
bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

/// Whether a bookmark already sits at [charOffset] of [chapterUrl] in the book.
///
/// The reader's toolbar button is a **toggle** (ADR-0066 §决策 3): the button state and the write
/// must agree on what "already bookmarked here" means, so both ask this one function.
bool isBookmarkedAt(
  List<Bookmark> bookmarks, {
  required String chapterUrl,
  required int charOffset,
}) => bookmarks.any(
  (Bookmark bookmark) =>
      bookmark.chapterUrl == chapterUrl && bookmark.charOffset == charOffset,
);
