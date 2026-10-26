// coverage:ignore-file
import 'package:drift/drift.dart';

/// How many checks one source keeps.
///
/// Enough to spot a flapping source without letting a large batch grow forever.
const int checkHistoryLimit = 20;

/// One run of the book-source check.
///
/// A separate table keeps every run's time and stage; single columns cannot.
@DataClassName('SourceCheckRow')
@TableIndex(
  name: 'source_checks_source_checked',
  columns: {#sourceId, #checkedAt},
)
class SourceChecks extends Table {
  /// Synthetic primary key; the history is append-only.
  IntColumn get id => integer().autoIncrement()();

  /// The `book_sources.id` this run belongs to.
  ///
  /// No foreign key: the delete paths remove the history in one transaction.
  IntColumn get sourceId => integer()();

  /// When the run finished, from the injected `Clock`.
  DateTimeColumn get checkedAt => dateTime()();

  /// `succeeded` / `failed` / `cancelled` — the domain enum's name.
  TextColumn get status => text()();

  /// The failure group tokens this run wrote, joined, or `null` when healthy.
  TextColumn get invalidGroups => text().nullable()();

  /// The note this run wrote into `bookSourceComment`, or `null` when healthy.
  TextColumn get errorComment => text().nullable()();

  /// How long the run took, which is also what `respondTime` stores.
  IntColumn get elapsedMillis => integer()();
}
