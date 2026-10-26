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

/// Row-level access to the shelf and the reading progress.
///
/// Owns the storage shape and the shelf order; identity rules live in the repository.
@DriftAccessor(tables: <Type>[Books, ReadingProgress])
class BookshelfDao extends DatabaseAccessor<ReaderDatabase>
    with _$BookshelfDaoMixin {
  /// Creates the DAO with an injected clock.
  BookshelfDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Every shelf entry, in the order the shelf page shows it.
  ///
  /// Unopened books have no progress row; their `NULL`s sort last, after read ones.
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
  /// [addedAt] / [updatedAt] are optional so a restore can write back the times the backup carried
  /// (`ADR-0073` §决策 3); an ordinary add uses the clock.
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
    DateTime? addedAt,
    DateTime? updatedAt,
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
        addedAt: addedAt ?? now,
        updatedAt: updatedAt ?? now,
      ),
    );
  }

  /// Refreshes the page-derived columns of row [id], keeping every user-state column.
  ///
  /// Re-adding an existing book is a refresh, not a reset of `status` / `isPinned`.
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
      // 仅在书源声明了 `canReName` 时覆盖书名/作者；absent 表示保留已存值。
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

  /// Sets the user's own cover path, or clears it with `null`.
  Future<void> setCustomCover({required int id, required String? path}) =>
      (update(books)..where((Books table) => table.id.equals(id))).write(
        BooksCompanion(
          customCoverPath: Value<String?>(path),
          updatedAt: Value<DateTime>(_clock.now()),
        ),
      );

  /// Rewrites the identity of row [id] in place.
  ///
  /// Keeps `addedAt`, `status` and `isPinned` when a source switch changes the URL.
  Future<void> migrateIdentity({
    required int id,
    required String sourceUrl,
    required String bookUrl,
    required String? tocUrl,
    required String name,
    required String? author,
    required String? coverUrl,
    required String? lastChapter,
  }) => (update(books)..where((Books table) => table.id.equals(id))).write(
    BooksCompanion(
      sourceUrl: Value<String>(sourceUrl),
      bookUrl: Value<String>(bookUrl),
      tocUrl: Value<String?>(tocUrl),
      name: Value<String>(name),
      author: Value<String?>(author),
      coverUrl: Value<String?>(coverUrl),
      lastChapter: Value<String?>(lastChapter),
      updatedAt: Value<DateTime>(_clock.now()),
    ),
  );

  /// Deletes row [id] and reports how many rows went away (0 or 1).
  Future<int> deleteById(int id) =>
      (delete(books)..where((Books table) => table.id.equals(id))).go();

  /// Deletes every row in [ids] together with its progress, and reports how many books went away.
  ///
  /// A leftover progress row would resurrect a deleted book as a recently-read entry.
  Future<int> deleteByIds(List<int> ids) {
    if (ids.isEmpty) {
      return Future<int>.value(0);
    }

    return transaction(() async {
      final List<BookRow> rows = await (select(
        books,
      )..where((Books table) => table.id.isIn(ids))).get();
      for (final BookRow row in rows) {
        await (delete(readingProgress)..where(
              (ReadingProgress table) =>
                  table.sourceUrl.equals(row.sourceUrl) &
                  table.bookUrl.equals(row.bookUrl),
            ))
            .go();
      }

      return (delete(books)..where((Books table) => table.id.isIn(ids))).go();
    });
  }

  /// Deletes the shelf row at `(sourceUrl, bookUrl)` together with its progress.
  ///
  /// Both go in one transaction so no leftover progress row can resurrect the book.
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

  /// Writes every user-state column of row [id] — the restore's merge (`ADR-0073` §决策 3).
  ///
  /// Separate from [updateUserState] because a restore also carries the group and the custom cover,
  /// which the shelf's own actions write one at a time.
  Future<void> restoreUserState({
    required int id,
    required int status,
    required bool isPinned,
    required int? groupId,
    required String? customCoverPath,
    String? tocUrl,
  }) => (update(books)..where((Books table) => table.id.equals(id))).write(
    BooksCompanion(
      status: Value<int>(status),
      isPinned: Value<bool>(isPinned),
      groupId: Value<int?>(groupId),
      customCoverPath: Value<String?>(customCoverPath),
      // 本地没有目录地址时才补：有值说明本机已经解析过这个源，恢复不该把它改回去。
      tocUrl: tocUrl == null
          ? const Value<String?>.absent()
          : Value<String?>(tocUrl),
    ),
  );

  /// Every progress row, for the backup (`ADR-0073` §决策 1).
  Future<List<ReadingProgressRow>> findAllProgress() =>
      select(readingProgress).get();

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
  ///
  /// [updatedAt] is optional so a restore can keep the backup's instant, which is what the
  /// 「最近阅读」ordering and the restore's own “do not move the user backwards” rule read
  /// (`ADR-0073` §决策 3).
  Future<void> upsertProgress({
    required String sourceUrl,
    required String bookUrl,
    required String chapterUrl,
    required String? chapterName,
    required int charOffset,
    DateTime? updatedAt,
  }) => into(readingProgress).insertOnConflictUpdate(
    ReadingProgressCompanion.insert(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      chapterUrl: chapterUrl,
      chapterName: Value<String?>(chapterName),
      charOffset: Value<int>(charOffset),
      updatedAt: updatedAt ?? _clock.now(),
    ),
  );

  /// Deletes every shelf row and every progress row, and reports how many books went away.
  Future<int> deleteAll() => transaction(() async {
    await delete(readingProgress).go();

    return delete(books).go();
  });
}
