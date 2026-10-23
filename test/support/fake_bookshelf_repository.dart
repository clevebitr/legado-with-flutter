import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_group.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/domain/repositories/bookshelf_repository.dart';

/// In-memory [BookshelfRepository] for tests (`docs/dev/testing.md` §4).
///
/// It behaves like the Drift implementation where the pages can tell the difference: `add` is
/// idempotent on `(sourceUrl, bookUrl)`, re-adding refreshes the snapshot but keeps the user
/// state, and `getAll` orders pinned first then by the newest write. [failWrites] makes every
/// mutation throw, which is how the notifier's failure path is exercised.
final class FakeBookshelfRepository implements BookshelfRepository {
  final List<ShelvedBook> _books = <ShelvedBook>[];

  /// Whether every mutation throws a generic exception (the C-ERR-2 boundary case).
  bool failWrites = false;

  /// Whether reading the shelf throws (the page's error state).
  bool failReads = false;

  int _nextId = 1;

  /// The groups the shelf has, in display order.
  final List<ShelfGroup> groups = <ShelfGroup>[];

  int _nextGroupId = 1;

  /// The entries currently stored, for assertions after a UI action.
  List<ShelvedBook> get entries => List<ShelvedBook>.unmodifiable(_books);

  /// Seeds one entry directly, bypassing the write path.
  ShelvedBook seed({
    required String name,
    String sourceUrl = 'https://source.test',
    String? bookUrl,
    String? tocUrl,
    bool canReName = false,
    ShelfStatus status = ShelfStatus.tracking,
    bool isPinned = false,
    String? coverUrl,
    int? groupId,
    String? customCoverPath,
    ReadingProgressPosition? progress,
  }) {
    final ShelvedBook book = ShelvedBook(
      id: _nextId++,
      sourceUrl: sourceUrl,
      bookUrl: bookUrl ?? 'https://source.test/book/$_nextId',
      tocUrl: tocUrl,
      name: name,
      coverUrl: coverUrl,
      status: status,
      isPinned: isPinned,
      groupId: groupId,
      customCoverPath: customCoverPath,
      addedAt: DateTime(2026, 10, 21),
      progress: progress,
    );
    _books.add(book);

    return book;
  }

  @override
  Future<List<ShelvedBook>> getAll() async {
    if (failReads) {
      throw Exception('the shelf is unavailable');
    }

    return _sort();
  }

  @override
  Future<void> add(ShelfCandidate candidate) async {
    _guard();
    final int index = _indexOf(candidate.sourceUrl, candidate.bookUrl);
    if (index < 0) {
      _books.add(
        ShelvedBook(
          id: _nextId++,
          sourceUrl: candidate.sourceUrl,
          bookUrl: candidate.bookUrl,
          tocUrl: candidate.tocUrl,
          name: candidate.name,
          author: candidate.author,
          kind: candidate.kind,
          coverUrl: candidate.coverUrl,
          intro: candidate.intro,
          lastChapter: candidate.lastChapter,
          addedAt: DateTime(2026, 10, 21),
        ),
      );

      return;
    }

    final ShelvedBook existing = _books[index];
    // 与真实实现同一条规则：书名 / 作者只在源声明 canReName 时覆盖（ADR-0044 §决策 5）。
    _books[index] = existing.copyWith(
      tocUrl: candidate.tocUrl,
      name: candidate.canReName ? candidate.name : existing.name,
      author: candidate.canReName ? candidate.author : existing.author,
      kind: candidate.kind,
      coverUrl: candidate.coverUrl,
      intro: candidate.intro,
      lastChapter: candidate.lastChapter,
    );
  }

  @override
  Future<void> updateUserState({
    required int id,
    required ShelfStatus status,
    required bool isPinned,
  }) async {
    _guard();
    final int index = _books.indexWhere((ShelvedBook book) => book.id == id);
    if (index < 0) {
      return;
    }
    _books[index] = _books[index].copyWith(status: status, isPinned: isPinned);
  }

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
    _guard();
    final int index = _books.indexWhere((ShelvedBook book) => book.id == id);
    if (index < 0) {
      return false;
    }
    // 目标身份已有行 → 两行并存（ADR-0051 §决策 3）。
    if (_books.any(
      (ShelvedBook book) =>
          book.id != id &&
          book.sourceUrl == sourceUrl &&
          book.bookUrl == bookUrl,
    )) {
      return false;
    }
    final ShelvedBook current = _books[index];
    _books[index] = current.copyWith(
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
    _guard();
    _books.removeWhere((ShelvedBook book) => book.id == id);
  }

  @override
  Future<void> removeMany(List<int> ids) async {
    _guard();
    _books.removeWhere((ShelvedBook book) => ids.contains(book.id));
  }

  @override
  Future<List<ShelfGroup>> getGroups() async {
    if (failReads) {
      throw Exception('the shelf is unavailable');
    }

    return List<ShelfGroup>.unmodifiable(
      groups.toList()..sort(
        (ShelfGroup left, ShelfGroup right) =>
            left.sortOrder.compareTo(right.sortOrder),
      ),
    );
  }

