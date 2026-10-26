// coverage:ignore-file
import 'package:drift/drift.dart';

/// A user-defined shelf group.
///
/// 「全部」 is a filter view, not a row; `books.groupId == null` means 未分组.
@DataClassName('BookGroupRow')
class BookGroups extends Table {
  /// Synthetic primary key.
  IntColumn get id => integer().autoIncrement()();

  /// The name shown in the filter chips and the management page; unique.
  TextColumn get name => text()();

  /// Normalized `0..n-1` position written by the management page's reordering.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// When the group was created.
  DateTimeColumn get createdAt => dateTime()();

  /// One row per name.
  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{name},
  ];
}
