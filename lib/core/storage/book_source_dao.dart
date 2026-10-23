import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/book_sources.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/source_checks.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';

part 'book_source_dao.g.dart';

/// Row-level access to the imported book sources (`docs/dev/roadmap.md` 5.1, ADR-0040).
///
/// The DAO owns the **storage shape** and the two decisions that belong to SQL: the row order
/// the list uses and which columns an idempotent re-import refreshes. The *business* decision of
/// what counts as "the same source" lives in `BookSourceRepositoryImpl` (it needs the domain's
/// fingerprint rule), so this class never parses a payload and never guesses an identity.
@DriftAccessor(tables: <Type>[BookSources, SourceChecks])
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
    bool ascending = true,
  }) {
    final OrderingMode mode = ascending ? OrderingMode.asc : OrderingMode.desc;

    // 默认序（手动序）保持「启用在前」这一层分组：把禁用的源拖到顶部没有意义，
    // 列表会立刻把它压回底部（ADR-0052 §决策 4）。其他排序键则让主键先说话。
    final List<OrderClauseGenerator<$BookSourcesTable>> primary =
        order == BookSourceSortOrder.defaultOrder
        ? <OrderClauseGenerator<$BookSourcesTable>>[
            ($BookSourcesTable table) => OrderingTerm(
              expression: table.isEnabled,
              mode: OrderingMode.desc,
            ),
            ($BookSourcesTable table) =>
                OrderingTerm(expression: table.customOrder, mode: mode),
          ]
        : <OrderClauseGenerator<$BookSourcesTable>>[
            ..._primaryOrder(order, mode),
            ($BookSourcesTable table) => OrderingTerm(
              expression: table.isEnabled,
              mode: OrderingMode.desc,
            ),
            ($BookSourcesTable table) =>
                OrderingTerm(expression: table.customOrder),
          ];

    return (select(bookSources)
          ..orderBy(<OrderClauseGenerator<$BookSourcesTable>>[
            ...primary,
            ($BookSourcesTable table) => OrderingTerm(
              expression: table.id,
              mode: order == BookSourceSortOrder.defaultOrder
                  ? mode
                  : OrderingMode.asc,
            ),
          ]))
        .get();
  }

  /// The primary terms of a non-manual [order], following its direction.
  List<OrderClauseGenerator<$BookSourcesTable>> _primaryOrder(
    BookSourceSortOrder order,
    OrderingMode mode,
  ) => switch (order) {
    // 默认序（手动序）由 [findAll] 自己排，不需要额外的主键。
    BookSourceSortOrder.defaultOrder =>
      const <OrderClauseGenerator<$BookSourcesTable>>[],
    BookSourceSortOrder.weight => <OrderClauseGenerator<$BookSourcesTable>>[
      ($BookSourcesTable table) =>
          OrderingTerm(expression: table.weight, mode: mode),
    ],
    BookSourceSortOrder.respondTime =>
      <OrderClauseGenerator<$BookSourcesTable>>[
        // 「从未校验」是 NULL，不是 0 ms：两个方向都把它排到最后（ADR-0045 §决策 2）。
        ($BookSourcesTable table) => OrderingTerm(
          expression: table.respondTime,
          mode: mode,
          nulls: NullsOrder.last,
        ),
      ],
    BookSourceSortOrder.name => <OrderClauseGenerator<$BookSourcesTable>>[
      ($BookSourcesTable table) =>
          OrderingTerm(expression: table.name, mode: mode),
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
    required bool isExploreEnabled,
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
        isExploreEnabled: Value<bool>(isExploreEnabled),
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

  /// Writes one check back: the three legacy columns **and** its history row, in one transaction
  /// (`docs/dev/roadmap.md` §3.10 V1, ADR-0052 §决策 1).
  ///
  /// [status] is the domain enum's name and [invalidGroups] is already joined, because `core/`
  /// must not import `features/` (architecture §2). Writing both in one transaction is what keeps
  /// the status light and the source's own group list from describing different runs.
  Future<void> applyCheck({
    required int id,
    required String? groupName,
    required String? comment,
    required int? respondTime,
    required String status,
    required String? invalidGroups,
    required String? errorComment,
    required int elapsedMillis,
  }) => transaction(() async {
    await writeCheckState(
      id: id,
      groupName: groupName,
      comment: comment,
      respondTime: respondTime,
    );
    await into(sourceChecks).insert(
      SourceChecksCompanion.insert(
        sourceId: id,
        checkedAt: _clock.now(),
        status: status,
        invalidGroups: Value<String?>(invalidGroups),
        errorComment: Value<String?>(errorComment),
        elapsedMillis: elapsedMillis,
      ),
    );
    await _trimHistory(id);
  });

  /// Keeps the newest [checkHistoryLimit] rows of [sourceId] and drops the rest.
  ///
  /// History is diagnosis, not a ledger: an unbounded log would let a few batch checks keep tens of
  /// thousands of rows forever (ADR-0052 §决策 1). Two queries instead of a subquery delete, because
  /// the id list is bounded by the same constant and this stays readable in the DSL.
  Future<void> _trimHistory(int sourceId) async {
    final List<int> keep =
        await (select(sourceChecks)
              ..where(
                ($SourceChecksTable table) => table.sourceId.equals(sourceId),
              )
              ..orderBy(<OrderClauseGenerator<$SourceChecksTable>>[
                ($SourceChecksTable table) => OrderingTerm(
                  expression: table.checkedAt,
                  mode: OrderingMode.desc,
                ),
                ($SourceChecksTable table) =>
                    OrderingTerm(expression: table.id, mode: OrderingMode.desc),
              ])
              ..limit(checkHistoryLimit))
            .map((SourceCheckRow row) => row.id)
            .get();
    await (delete(sourceChecks)..where(
          ($SourceChecksTable table) =>
              table.sourceId.equals(sourceId) & table.id.isNotIn(keep),
        ))
        .go();
  }

  /// The newest recorded check per source, ignoring [excludedStatus] (`cancelled`).
  ///
  /// A cancelled run proves nothing about the source (ADR-0043 §后果), so the light and the
  /// "last checked" line must describe the last **verdict**. Ordering by `(sourceId, checkedAt
  /// desc)` walks the `source_checks_source_checked` index and keeps one row per source in memory.
  Future<Map<int, SourceCheckRow>> latestChecks({
    required String excludedStatus,
  }) async {
    final List<SourceCheckRow> rows =
        await (select(sourceChecks)
              ..where(
                ($SourceChecksTable table) =>
                    table.status.equals(excludedStatus).not(),
              )
              ..orderBy(<OrderClauseGenerator<$SourceChecksTable>>[
                ($SourceChecksTable table) =>
                    OrderingTerm(expression: table.sourceId),
                ($SourceChecksTable table) => OrderingTerm(
                  expression: table.checkedAt,
                  mode: OrderingMode.desc,
                ),
                ($SourceChecksTable table) =>
                    OrderingTerm(expression: table.id, mode: OrderingMode.desc),
              ]))
            .get();
    final Map<int, SourceCheckRow> latest = <int, SourceCheckRow>{};
    for (final SourceCheckRow row in rows) {
      latest.putIfAbsent(row.sourceId, () => row);
    }

    return latest;
  }

  /// Deletes the recorded checks of [sourceIds] (used by the delete paths below).
  Future<void> deleteChecksOf(List<int> sourceIds) async {
    if (sourceIds.isEmpty) {
      return;
    }
    await (delete(sourceChecks)
          ..where(($SourceChecksTable table) => table.sourceId.isIn(sourceIds)))
        .go();
  }

  /// Enables or disables the discover page of row [id] — user state (ADR-0052 §决策 3).
  Future<void> setExploreEnabled({
    required int id,
    required bool isExploreEnabled,
  }) =>
      (update(
        bookSources,
      )..where(($BookSourcesTable table) => table.id.equals(id))).write(
        BookSourcesCompanion(isExploreEnabled: Value<bool>(isExploreEnabled)),
      );

  /// Enables or disables the discover page of every row in [ids] in one transaction.
  Future<void> setExploreEnabledFor(
    List<int> ids, {
    required bool isExploreEnabled,
  }) => transaction(() async {
    for (final int id in ids) {
      await setExploreEnabled(id: id, isExploreEnabled: isExploreEnabled);
    }
  });

  /// Moves every id in [ids] to the top or the bottom of the manual order.
  ///
  /// It builds the new order from the **manual** order (not the one currently displayed), moves the
  /// selected rows as one block, and reuses [reorder]'s whole-list renumbering: two rows that share
  /// a `customOrder` have no defined swap (ADR-0045 §决策 3).
  Future<void> moveToEdge(List<int> ids, {required bool toTop}) async {
    if (ids.isEmpty) {
      return;
    }
    final Set<int> movingIds = ids.toSet();
    final List<BookSourceRow> rows =
        await (select(bookSources)
              ..orderBy(<OrderClauseGenerator<$BookSourcesTable>>[
                ($BookSourcesTable table) =>
                    OrderingTerm(expression: table.customOrder),
                ($BookSourcesTable table) => OrderingTerm(expression: table.id),
              ]))
            .get();
    final List<int> moving = <int>[
      for (final BookSourceRow row in rows)
        if (movingIds.contains(row.id)) row.id,
    ];
    final List<int> rest = <int>[
      for (final BookSourceRow row in rows)
        if (!movingIds.contains(row.id)) row.id,
    ];

    await reorder(<int>[if (toTop) ...moving, ...rest, if (!toTop) ...moving]);
  }

  /// Enables or disables row [id] — user state, so only the UI calls this.
  Future<void> setEnabled({required int id, required bool isEnabled}) =>
      (update(bookSources)
            ..where(($BookSourcesTable table) => table.id.equals(id)))
          .write(BookSourcesCompanion(isEnabled: Value<bool>(isEnabled)));

  /// Enables or disables every row in [ids] in **one transaction** (ADR-0050 §决策 2).
  Future<void> setEnabledFor(List<int> ids, {required bool isEnabled}) =>
      transaction(() async {
        for (final int id in ids) {
          await setEnabled(id: id, isEnabled: isEnabled);
        }
      });

  /// Deletes every row in [ids] in one transaction and answers how many went away.
  Future<int> deleteByIds(List<int> ids) => transaction(() async {
    await deleteChecksOf(ids);
    var deleted = 0;
    for (final int id in ids) {
      deleted += await deleteById(id);
    }

    return deleted;
  });

  /// Replaces the stored payload of [id] — the **edit** path (ADR-0050 §决策 3).
  ///
  /// The identity columns move with it, because editing a URL or a rule changes the fingerprint:
  /// what must not move is user state (`isEnabled` / `customOrder`). The caller has already
  /// validated the payload and checked that the new identity does not collide with another row.
  Future<void> updatePayload({
    required int id,
    required String url,
    required String fingerprint,
    required String payload,
    required String name,
    required int sourceType,
    required int weight,
    required int? lastUpdateTime,
  }) =>
      (update(
        bookSources,
      )..where(($BookSourcesTable table) => table.id.equals(id))).write(
        BookSourcesCompanion(
          url: Value<String>(url),
          fingerprint: Value<String>(fingerprint),
          payload: Value<String>(payload),
          name: Value<String>(name),
          sourceType: Value<int>(sourceType),
          weight: Value<int>(weight),
          lastUpdateTime: Value<int?>(lastUpdateTime),
          updatedAt: Value<DateTime>(_clock.now()),
        ),
      );

  /// Deletes row [id] and reports how many rows went away (0 or 1).
  Future<int> deleteById(int id) => transaction(() async {
    await deleteChecksOf(<int>[id]);

    return (delete(
      bookSources,
    )..where(($BookSourcesTable table) => table.id.equals(id))).go();
  });

  /// Deletes every row and its history, returning how many sources were removed.
  Future<int> deleteAll() => transaction(() async {
    await delete(sourceChecks).go();

    return delete(bookSources).go();
  });
}