  @override
  Future<ShelfGroup?> createGroup(String name) async {
    _guard();
    final String trimmed = name.trim();
    if (trimmed.isEmpty ||
        groups.any((ShelfGroup group) => group.name == trimmed)) {
      return null;
    }
    final ShelfGroup group = ShelfGroup(
      id: _nextGroupId++,
      name: trimmed,
      sortOrder: groups.length,
    );
    groups.add(group);

    return group;
  }

  @override
  Future<bool> renameGroup({required int id, required String name}) async {
    _guard();
    final String trimmed = name.trim();
    if (trimmed.isEmpty ||
        groups.any(
          (ShelfGroup group) => group.id != id && group.name == trimmed,
        )) {
      return false;
    }
    final int index = groups.indexWhere((ShelfGroup group) => group.id == id);
    if (index < 0) {
      return false;
    }
    groups[index] = groups[index].copyWith(name: trimmed);

    return true;
  }

  @override
  Future<void> deleteGroup(int id) async {
    _guard();
    groups.removeWhere((ShelfGroup group) => group.id == id);
    for (var index = 0; index < _books.length; index++) {
      if (_books[index].groupId == id) {
        _books[index] = _books[index].copyWith(groupId: null);
      }
    }
  }

  @override
  Future<void> reorderGroups(List<int> ids) async {
    _guard();
    for (var order = 0; order < ids.length; order++) {
      final int index = groups.indexWhere(
        (ShelfGroup group) => group.id == ids[order],
      );
      if (index >= 0) {
        groups[index] = groups[index].copyWith(sortOrder: order);
      }
    }
  }

  @override
  Future<void> setGroupFor({
    required List<int> ids,
    required int? groupId,
  }) async {
    _guard();
    _mapBooks(ids, (ShelvedBook book) => book.copyWith(groupId: groupId));
  }

  @override
  Future<void> setPinnedFor({
    required List<int> ids,
    required bool isPinned,
  }) async {
    _guard();
    _mapBooks(ids, (ShelvedBook book) => book.copyWith(isPinned: isPinned));
  }

  @override
  Future<void> setStatusFor({
    required List<int> ids,
    required ShelfStatus status,
  }) async {
    _guard();
    _mapBooks(ids, (ShelvedBook book) => book.copyWith(status: status));
  }

  @override
  Future<void> saveCustomCover({required int id, required String? path}) async {
    _guard();
    _mapBooks(<int>[
      id,
    ], (ShelvedBook book) => book.copyWith(customCoverPath: path));
  }

  @override
  Future<ShelvedBook?> findByUrl({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    if (failReads) {
      throw Exception('the shelf is unavailable');
    }
    final int index = _indexOf(sourceUrl, bookUrl);

    return index < 0 ? null : _books[index];
  }

  /// Applies [change] to every entry whose id is in [ids].
  void _mapBooks(List<int> ids, ShelvedBook Function(ShelvedBook book) change) {
    for (var index = 0; index < _books.length; index++) {
      if (ids.contains(_books[index].id)) {
        _books[index] = change(_books[index]);
      }
    }
  }

  @override
  Future<ReadingProgressPosition?> findProgress({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    if (failReads) {
      throw Exception('the shelf is unavailable');
    }
    final int index = _indexOf(sourceUrl, bookUrl);

    return index < 0 ? null : _books[index].progress;
  }

  @override
  Future<void> saveProgress({
    required String sourceUrl,
    required String bookUrl,
    required String chapterUrl,
    String? chapterName,
    int charOffset = 0,
  }) async {
    _guard();
    final int index = _indexOf(sourceUrl, bookUrl);
    if (index < 0) {
      return;
    }
    _books[index] = _books[index].copyWith(
      progress: ReadingProgressPosition(
        chapterUrl: chapterUrl,
        chapterName: chapterName,
        charOffset: charOffset,
        updatedAt: DateTime(2026, 10, 21),
      ),
    );
  }

  /// The index of the entry at `(sourceUrl, bookUrl)`, or -1.
  int _indexOf(String sourceUrl, String bookUrl) => _books.indexWhere(
    (ShelvedBook book) =>
        book.sourceUrl == sourceUrl && book.bookUrl == bookUrl,
  );

  /// Pinned first, then the ones with progress, then insertion order.
  List<ShelvedBook> _sort() {
    final List<ShelvedBook> copy = List<ShelvedBook>.of(_books)
      ..sort((ShelvedBook left, ShelvedBook right) {
        if (left.isPinned != right.isPinned) {
          return left.isPinned ? -1 : 1;
        }
        final DateTime leftRead = left.progress?.updatedAt ?? DateTime(0);
        final DateTime rightRead = right.progress?.updatedAt ?? DateTime(0);
        if (leftRead != rightRead) {
          return rightRead.compareTo(leftRead);
        }

        return right.id.compareTo(left.id);
      });

    return copy;
  }

  /// Throws when [failWrites] is set.
  void _guard() {
    if (failWrites) {
      throw Exception('the shelf is unavailable');
    }
  }
}
