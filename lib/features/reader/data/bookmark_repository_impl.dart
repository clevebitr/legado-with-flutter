import 'package:flutter_reader/core/storage/bookmark_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:flutter_reader/features/reader/domain/repositories/bookmark_repository.dart';

/// Drift-backed [BookmarkRepository] (`docs/dev/roadmap.md` M19).
///
/// It owns the decision the DAO must not make: the toolbar button is a **toggle**, and "already
/// bookmarked here" means the unique position key `(sourceUrl, bookUrl, chapterUrl, charOffset)`
/// (ADR-0066 §决策 3). Checking and writing in one method keeps the button and the stored row from
/// disagreeing — the table's unique key would turn a double add into an exception.
final class BookmarkRepositoryImpl implements BookmarkRepository {
  /// Creates the repository.
  const BookmarkRepositoryImpl(this._dao);

  final BookmarkDao _dao;

  @override
  Future<List<Bookmark>> getAll() async =>
      (await _dao.findAll()).map(_toBookmark).toList();

  @override
  Future<List<Bookmark>> getForBook({
    required String sourceUrl,
    required String bookUrl,
  }) async => (await _dao.findForBook(
    sourceUrl: sourceUrl,
    bookUrl: bookUrl,
  )).map(_toBookmark).toList();

  @override
  Future<bool> toggle(BookmarkDraft draft) async {
    final BookmarkRow? existing = await _dao.findAt(
      sourceUrl: draft.sourceUrl,
      bookUrl: draft.bookUrl,
      chapterUrl: draft.chapterUrl,
      charOffset: draft.charOffset,
    );
    if (existing != null) {
      await _dao.deleteById(existing.id);

      return false;
    }

    await _dao.insertNew(
      sourceUrl: draft.sourceUrl,
      bookUrl: draft.bookUrl,
      bookName: draft.bookName,
      tocUrl: draft.tocUrl,
      chapterUrl: draft.chapterUrl,
      chapterName: draft.chapterName,
      chapterIndex: draft.chapterIndex,
      charOffset: draft.charOffset,
      excerpt: draft.excerpt,
    );

    return true;
  }

  @override
  Future<void> remove(int id) async {
    await _dao.deleteById(id);
  }

  /// Maps one row to the reader's value object.
  Bookmark _toBookmark(BookmarkRow row) => Bookmark(
    id: row.id,
    sourceUrl: row.sourceUrl,
    bookUrl: row.bookUrl,
    bookName: row.bookName,
    tocUrl: row.tocUrl,
    chapterUrl: row.chapterUrl,
    chapterName: row.chapterName,
    chapterIndex: row.chapterIndex,
    charOffset: row.charOffset,
    excerpt: row.excerpt,
    createdAt: row.createdAt,
  );
}
