import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/bookmarks.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';

part 'bookmark_dao.g.dart';

/// Row-level access to the bookmarks.
@DriftAccessor(tables: <Type>[Bookmarks])
class BookmarkDao extends DatabaseAccessor<ReaderDatabase>
    with _$BookmarkDaoMixin {
  /// Creates the DAO with an injected clock.
  BookmarkDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Every bookmark, newest first.
  ///
  /// The `id` tie-breaker keeps the order stable when two marks share a timestamp.
  Future<List<BookmarkRow>> findAll() =>
      (select(bookmarks)..orderBy(<OrderClauseGenerator<$BookmarksTable>>[
            ($BookmarksTable table) => OrderingTerm.desc(table.createdAt),
            ($BookmarksTable table) => OrderingTerm.desc(table.id),
          ]))
          .get();

  /// The bookmarks of `(sourceUrl, bookUrl)`, in chapter order.
  Future<List<BookmarkRow>> findForBook({
    required String sourceUrl,
    required String bookUrl,
  }) =>
      (select(bookmarks)
            ..where(
              (Bookmarks table) =>
                  table.sourceUrl.equals(sourceUrl) &
                  table.bookUrl.equals(bookUrl),
            )
            ..orderBy(<OrderClauseGenerator<$BookmarksTable>>[
              ($BookmarksTable table) => OrderingTerm.asc(table.chapterIndex),
              ($BookmarksTable table) => OrderingTerm.asc(table.charOffset),
            ]))
          .get();

  /// The bookmark at one exact position, or `null`.
  ///
  /// The position is the unique key, so this is one indexed lookup.
  Future<BookmarkRow?> findAt({
    required String sourceUrl,
    required String bookUrl,
    required String chapterUrl,
    required int charOffset,
  }) =>
      (select(bookmarks)..where(
            (Bookmarks table) =>
                table.sourceUrl.equals(sourceUrl) &
                table.bookUrl.equals(bookUrl) &
                table.chapterUrl.equals(chapterUrl) &
                table.charOffset.equals(charOffset),
          ))
          .getSingleOrNull();

  /// Inserts one bookmark and returns its generated id.
  Future<int> insertNew({
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    required String? tocUrl,
    required String chapterUrl,
    required String? chapterName,
    required int chapterIndex,
    required int charOffset,
    required String? excerpt,
  }) => into(bookmarks).insert(
    BookmarksCompanion.insert(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      bookName: bookName,
      tocUrl: Value<String?>(tocUrl),
      chapterUrl: chapterUrl,
      chapterName: Value<String?>(chapterName),
      chapterIndex: Value<int>(chapterIndex),
      charOffset: Value<int>(charOffset),
      excerpt: Value<String?>(excerpt),
      createdAt: _clock.now(),
    ),
  );

  /// Deletes bookmark [id] and reports how many rows went away (0 or 1).
  Future<int> deleteById(int id) =>
      (delete(bookmarks)..where((Bookmarks table) => table.id.equals(id))).go();
}
