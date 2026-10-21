// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookshelf_dao.dart';

// ignore_for_file: type=lint
mixin _$BookshelfDaoMixin on DatabaseAccessor<ReaderDatabase> {
  $BooksTable get books => attachedDatabase.books;
  $ReadingProgressTable get readingProgress => attachedDatabase.readingProgress;
  BookshelfDaoManager get managers => BookshelfDaoManager(this);
}

class BookshelfDaoManager {
  final _$BookshelfDaoMixin _db;
  BookshelfDaoManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(
        _db.attachedDatabase,
        _db.readingProgress,
      );
}
