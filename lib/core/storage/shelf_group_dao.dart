import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/book_groups.dart';
import 'package:flutter_reader/core/storage/books.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';

part 'shelf_group_dao.g.dart';

/// Row-level access to the shelf groups.
///
/// Deleting a group clears its books, and reordering normalizes to `0..n-1`.
@DriftAccessor(tables: <Type>[BookGroups, Books])
class ShelfGroupDao extends DatabaseAccessor<ReaderDatabase>
    with _$ShelfGroupDaoMixin {
  /// Creates the DAO with an injected clock.
  ShelfGroupDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Every group in display order.
  Future<List<BookGroupRow>> findAll() =>
      (select(bookGroups)..orderBy(<OrderClauseGenerator<$BookGroupsTable>>[
            ($BookGroupsTable table) => OrderingTerm.asc(table.sortOrder),
            ($BookGroupsTable table) => OrderingTerm.asc(table.id),
          ]))
          .get();

  /// The group named [name], or `null`.
  Future<BookGroupRow?> findByName(String name) => (select(
    bookGroups,
  )..where((BookGroups table) => table.name.equals(name))).getSingleOrNull();

  /// Inserts [name] at [sortOrder] and returns the generated id.
  ///
  /// [createdAt] is optional so a restore can keep the original creation time (`ADR-0073`).
  Future<int> insertNew({
    required String name,
    required int sortOrder,
    DateTime? createdAt,
  }) => into(bookGroups).insert(
    BookGroupsCompanion.insert(
      name: name,
      sortOrder: Value<int>(sortOrder),
      createdAt: createdAt ?? _clock.now(),
    ),
  );

  /// Renames group [id].
  Future<void> rename({required int id, required String name}) =>
      (update(bookGroups)..where((BookGroups table) => table.id.equals(id)))
          .write(BookGroupsCompanion(name: Value<String>(name)));

  /// Deletes group [id], moving its books back to 「未分组」 in the same transaction.
  ///
  /// The books themselves are kept: a group is an organization, not a container.
  Future<void> deleteById(int id) => transaction(() async {
    await (update(books)..where((Books row) => row.groupId.equals(id))).write(
      const BooksCompanion(groupId: Value<int?>(null)),
    );
    await (delete(
      bookGroups,
    )..where((BookGroups table) => table.id.equals(id))).go();
  });

  /// Writes [ids]'s normalized order (`0..n-1`) in one transaction.
  Future<void> reorder(List<int> ids) => transaction(() async {
    for (var index = 0; index < ids.length; index++) {
      await (update(bookGroups)
            ..where((BookGroups table) => table.id.equals(ids[index])))
          .write(BookGroupsCompanion(sortOrder: Value<int>(index)));
    }
  });

  /// Moves shelf rows [ids] into [groupId] (`null` = 未分组) and reports how many changed.
  Future<int> setGroupFor(List<int> ids, int? groupId) {
    if (ids.isEmpty) {
      return Future<int>.value(0);
    }

    return (update(books)..where((Books row) => row.id.isIn(ids))).write(
      BooksCompanion(
        groupId: Value<int?>(groupId),
        updatedAt: Value<DateTime>(_clock.now()),
      ),
    );
  }

  /// Pins or unpins shelf rows [ids] and reports how many changed.
  Future<int> setPinnedFor(List<int> ids, bool isPinned) {
    if (ids.isEmpty) {
      return Future<int>.value(0);
    }

    return (update(books)..where((Books row) => row.id.isIn(ids))).write(
      BooksCompanion(
        isPinned: Value<bool>(isPinned),
        updatedAt: Value<DateTime>(_clock.now()),
      ),
    );
  }

  /// Sets the status of shelf rows [ids] and reports how many changed.
  Future<int> setStatusFor(List<int> ids, int status) {
    if (ids.isEmpty) {
      return Future<int>.value(0);
    }

    return (update(books)..where((Books row) => row.id.isIn(ids))).write(
      BooksCompanion(
        status: Value<int>(status),
        updatedAt: Value<DateTime>(_clock.now()),
      ),
    );
  }
}
