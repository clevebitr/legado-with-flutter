import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
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

  /// The entries currently stored, for assertions after a UI action.
  List<ShelvedBook> get entries => List<ShelvedBook>.unmodifiable(_books);

  /// Seeds one entry directly, bypassing the write path.
  ShelvedBook seed({
    required String name,
    String sourceUrl = 'https://source.test',
    String? bookUrl,
    ShelfStatus status = ShelfStatus.tracking,
    bool isPinned = false,
    ReadingProgressPosition? progress,
  }) {
    final ShelvedBook book = ShelvedBook(
      id: _nextId++,
      sourceUrl: sourceUrl,
      bookUrl: bookUrl ?? 'https://source.test/book/$_nextId',
      name: name,
      status: status,
      isPinned: isPinned,
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
    _books[index] = existing.copyWith(
      name: candidate.name,
      author: candidate.author,
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
  Future<void> remove(int id) async {
    _guard();
    _books.removeWhere((ShelvedBook book) => book.id == id);
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
