// coverage:ignore-file
import 'package:drift/drift.dart';

/// The book sources the user imported.
///
/// The identity is `(url, fingerprint)`; same URL with different rules differs.
@DataClassName('BookSourceRow')
class BookSources extends Table {
  /// Synthetic primary key; `AUTOINCREMENT` stops SQLite from reusing a deleted id.
  IntColumn get id => integer().autoIncrement()();

  /// `bookSourceUrl` — upstream's natural identifier.
  TextColumn get url => text()();

  /// sha256 of the behaviour fields' canonical JSON.
  TextColumn get fingerprint => text()();

  /// The entry exactly as imported; unknown keys survive here byte-for-byte.
  TextColumn get payload => text()();

  /// `bookSourceName`, projected for the list.
  TextColumn get name => text()();

  /// `bookSourceGroup`, projected for the list.
  TextColumn get groupName => text().nullable()();

  /// `bookSourceComment`, rewritten by the batch check; not part of [payload].
  TextColumn get comment => text().nullable()();

  /// `bookSourceType`, projected for the list.
  IntColumn get sourceType => integer().withDefault(const Constant(0))();

  /// User state: whether the source takes part in search / explore.
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  /// User state: the manual sort order.
  IntColumn get customOrder => integer().withDefault(const Constant(0))();

  /// User state: whether the source's discover page is offered.
  BoolColumn get isExploreEnabled =>
      boolean().withDefault(const Constant(true))();

  /// `weight`, projected for sorting.
  IntColumn get weight => integer().withDefault(const Constant(0))();

  /// `lastUpdateTime`, projected for display.
  IntColumn get lastUpdateTime => integer().nullable()();

  /// `respondTime`, projected for display.
  IntColumn get respondTime => integer().nullable()();

  /// The `loginUi` form's values, as a JSON object, or `null` when the source was never signed in
  /// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
  ///
  /// User state like [isEnabled]: an import never overwrites it, and it is stored in cleartext —
  /// the same level as the cookie jar (registered in `roadmap.md` §3.7).
  TextColumn get loginInfo => text().nullable()();

  /// When the row was created.
  DateTimeColumn get importedAt => dateTime()();

  /// When the stored payload was last refreshed.
  DateTimeColumn get updatedAt => dateTime()();

  /// The identity unique key: same URL and same behaviour is the same source.
  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{url, fingerprint},
  ];
}
