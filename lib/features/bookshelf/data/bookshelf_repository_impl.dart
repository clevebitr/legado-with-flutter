import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/shelf_group_dao.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_group.dart';
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
  const BookshelfRepositoryImpl({required this._dao, required this._groups});

  final BookshelfDao _dao;
  final ShelfGroupDao _groups;

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
  Future<bool> migrateIdentity({
    required int id,
    required String sourceUrl,
    required String bookUrl,
    required String? tocUrl,
    required String name,
    required String? author,
    required String? coverUrl,
    required String? lastChapter,
  }) async {
    final BookRow? existing = await _dao.findIdentity(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
    );
    if (existing != null && existing.id != id) {
      // 目标身份已有行：两行并存，各自保留自己的进度（ADR-0051 §决策 3 第 1 条）。
      return false;
    }
    await _dao.migrateIdentity(
      id: id,
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      tocUrl: tocUrl,
      name: name,
      author: author,
      coverUrl: coverUrl,
      lastChapter: lastChapter,
    );

    return true;
  }

  @override
  Future<void> remove(int id) async {
    await _dao.deleteById(id);
  }

  @override
  Future<void> removeMany(List<int> ids) async {
    await _dao.deleteByIds(ids);
  }

  @override
  Future<List<ShelfGroup>> getGroups() async =>
      (await _groups.findAll()).map(_toGroup).toList();

  @override
  Future<ShelfGroup?> createGroup(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    // 先问名字是否被占用，再插：唯一键保证并发下也不会出现两个同名分组，但那条异常会给用户看
    // 一条「写入失败」，而这里想回答的是「这个名字已经有了」。
    if (await _groups.findByName(trimmed) != null) {
      return null;
    }
    final List<BookGroupRow> existing = await _groups.findAll();
    final int id = await _groups.insertNew(
      name: trimmed,
      sortOrder: existing.length,
    );

    return ShelfGroup(id: id, name: trimmed, sortOrder: existing.length);
  }

  @override
  Future<bool> renameGroup({required int id, required String name}) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final BookGroupRow? other = await _groups.findByName(trimmed);
    if (other != null && other.id != id) {
      return false;
    }
    await _groups.rename(id: id, name: trimmed);

    return true;
  }

  @override
  Future<void> deleteGroup(int id) async {
    await _groups.deleteById(id);
  }

  @override
  Future<void> reorderGroups(List<int> ids) async {
    await _groups.reorder(ids);
  }

  @override
  Future<void> setGroupFor({
    required List<int> ids,
    required int? groupId,
  }) async {
    await _groups.setGroupFor(ids, groupId);
  }

  @override
  Future<void> setPinnedFor({
    required List<int> ids,
    required bool isPinned,
  }) async {
    await _groups.setPinnedFor(ids, isPinned);
  }

  @override
  Future<void> setStatusFor({
    required List<int> ids,
    required ShelfStatus status,
  }) async {
    await _groups.setStatusFor(ids, status.storageValue);
  }

  @override
  Future<void> saveCustomCover({required int id, required String? path}) async {
    await _dao.setCustomCover(id: id, path: path);
  }

  @override
  Future<ShelvedBook?> findByUrl({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    final BookRow? row = await _dao.findIdentity(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
    );

    return row == null
        ? null
        : _toShelvedBook(BookshelfRow(book: row, progress: null));
  }

  /// Maps one group row to the shelf's value object.
  ShelfGroup _toGroup(BookGroupRow row) =>
      ShelfGroup(id: row.id, name: row.name, sortOrder: row.sortOrder);

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
    groupId: row.book.groupId,
    customCoverPath: row.book.customCoverPath,
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
