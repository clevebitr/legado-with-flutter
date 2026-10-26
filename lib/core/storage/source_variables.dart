// coverage:ignore-file
import 'package:drift/drift.dart';

/// One persisted book-source variable (`source.getVariable` / `source.setVariable`).
///
/// Upstream keeps `BaseSource.getVariableMap()` as a JSON object on the source row; this repository
/// stores one row per name so a value can be read and written without rewriting the whole map
/// (ADR-0076 §决策 1). The key is the source **URL**, not the `book_sources.id`: an id belongs to
/// one import, while “this source's variables” follows the source itself (the same identity rule
/// the bookshelf already uses).
@DataClassName('SourceVariableRow')
@TableIndex(name: 'source_variables_source', columns: {#sourceUrl})
class SourceVariables extends Table {
  /// `bookSourceUrl` of the source the variable belongs to.
  TextColumn get sourceUrl => text()();

  /// The variable's name.
  TextColumn get name => text()();

  /// The variable's value; upstream's map holds strings only.
  TextColumn get value => text()();

  /// When the row was last written; a diagnostic column, not part of the value.
  DateTimeColumn get updatedAt => dateTime()();

  /// One value per (source, name).
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{sourceUrl, name};
}
