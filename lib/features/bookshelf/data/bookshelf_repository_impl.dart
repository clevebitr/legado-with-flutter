import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/domain/repositories/bookshelf_repository.dart';

/// Drift-backed [BookshelfRepository] (`docs/dev/roadmap.md` 5.4).
///
/// It owns the one business decision the DAO must not make: what "already on the shelf" means
/// (`(sourceUrl, bookUrl)`) and therefore whether an add is an insert or a refresh. Everything
/// else — the row shape, the ordering, the transaction around delete — stays in the DAO.
final class BookshelfRepositoryImpl implements BookshelfRepository {
  /// Creates the repository.
  const BookshelfRepositoryImpl({required this._dao});

  final BookshelfDao _dao;

  @override
  Future<List<ShelvedBook>> getAll() async {
    final List<BookshelfRow> rows = await _dao.findAll();

    return rows.map(_toShelvedBook).toList();
  }

  @override
  Future<void> add(ShelfCandidate candidate) async {
    final BookRow? stored = await _dao.findIdentity(
      sourceUrl: candidate.sourceUrl,
      bookUrl: candidate.bookUrl,
    );

    if (stored == null) {
      await _dao.insertNew(
        sourceUrl: candidate.sourceUrl,
        bookUrl: candidate.bookUrl,
        tocUrl: candidate.tocUrl,
        name: candidate.name,
        author: candidate.author,
        kind: candidate.kind,
        coverUrl: candidate.coverUrl,
        intro: candidate.intro,
        lastChapter: candidate.lastChapter,
      );

      return;
    }

    // 书名 / 作者是否覆盖是书源说了算（`canReName`，ADR-0044 §决策 5）：用户看到的名字不该被
    // 一条没声明该能力的源悄悄改掉，而声明了的源修正错字时又应当跟上。
    await _dao.refreshDetails(
      id: stored.id,
      tocUrl: candidate.tocUrl,
      name: candidate.name,
      author: candidate.author,
      kind: candidate.kind,
      coverUrl: candidate.coverUrl,
      intro: candidate.intro,
      lastChapter: candidate.lastChapter,
      rewritesTitle: candidate.canReName,
    );
  }

  @override
  Future<void> updateUserState({
    required int id,
    required ShelfStatus status,
    required bool isPinned,
  }) => _dao.updateUserState(
    id: id,
    status: status.storageValue,
    isPinned: isPinned,
  );

  @override
  Future<void> remove(int id) async {
    await _dao.deleteById(id);
  }

  @override
  Future<ReadingProgressPosition?> findProgress({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    final ReadingProgressRow? row = await _dao.findProgress(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
    );

    return _toProgress(row);
  }

  @override
  Future<void> saveProgress({
    required String sourceUrl,
    required String bookUrl,
    required String chapterUrl,
    String? chapterName,
    int charOffset = 0,
  }) => _dao.upsertProgress(
    sourceUrl: sourceUrl,
    bookUrl: bookUrl,
    chapterUrl: chapterUrl,
    chapterName: chapterName,
    charOffset: charOffset,
  );

  /// Turns one row pair into the shelf entity.
  ShelvedBook _toShelvedBook(BookshelfRow row) => ShelvedBook(
    id: row.book.id,
    sourceUrl: row.book.sourceUrl,
    bookUrl: row.book.bookUrl,
    tocUrl: row.book.tocUrl,
    name: row.book.name,
    author: row.book.author,
    kind: row.book.kind,
    coverUrl: row.book.coverUrl,
    intro: row.book.intro,
    lastChapter: row.book.lastChapter,
    status: ShelfStatus.fromStorage(row.book.status),
    isPinned: row.book.isPinned,
    addedAt: row.book.addedAt,
    progress: _toProgress(row.progress),
  );

  /// Maps the joined progress row, or `null` when the book was never opened.
  ReadingProgressPosition? _toProgress(ReadingProgressRow? row) {
    if (row == null) {
      return null;
    }

    return ReadingProgressPosition(
      chapterUrl: row.chapterUrl,
      chapterName: row.chapterName,
      charOffset: row.charOffset,
      updatedAt: row.updatedAt,
    );
  }
}
