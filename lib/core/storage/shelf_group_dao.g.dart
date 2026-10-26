// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shelf_group_dao.dart';

// ignore_for_file: type=lint
mixin _$ShelfGroupDaoMixin on DatabaseAccessor<ReaderDatabase> {
  $BookGroupsTable get bookGroups => attachedDatabase.bookGroups;
  $BooksTable get books => attachedDatabase.books;
  ShelfGroupDaoManager get managers => ShelfGroupDaoManager(this);
}

class ShelfGroupDaoManager {
  final _$ShelfGroupDaoMixin _db;
  ShelfGroupDaoManager(this._db);
  $$BookGroupsTableTableManager get bookGroups =>
      $$BookGroupsTableTableManager(_db.attachedDatabase, _db.bookGroups);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
}
