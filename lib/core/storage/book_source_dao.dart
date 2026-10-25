import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/book_sources.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/source_checks.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';

part 'book_source_dao.g.dart';

/// Row-level access to the imported book sources.
///
/// Owns the storage shape, list order and re-import columns; identity rules live elsewhere.
@DriftAccessor(tables: <Type>[BookSources, SourceChecks])
class BookSourceDao extends DatabaseAccessor<ReaderDatabase>
    with _$BookSourceDaoMixin {
  /// Creates the DAO with an injected clock.
  BookSourceDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Every row in the order the source list uses: [order] first, then enabled,
  /// then manual and insertion order, with a stable id tie-break.
  Future<List<BookSourceRow>> findAll({
    BookSourceSortOrder order = BookSourceSortOrder.defaultOrder,
    bool ascending = true,
  }) {
    final OrderingMode mode = ascending ? OrderingMode.asc : OrderingMode.desc;

    // 手动序下禁用源始终排在启用源之后，避免列表把它压回底部。
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

  List<OrderClauseGenerator<$BookSourcesTable>> _primaryOrder(
    BookSourceSortOrder order,
    OrderingMode mode,
  ) => switch (order) {
    BookSourceSortOrder.defaultOrder =>
      const <OrderClauseGenerator<$BookSourcesTable>>[],
    BookSourceSortOrder.weight => <OrderClauseGenerator<$BookSourcesTable>>[
      ($BookSourcesTable table) =>
          OrderingTerm(expression: table.weight, mode: mode),
    ],
    BookSourceSortOrder.respondTime =>
      <OrderClauseGenerator<$BookSourcesTable>>[
        // 从未校验为 NULL，两个方向都排到最后。
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
  /// Renumbering is idempotent and skips ids that no longer exist.
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

  /// Writes the `loginUi` values of [id] (JSON text, `null` clears them).
  ///
  /// User state like `is_enabled`: only the login page writes it, and a re-import leaves it alone
  /// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
  Future<void> writeLoginInfo({required int id, required String? loginInfo}) =>
      (update(bookSources)
            ..where(($BookSourcesTable table) => table.id.equals(id)))
          .write(BookSourcesCompanion(loginInfo: Value<String?>(loginInfo)));

  /// Refreshes the stored payload of row [id] — the idempotent half of a re-import.
  ///
  /// Only `payload` and `updatedAt` change; user state and display metadata stay.
  Future<void> refreshPayload({required int id, required String payload}) =>
      (update(
        bookSources,
      )..where(($BookSourcesTable table) => table.id.equals(id))).write(
        BookSourcesCompanion(
          payload: Value<String>(payload),
          updatedAt: Value<DateTime>(_clock.now()),
        ),
      );

  /// Writes what a batch check found back onto row [id].
  ///
  /// The three columns describe one run, so they are written together.
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

  /// Writes one check back: the legacy columns and its history row, in one transaction.
  ///
  /// [status] is the domain enum's name and [invalidGroups] is already joined.
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

  // 历史只用于诊断，保留最新 checkHistoryLimit 行即可避免无限增长。
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

  /// The newest recorded check per source, ignoring [excludedStatus].
  ///
  /// [excludedStatus] is `cancelled`: a cancelled run says nothing about the source.
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

  /// Deletes the recorded checks of [sourceIds].
  Future<void> deleteChecksOf(List<int> sourceIds) async {
    if (sourceIds.isEmpty) {
      return;
    }
    await (delete(sourceChecks)
          ..where(($SourceChecksTable table) => table.sourceId.isIn(sourceIds)))
        .go();
  }

  /// Enables or disables the discover page of row [id].
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
  /// Builds the new order from the manual order and moves the selected rows as one block.
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

  /// Enables or disables row [id].
  Future<void> setEnabled({required int id, required bool isEnabled}) =>
      (update(bookSources)
            ..where(($BookSourcesTable table) => table.id.equals(id)))
          .write(BookSourcesCompanion(isEnabled: Value<bool>(isEnabled)));

  /// Enables or disables every row in [ids] in one transaction.
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

  /// Replaces the stored payload of [id] — the edit path.
  ///
  /// Identity columns move with it; user state (`isEnabled` / `customOrder`) does not.
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
