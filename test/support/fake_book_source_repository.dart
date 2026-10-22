import 'dart:convert';

import 'package:flutter_reader/features/book_source/domain/book_source_fingerprint.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';

/// In-memory [BookSourceRepository] double for the notifier and widget tests
/// (`docs/dev/testing.md` §4).
///
/// It keeps the three parts of the port's contract the UI depends on, so a test that passes here
/// says something about production:
///
/// * rows come back in the shared order — enabled first, then `customOrder`, then `id`
///   (ADR-0040 §决策 3);
/// * re-importing the same identity refreshes instead of adding a row, and the identity is the
///   **real** `bookSourceFingerprint`, so the double cannot invent a rule the domain does not have;
/// * `enabled` / `customOrder` are user state that an import never overwrites.
final class FakeBookSourceRepository implements BookSourceRepository {
  final Map<int, StoredBookSource> _rows = <int, StoredBookSource>{};

  /// Identity (`url|fingerprint`) to row id, the in-memory stand-in for the unique key.
  final Map<String, int> _identities = <String, int>{};

  int _nextId = 1;

  /// The timestamps new rows get; a test can pin them for an assertion.
  DateTime importedAt = DateTime.utc(2026, 10, 14);

  /// When true, [getAll] throws, so a test can pin the pages' load-failure state
  /// (a storage failure is the one thing the port lets through as an exception).
  bool failReads = false;

  /// Seeds one stored source and returns it.
  StoredBookSource add({
    required BookSource source,
    bool isEnabled = true,
    int customOrder = 0,
    String? groupName,
    int? lastUpdateTime,
    int? respondTime,
    int? weight,
    String? comment,
  }) {
    final StoredBookSource stored = StoredBookSource(
      id: _nextId++,
      source: source,
      isEnabled: isEnabled,
      customOrder: customOrder,
      importedAt: importedAt,
      groupName: groupName,
      lastUpdateTime: lastUpdateTime,
      respondTime: respondTime,
      weight: weight,
      comment: comment,
    );
    _rows[stored.id] = stored;
    _identities[_identityOf(source)] = stored.id;

    return stored;
  }

  /// Every row, in the order the port promises.
  @override
  Future<List<StoredBookSource>> getAll({
    BookSourceSortOrder order = BookSourceSortOrder.defaultOrder,
  }) async {
    if (failReads) {
      throw Exception('stored book sources could not be read');
    }
    int byPrimary(StoredBookSource a, StoredBookSource b) => switch (order) {
      BookSourceSortOrder.defaultOrder => 0,
      BookSourceSortOrder.weight => (b.weight ?? 0).compareTo(a.weight ?? 0),
      // 「从未校验」排最后，而不是当 0 ms（ADR-0045 §决策 2）。
      BookSourceSortOrder.respondTime => switch ((
        a.respondTime,
        b.respondTime,
      )) {
        (final int left, final int right) => left.compareTo(right),
        (final int _, null) => -1,
        (null, final int _) => 1,
        (null, null) => 0,
      },
      BookSourceSortOrder.name => a.source.name.compareTo(b.source.name),
    };

    final List<StoredBookSource> rows = _rows.values.toList()
      ..sort((StoredBookSource a, StoredBookSource b) {
        final int primary = byPrimary(a, b);
        if (primary != 0) {
          return primary;
        }
        if (a.isEnabled != b.isEnabled) {
          return a.isEnabled ? -1 : 1;
        }
        if (a.customOrder != b.customOrder) {
          return a.customOrder.compareTo(b.customOrder);
        }

        return a.id.compareTo(b.id);
      });

    return rows;
  }

  @override
  Future<StoredBookSource?> findById(int id) async => _rows[id];

  @override
  Future<BookSourceSaveReport> saveAll(
    List<Map<String, Object?>> entries,
  ) async {
    var inserted = 0;
    var refreshed = 0;

    for (final Map<String, Object?> entry in entries) {
      final String url = '${entry['bookSourceUrl']}';
      final String identity = '$url|${bookSourceFingerprint(entry)}';
      final int? existingId = _identities[identity];

      if (existingId == null) {
        final StoredBookSource stored = add(
          source: BookSource.fromLegadoJson(entry),
          isEnabled: entry['enabled'] is bool ? entry['enabled'] as bool : true,
          customOrder: entry['customOrder'] is int
              ? entry['customOrder'] as int
              : 0,
        );
        _identities[identity] = stored.id;
        inserted++;
      } else {
        // 身份相同 ⇒ 行为字段相同；只刷新时间，用户态不动（与 ADR-0040 §决策 3 一致）。
        final StoredBookSource row = _rows[existingId]!;
        _rows[existingId] = StoredBookSource(
          id: row.id,
          source: row.source,
          isEnabled: row.isEnabled,
          customOrder: row.customOrder,
          importedAt: row.importedAt,
        );
        refreshed++;
      }
    }

    return BookSourceSaveReport(inserted: inserted, refreshed: refreshed);
  }

