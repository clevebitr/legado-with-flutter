import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/books.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';

part 'bookshelf_dao.g.dart';

/// One shelf row together with its reading progress, if the book was ever opened.
final class BookshelfRow {
  /// Creates a shelf row.
  const BookshelfRow({required this.book, required this.progress});

  /// The book itself.
  final BookRow book;

  /// Where the reader stopped, or `null` when the book was never opened.
  final ReadingProgressRow? progress;
}

/// Row-level access to the shelf and the reading progress (`docs/dev/roadmap.md` 5.4).
///
/// The DAO owns the **storage shape** and the one ordering SQL decides: pinned first, then
/// «recently read» (progress, falling back to when the row was last written), then insertion
/// order. The business rules — what counts as the same book, and which fields an existing row
/// keeps — live in `BookshelfRepositoryImpl`, for the same reason `BookSourceDao` keeps out of
/// the fingerprint decision.
@DriftAccessor(tables: <Type>[Books, ReadingProgress])
class BookshelfDao extends DatabaseAccessor<ReaderDatabase>
    with _$BookshelfDaoMixin {
  /// Creates the DAO; `clock` decides the row timestamps (`docs/dev/testing.md` §4).
  BookshelfDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Every shelf entry, in the order the shelf page shows it.
  ///
  /// «Recently read» is a left join on [ReadingProgress]: a book that was never opened has no
  /// progress row, and SQLite sorts those `NULL`s last under `DESC`, which is exactly the
  /// wanted fallback order (unread books by `updatedAt`, after the read ones).
  Future<List<BookshelfRow>> findAll() async {
    final JoinedSelectStatement<HasResultSet, dynamic> query =
        select(books).join(<Join<HasResultSet, dynamic>>[
          leftOuterJoin(
            readingProgress,
            readingProgress.sourceUrl.equalsExp(books.sourceUrl) &
                readingProgress.bookUrl.equalsExp(books.bookUrl),
          ),
        ])..orderBy(<OrderingTerm>[
          OrderingTerm.desc(books.isPinned),
          OrderingTerm.desc(readingProgress.updatedAt),
          OrderingTerm.desc(books.updatedAt),
          OrderingTerm.desc(books.id),
        ]);

    final List<TypedResult> rows = await query.get();

    return rows
        .map(
          (TypedResult row) => BookshelfRow(
            book: row.readTable(books),
            progress: row.readTableOrNull(readingProgress),
          ),
        )
        .toList();
  }

  /// The row identifying the book at `(sourceUrl, bookUrl)`, or `null`.
  Future<BookRow?> findIdentity({
    required String sourceUrl,
    required String bookUrl,
  }) =>
      (select(books)..where(
            (Books table) =>
                table.sourceUrl.equals(sourceUrl) &
                table.bookUrl.equals(bookUrl),
          ))
          .getSingleOrNull();

  /// Inserts a new shelf row and returns its generated id.
  ///
  /// The caller already decided this identity is new (`BookshelfRepositoryImpl`); the unique
  /// key would reject a duplicate anyway.
  Future<int> insertNew({
    required String sourceUrl,
    required String bookUrl,
    required String? tocUrl,
    required String name,
    required String? author,
    required String? kind,
    required String? coverUrl,
    required String? intro,
    required String? lastChapter,
  }) {
    final DateTime now = _clock.now();

    return into(books).insert(
      BooksCompanion.insert(
        sourceUrl: sourceUrl,
        bookUrl: bookUrl,
        tocUrl: Value<String?>(tocUrl),
        name: name,
        author: Value<String?>(author),
        kind: Value<String?>(kind),
        coverUrl: Value<String?>(coverUrl),
        intro: Value<String?>(intro),
        lastChapter: Value<String?>(lastChapter),
        addedAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Refreshes the page-derived columns of row [id], keeping every user-state column.
  ///
  /// Re-adding an existing book is a refresh, not a reset: `status` / `isPinned` are the user's
  /// and the same rule as ADR-0040 §决策 3 applies (an import must never undo user state).
  Future<void> refreshDetails({
    required int id,
    required String? tocUrl,
    required String name,
    required String? author,
    required String? kind,
    required String? coverUrl,
    required String? intro,
    required String? lastChapter,
    required bool rewritesTitle,
  }) => (update(books)..where((Books table) => table.id.equals(id))).write(
    BooksCompanion(
      tocUrl: Value<String?>(tocUrl),
      kind: Value<String?>(kind),
      coverUrl: Value<String?>(coverUrl),
      intro: Value<String?>(intro),
      lastChapter: Value<String?>(lastChapter),
      // 书名 / 作者只在书源声明了 `canReName` 时覆盖（ADR-0044 §决策 5）：
      // `null` 表示「保留已存的值」，不是「写成 null」。
      name: rewritesTitle ? Value<String>(name) : const Value<String>.absent(),
      author: rewritesTitle
          ? Value<String?>(author)
          : const Value<String?>.absent(),
      updatedAt: Value<DateTime>(_clock.now()),
    ),
  );

  /// Sets the user-state columns of row [id].
  Future<void> updateUserState({
    required int id,
    required int status,
    required bool isPinned,
  }) => (update(books)..where((Books table) => table.id.equals(id))).write(
    BooksCompanion(
      status: Value<int>(status),
      isPinned: Value<bool>(isPinned),
      updatedAt: Value<DateTime>(_clock.now()),
    ),
  );

  /// Deletes row [id] and reports how many rows went away (0 or 1).
  Future<int> deleteById(int id) =>
      (delete(books)..where((Books table) => table.id.equals(id))).go();

  /// Deletes the shelf row at `(sourceUrl, bookUrl)` together with its progress.
  ///
  /// Both go in one transaction: a leftover progress row would resurrect a deleted book as a
  /// «recently read» entry the moment it is re-added.
  Future<void> deleteIdentity({
    required String sourceUrl,
    required String bookUrl,
  }) => transaction(() async {
    await (delete(readingProgress)..where(
          (ReadingProgress table) =>
              table.sourceUrl.equals(sourceUrl) & table.bookUrl.equals(bookUrl),
        ))
        .go();
    await (delete(books)..where(
          (Books table) =>
              table.sourceUrl.equals(sourceUrl) & table.bookUrl.equals(bookUrl),
        ))
        .go();
  });

  /// The progress row of `(sourceUrl, bookUrl)`, or `null`.
  Future<ReadingProgressRow?> findProgress({
    required String sourceUrl,
    required String bookUrl,
  }) =>
      (select(readingProgress)..where(
            (ReadingProgress table) =>
                table.sourceUrl.equals(sourceUrl) &
                table.bookUrl.equals(bookUrl),
          ))
          .getSingleOrNull();

  /// Writes the progress of one book, replacing the previous position.
  Future<void> upsertProgress({
    required String sourceUrl,
    required String bookUrl,
    required String chapterUrl,
    required String? chapterName,
    required int charOffset,
  }) => into(readingProgress).insertOnConflictUpdate(
    ReadingProgressCompanion.insert(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      chapterUrl: chapterUrl,
      chapterName: Value<String?>(chapterName),
      charOffset: Value<int>(charOffset),
      updatedAt: _clock.now(),
    ),
  );

  /// Deletes every shelf row and every progress row, and reports how many books went away.
  Future<int> deleteAll() => transaction(() async {
    await delete(readingProgress).go();

    return delete(books).go();
  });
}
