import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/book_sources.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';

part 'book_source_dao.g.dart';

/// Row-level access to the imported book sources (`PLAN.md` 5.1, ADR-0040).
///
/// The DAO owns the **storage shape** and the two decisions that belong to SQL: the row order
/// the list uses and which columns an idempotent re-import refreshes. The *business* decision of
/// what counts as "the same source" lives in `BookSourceRepositoryImpl` (it needs the domain's
/// fingerprint rule), so this class never parses a payload and never guesses an identity.
@DriftAccessor(tables: <Type>[BookSources])
class BookSourceDao extends DatabaseAccessor<ReaderDatabase>
    with _$BookSourceDaoMixin {
  /// Creates the DAO; `clock` decides the row timestamps (`docs/dev/testing.md` §4).
  BookSourceDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Every row, in the order the source list and the default pick use (ADR-0040 §后果):
  /// enabled first, then the manual order, then insertion order.
  ///
  /// The order is part of the contract rather than a caller's `sort`, because two callers
  /// (the list page and `currentBookSourceProvider`) must agree on what "the first source" means.
  Future<List<BookSourceRow>> findAll() =>
      (select(bookSources)..orderBy(<OrderClauseGenerator<$BookSourcesTable>>[
            ($BookSourcesTable table) => OrderingTerm(
              expression: table.isEnabled,
              mode: OrderingMode.desc,
            ),
            ($BookSourcesTable table) =>
                OrderingTerm(expression: table.customOrder),
            ($BookSourcesTable table) => OrderingTerm(expression: table.id),
          ]))
          .get();

  /// The row with [id], or `null` when it is gone.
  Future<BookSourceRow?> findById(int id) => (select(
    bookSources,
  )..where(($BookSourcesTable table) => table.id.equals(id))).getSingleOrNull();

  /// The row identifying the same source as `(url, fingerprint)`, or `null`.
  Future<BookSourceRow?> findIdentity({
    required String url,
    required String fingerprint,
  }) =>
      (select(bookSources)..where(
            ($BookSourcesTable table) =>
                table.url.equals(url) & table.fingerprint.equals(fingerprint),
          ))
          .getSingleOrNull();

  /// Inserts a new row and returns its generated id.
  ///
  /// The caller has already decided that this identity is new
  /// (`BookSourceRepositoryImpl`), and the unique key would reject a duplicate anyway.
  Future<int> insertNew({
    required String url,
    required String fingerprint,
    required String payload,
    required String name,
    required String? groupName,
    required int sourceType,
    required bool isEnabled,
    required int customOrder,
    required int weight,
    required int? lastUpdateTime,
    required int? respondTime,
  }) {
    final DateTime now = _clock.now();

    return into(bookSources).insert(
      BookSourcesCompanion.insert(
        url: url,
        fingerprint: fingerprint,
        payload: payload,
        name: name,
        groupName: Value<String?>(groupName),
        sourceType: Value<int>(sourceType),
        isEnabled: Value<bool>(isEnabled),
        customOrder: Value<int>(customOrder),
        weight: Value<int>(weight),
        lastUpdateTime: Value<int?>(lastUpdateTime),
        respondTime: Value<int?>(respondTime),
        importedAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Refreshes the stored payload of row [id] — the idempotent half of a re-import.
  ///
  /// Only `payload` and `updatedAt` change: the identity already proves that every behaviour
  /// field is equal, and `isEnabled` / `customOrder` are **user state** that an import must
  /// never reset (ADR-0040 §决策 3). The display metadata columns (`groupName`, `weight`, …)
  /// keep their first-import values until `PLAN.md` 5.5 owns them.
  Future<void> refreshPayload({required int id, required String payload}) =>
      (update(
        bookSources,
      )..where(($BookSourcesTable table) => table.id.equals(id))).write(
        BookSourcesCompanion(
          payload: Value<String>(payload),
          updatedAt: Value<DateTime>(_clock.now()),
        ),
      );

  /// Enables or disables row [id] — user state, so only the UI calls this.
  Future<void> setEnabled({required int id, required bool isEnabled}) =>
      (update(bookSources)
            ..where(($BookSourcesTable table) => table.id.equals(id)))
          .write(BookSourcesCompanion(isEnabled: Value<bool>(isEnabled)));

  /// Deletes row [id] and reports how many rows went away (0 or 1).
  Future<int> deleteById(int id) => (delete(
    bookSources,
  )..where(($BookSourcesTable table) => table.id.equals(id))).go();

  /// Deletes every row and returns how many were removed.
  Future<int> deleteAll() => delete(bookSources).go();
}
