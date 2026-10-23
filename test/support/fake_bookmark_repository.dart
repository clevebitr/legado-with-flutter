import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:flutter_reader/features/reader/domain/repositories/bookmark_repository.dart';

/// In-memory [BookmarkRepository] for the reader tests (`docs/dev/testing.md` §4).
///
/// It mirrors the one rule the real implementation owns — the position is the identity, so
/// toggling twice removes — and records every call, which is what the reader page's tests assert
/// on instead of reading a database.
final class FakeBookmarkRepository implements BookmarkRepository {
  /// The stored bookmarks, oldest first.
  final List<Bookmark> bookmarks = <Bookmark>[];

  /// Every draft handed to [toggle], in order.
  final List<BookmarkDraft> toggles = <BookmarkDraft>[];

  /// Every id handed to [remove], in order.
  final List<int> removed = <int>[];

  /// When set, every write throws it (an unexpected storage failure).
  Exception? writeFailure;

  /// The id the next inserted bookmark gets.
  int _nextId = 1;

  /// The creation time the next inserted bookmark gets.
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  Future<List<Bookmark>> getAll() async =>
      List<Bookmark>.unmodifiable(bookmarks);

  @override
  Future<List<Bookmark>> getForBook({
    required String sourceUrl,
    required String bookUrl,
  }) async => bookmarks
      .where(
        (Bookmark bookmark) =>
            bookmark.sourceUrl == sourceUrl && bookmark.bookUrl == bookUrl,
      )
      .toList();

  @override
  Future<bool> toggle(BookmarkDraft draft) async {
    toggles.add(draft);
    final Exception? failure = writeFailure;
    if (failure != null) {
      throw failure;
    }
    final int existing = bookmarks.indexWhere(
      (Bookmark bookmark) =>
          bookmark.sourceUrl == draft.sourceUrl &&
          bookmark.bookUrl == draft.bookUrl &&
          bookmark.chapterUrl == draft.chapterUrl &&
          bookmark.charOffset == draft.charOffset,
    );
    if (existing >= 0) {
      bookmarks.removeAt(existing);

      return false;
    }
    bookmarks.add(
      Bookmark(
        id: _nextId++,
        sourceUrl: draft.sourceUrl,
        bookUrl: draft.bookUrl,
        bookName: draft.bookName,
        tocUrl: draft.tocUrl,
        chapterUrl: draft.chapterUrl,
        chapterName: draft.chapterName,
        chapterIndex: draft.chapterIndex,
        charOffset: draft.charOffset,
        excerpt: draft.excerpt,
        createdAt: createdAt,
      ),
    );

    return true;
  }

  @override
  Future<void> remove(int id) async {
    removed.add(id);
    final Exception? failure = writeFailure;
    if (failure != null) {
      throw failure;
    }
    bookmarks.removeWhere((Bookmark bookmark) => bookmark.id == id);
  }
}