  @override
  Future<void> setEnabled({required int id, required bool isEnabled}) async {
    final StoredBookSource? row = _rows[id];
    if (row == null) {
      return;
    }
    _rows[id] = StoredBookSource(
      id: row.id,
      source: row.source,
      isEnabled: isEnabled,
      customOrder: row.customOrder,
      importedAt: row.importedAt,
    );
  }

  @override
  Future<void> reorder(List<int> orderedIds) async {
    for (var index = 0; index < orderedIds.length; index++) {
      final StoredBookSource? row = _rows[orderedIds[index]];
      if (row == null) {
        continue;
      }
      _rows[row.id] = StoredBookSource(
        id: row.id,
        source: row.source,
        isEnabled: row.isEnabled,
        customOrder: index,
        importedAt: row.importedAt,
        groupName: row.groupName,
        lastUpdateTime: row.lastUpdateTime,
        respondTime: row.respondTime,
        weight: row.weight,
        comment: row.comment,
      );
    }
  }

  @override
  Future<bool> applyCheckReport({
    required int id,
    required SourceCheckReport report,
  }) async {
    final StoredBookSource? row = _rows[id];
    if (row == null) {
      return false;
    }
    // 真实适配器写的是**列**（ADR-0043 §决策 1）：替身也把结果落到行投影上，
    // 这样页面测试读到的就是同一份数据（ADR-0045 §决策 1）。
    final String? groups = withoutInvalidGroups(row.groupName);
    final String? comment = withoutErrorComment(row.comment);
    final String? note = report.errorComment;
    _rows[id] = StoredBookSource(
      id: row.id,
      source: row.source,
      isEnabled: row.isEnabled,
      customOrder: row.customOrder,
      importedAt: row.importedAt,
      groupName: report.invalidGroups.isEmpty
          ? groups
          : withGroups(groups, report.invalidGroups),
      lastUpdateTime: row.lastUpdateTime,
      respondTime: report.elapsedMillis,
      weight: row.weight,
      comment: note == null ? comment : withErrorComment(comment, note),
    );

    return true;
  }

  /// The group names row [id] currently carries — the `groupName` column.
  List<String> groupsOf(int id) => splitGroups(_rows[id]?.groupName);

  /// The error note row [id] currently carries — the `comment` column.
  String? commentOf(int id) => _rows[id]?.comment;

  /// The last `respondTime` written for row [id].
  int? respondTimeOf(int id) => _rows[id]?.respondTime;

  @override
  Future<void> delete(int id) async {
    _rows.remove(id);
    _identities.removeWhere((String _, int rowId) => rowId == id);
  }

  @override
  Future<String?> payloadOf(int id) async {
    final StoredBookSource? row = _rows[id];

    return row == null ? null : jsonEncode(row.source.toJson());
  }

  @override
  Future<void> setEnabledFor(List<int> ids, {required bool isEnabled}) async {
    for (final int id in ids) {
      await setEnabled(id: id, isEnabled: isEnabled);
    }
  }

  @override
  Future<void> deleteMany(List<int> ids) async {
    for (final int id in ids) {
      await delete(id);
    }
  }

  @override
  Future<void> setGroupFor(List<int> ids, String? group) async {
    for (final int id in ids) {
      final StoredBookSource? row = _rows[id];
      if (row == null) {
        continue;
      }
      // 分组是 payload 里的字段（ADR-0050 §决策 1）：替身改的是模型上的 `group`，
      // 身份（指纹）不动 —— 与真实适配器一致。
      _rows[id] = StoredBookSource(
        id: row.id,
        source: row.source.copyWith(group: group),
        isEnabled: row.isEnabled,
        customOrder: row.customOrder,
        importedAt: row.importedAt,
        groupName: row.groupName,
        lastUpdateTime: row.lastUpdateTime,
        respondTime: row.respondTime,
        weight: row.weight,
        comment: row.comment,
      );
    }
  }

  @override
  Future<BookSourceEditOutcome> update({
    required int id,
    required Map<String, Object?> entry,
  }) async {
    final StoredBookSource? row = _rows[id];
    if (row == null) {
      return BookSourceEditOutcome.sourceMissing;
    }
    final BookSource edited = BookSource.fromLegadoJson(entry);
    final String identity = _identityOf(edited);
    final int? owner = _identities[identity];
    if (owner != null && owner != id) {
      return BookSourceEditOutcome.identityConflict;
    }

    _identities.remove(_identityOf(row.source));
    _identities[identity] = id;
    _rows[id] = StoredBookSource(
      id: row.id,
      // 用户态以列为准（与真实适配器同一条口径）。
      source: edited.copyWith(isEnabled: row.isEnabled),
      isEnabled: row.isEnabled,
      customOrder: row.customOrder,
      importedAt: row.importedAt,
      groupName: row.groupName,
      lastUpdateTime: row.lastUpdateTime,
      respondTime: row.respondTime,
      weight: row.weight,
      comment: row.comment,
    );

    return BookSourceEditOutcome.saved;
  }

  /// The in-memory stand-in for the `(url, fingerprint)` unique key (ADR-0040 §决策 1).
  String _identityOf(BookSource source) =>
      '${source.url}|${bookSourceFingerprint(source.toJson())}';
}
