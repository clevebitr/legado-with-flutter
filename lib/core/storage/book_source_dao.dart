import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/book_sources.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';

part 'book_source_dao.g.dart';

/// Row-level access to the imported book sources (`docs/dev/roadmap.md` 5.1, ADR-0040).
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

  /// Every row, in the order the source list and the default pick use (ADR-0040 §后果,
  /// ADR-0045 §决策 2): [order] first, then enabled first, the manual order and insertion order.
  ///
  /// The order is part of the contract rather than a caller's `sort`, because two callers
  /// (the list page and `currentBookSourceProvider`) must agree on what "the first source" means.
  ///
  /// The trailing three terms are **fixed for every key** on purpose: without them a key whose
  /// values tie (two sources with the same weight) would come back in whatever order SQLite felt
  /// like, and the list would reshuffle between visits.
  Future<List<BookSourceRow>> findAll({
    BookSourceSortOrder order = BookSourceSortOrder.defaultOrder,
  }) =>
      (select(bookSources)..orderBy(<OrderClauseGenerator<$BookSourcesTable>>[
            ..._primaryOrder(order),
            ($BookSourcesTable table) => OrderingTerm(
              expression: table.isEnabled,
              mode: OrderingMode.desc,
            ),
            ($BookSourcesTable table) =>
                OrderingTerm(expression: table.customOrder),
            ($BookSourcesTable table) => OrderingTerm(expression: table.id),
          ]))
          .get();

  /// The terms the chosen [order] adds in front of the fixed tie-breakers.
  List<OrderClauseGenerator<$BookSourcesTable>> _primaryOrder(
    BookSourceSortOrder order,
  ) => switch (order) {
    // 默认序就是「手动序」，它已经在固定 tie-breaker 里，不需要额外的主键。
    BookSourceSortOrder.defaultOrder =>
      const <OrderClauseGenerator<$BookSourcesTable>>[],
    BookSourceSortOrder.weight => <OrderClauseGenerator<$BookSourcesTable>>[
      ($BookSourcesTable table) =>
          OrderingTerm(expression: table.weight, mode: OrderingMode.desc),
    ],
    BookSourceSortOrder.respondTime =>
      <OrderClauseGenerator<$BookSourcesTable>>[
        // 「从未校验」是 NULL，不是 0 ms：升序时把它排到最后（ADR-0045 §决策 2）。
        ($BookSourcesTable table) =>
            OrderingTerm(expression: table.respondTime, nulls: NullsOrder.last),
      ],
    BookSourceSortOrder.name => <OrderClauseGenerator<$BookSourcesTable>>[
      ($BookSourcesTable table) => OrderingTerm(expression: table.name),
    ],
  };

  /// Rewrites `customOrder` as `0..n-1` following [orderedIds], in one transaction.
  ///
  /// Whole-list renumbering instead of swapping neighbours: swapping two rows that share a
  /// `customOrder` has no defined result, while renumbering is idempotent (ADR-0045 §决策 3).
  /// Ids that no longer exist are skipped, so a row deleted in another tab cannot make the write
  /// fail; the caller re-reads the list afterwards either way.
  Future<void> reorder(List<int> orderedIds) => transaction(
    () => batch((Batch batch) {
      for (var index = 0; index < orderedIds.length; index++) {
        batch.update(
          bookSources,
          BookSourcesCompanion(customOrder: Value<int>(index)),
          where: ($BookSourcesTable table) =>
              table.id.equals(orderedIds[index]),
        );
      }
    }),
  );

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
  /// keep their first-import values until `docs/dev/roadmap.md` 5.5 owns them.
  Future<void> refreshPayload({required int id, required String payload}) =>
      (update(
        bookSources,
      )..where(($BookSourcesTable table) => table.id.equals(id))).write(
        BookSourcesCompanion(
          payload: Value<String>(payload),
          updatedAt: Value<DateTime>(_clock.now()),
        ),
      );

  /// Writes what a batch check found back onto row [id] (`docs/dev/roadmap.md` §5.10).
  ///
  /// The three columns are written together because they describe one run: a group list that was
  /// cleared without its matching note (or the other way round) would show a source as healthy
  /// while its comment still says what broke. The **merge** itself is not decided here — the caller
  /// passes the values it computed from the domain's group / comment rules (ADR-0043 §决策 1).
  Future<void> writeCheckState({
    required int id,
    required String? groupName,
    required String? comment,
    required int? respondTime,
  }) =>
      (update(
        bookSources,
      )..where(($BookSourcesTable table) => table.id.equals(id))).write(
        BookSourcesCompanion(
          groupName: Value<String?>(groupName),
          comment: Value<String?>(comment),
          respondTime: Value<int?>(respondTime),
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
