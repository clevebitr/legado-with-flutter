import 'dart:convert';

import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/features/book_source/domain/book_source_fingerprint.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:json_annotation/json_annotation.dart';

/// Drift-backed [BookSourceRepository] — the first real consumer of `data/` (ADR-0021 复审注记).
///
/// It owns the identity decision of ADR-0040 §决策 3 and nothing else: the DAO keeps the row
/// shape and the ordering, this class decides "same source" (via [bookSourceFingerprint]) and
/// turns rows into [StoredBookSource]s.
final class BookSourceRepositoryImpl implements BookSourceRepository {
  /// Creates the repository.
  const BookSourceRepositoryImpl({required this._dao, required this._logger});

  final BookSourceDao _dao;
  final AppLogger _logger;

  @override
  Future<List<StoredBookSource>> getAll({
    BookSourceSortOrder order = BookSourceSortOrder.defaultOrder,
    bool ascending = true,
  }) async {
    final List<BookSourceRow> rows = await _dao.findAll(
      order: order,
      ascending: ascending,
    );
    // 一次读出每个源的最近结论，再逐行合并：不要为每行发一条查询（C-PERF-6）。
    final Map<int, SourceCheckRecord> latest = await latestChecks();
    final List<StoredBookSource> sources = <StoredBookSource>[];
    for (final BookSourceRow row in rows) {
      final StoredBookSource? stored = _toStored(
        row,
        lastCheck: latest[row.id],
      );
      if (stored != null) {
        sources.add(stored);
      }
    }

    return sources;
  }

  @override
  Future<Map<int, SourceCheckRecord>> latestChecks() async {
    final Map<int, SourceCheckRow> rows = await _dao.latestChecks(
      // 取消不算结论：传入领域枚举的名字，以免 core 反向依赖 features（architecture §2）。
      excludedStatus: SourceCheckStatus.cancelled.name,
    );

    return <int, SourceCheckRecord>{
      for (final MapEntry<int, SourceCheckRow> entry in rows.entries)
        entry.key: _toRecord(entry.value),
    };
  }

  @override
  Future<StoredBookSource?> findById(int id) async {
    final BookSourceRow? row = await _dao.findById(id);

    return row == null ? null : _toStored(row);
  }

  @override
  Future<bool> exists({
    required String url,
    required String fingerprint,
  }) async =>
      await _dao.findIdentity(url: url, fingerprint: fingerprint) != null;

  @override
  Future<BookSourceSaveReport> saveAll(
    List<Map<String, Object?>> entries,
  ) async {
    var inserted = 0;
    var refreshed = 0;

    for (final Map<String, Object?> entry in entries) {
      final String url = _text(entry['bookSourceUrl']);
      final String fingerprint = bookSourceFingerprint(entry);
      final String payload = jsonEncode(entry);
      final BookSourceRow? stored = await _dao.findIdentity(
        url: url,
        fingerprint: fingerprint,
      );

      if (stored == null) {
        await _dao.insertNew(
          url: url,
          fingerprint: fingerprint,
          payload: payload,
          name: _text(entry['bookSourceName']),
          groupName: _textOrNull(entry['bookSourceGroup']),
          sourceType: _number(entry['bookSourceType']),
          // `enabled` 只在**新建行**时按负载初始化；既有行的这一列属用户态（ADR-0040 §决策 3）。
          isEnabled: entry['enabled'] is bool ? entry['enabled'] as bool : true,
          customOrder: _number(entry['customOrder']),
          weight: _number(entry['weight']),
          lastUpdateTime: _numberOrNull(entry['lastUpdateTime']),
          respondTime: _numberOrNull(entry['respondTime']),
          // 探索开关的初值来自负载，之后只由用户改（ADR-0040 §决策 3、ADR-0052 §决策 3）。
          isExploreEnabled: entry['enabledExplore'] is bool
              ? entry['enabledExplore'] as bool
              : true,
        );
        inserted++;
      } else {
        await _dao.refreshPayload(id: stored.id, payload: payload);
        refreshed++;
      }
    }

    return BookSourceSaveReport(inserted: inserted, refreshed: refreshed);
  }

  @override
  Future<void> setEnabled({required int id, required bool isEnabled}) =>
      _dao.setEnabled(id: id, isEnabled: isEnabled);

  @override
  Future<void> reorder(List<int> orderedIds) => _dao.reorder(orderedIds);

  @override
  Future<bool> applyCheckReport({
    required int id,
    required SourceCheckReport report,
  }) async {
    final BookSourceRow? row = await _dao.findById(id);
    if (row == null) {
      _logger.warning(
        'Book source check result has no row to land on: id=$id.',
      );

      return false;
    }

    // 合并针对**列**而不是负载：负载是导入原文（ADR-0040 §决策 4），本轮该被清掉的分组
    // 只能从列里看出来。顺序也是有意的 —— 先清掉上次的失效分组与错误注释，再加本轮的，
    // 这样重复校验不会累积分组（ADR-0043 §后果）。
    final String? groups = withoutInvalidGroups(row.groupName);
    final String? comment = withoutErrorComment(row.comment);
    final String? errorComment = report.errorComment;

    // 列与历史在同一个事务里写（DAO.applyCheck）：状态灯读历史，分组轴读列，
    // 两处不一致会让同一源出现两个结论（ADR-0052 §决策 1）。
    await _dao.applyCheck(
      id: id,
      groupName: report.invalidGroups.isEmpty
          ? groups
          : withGroups(groups, report.invalidGroups),
      comment: errorComment == null
          ? comment
          : withErrorComment(comment, errorComment),
      respondTime: report.elapsedMillis,
      status: report.status.name,
      invalidGroups: report.invalidGroups.isEmpty
          ? null
          : joinGroups(report.invalidGroups),
      errorComment: errorComment,
      elapsedMillis: report.elapsedMillis,
    );

    return true;
  }

  @override
  Future<void> delete(int id) async {
    await _dao.deleteById(id);
  }

  @override
  Future<String?> payloadOf(int id) async {
    final BookSourceRow? row = await _dao.findById(id);

    return row?.payload;
  }

  @override
  Future<void> setEnabledFor(List<int> ids, {required bool isEnabled}) =>
      _dao.setEnabledFor(ids, isEnabled: isEnabled);

  @override
  Future<void> deleteMany(List<int> ids) async {
    await _dao.deleteByIds(ids);
  }

  @override
  Future<void> setExploreEnabledFor(
    List<int> ids, {
    required bool isExploreEnabled,
  }) => _dao.setExploreEnabledFor(ids, isExploreEnabled: isExploreEnabled);

  @override
  Future<void> moveToEdge(List<int> ids, {required bool toTop}) =>
      _dao.moveToEdge(ids, toTop: toTop);

  @override
  Future<void> renameGroup(String from, String to) async {
    final String target = to.trim();
    if (target.isEmpty || target == from) {
      return;
    }
    for (final BookSourceRow row in await _dao.findAll()) {
      await _rewriteGroups(
        row,
        (List<String> names) => <String>[
          for (final String name in names)
            if (name == from) target else name,
        ],
      );
    }
  }

  @override
  Future<void> deleteGroup(String group) async {
    for (final BookSourceRow row in await _dao.findAll()) {
      await _rewriteGroups(
        row,
        (List<String> names) => <String>[
          for (final String name in names)
            if (name != group) name,
        ],
      );
    }
  }

  @override
  Future<void> removeFromGroup(List<int> ids, String group) async {
    for (final int id in ids) {
      final BookSourceRow? row = await _dao.findById(id);
      if (row == null) {
        continue;
      }
      await _rewriteGroups(
        row,
        (List<String> names) => <String>[
          for (final String name in names)
            if (name != group) name,
        ],
      );
    }
  }

  /// Rewrites the user group of [row] through [change], preserving every other payload key.
  ///
  /// An unchanged token list is a no-op: group operations are expressed as "map the list", so
  /// renaming a group onto itself or removing a group the row does not carry must not bump
  /// `updatedAt` (ADR-0050 §决策 1).
  Future<void> _rewriteGroups(
    BookSourceRow row,
    List<String> Function(List<String> names) change,
  ) async {
    final Map<String, Object?>? payload = _payloadOf(row);
    if (payload == null) {
      return;
    }
    final Object? raw = payload['bookSourceGroup'];
    final List<String> current = splitGroups(raw is String ? raw : null);
    final List<String> next = change(current);
    if (next.length == current.length && next.every(current.contains)) {
      return;
    }
    final Map<String, Object?> updated = Map<String, Object?>.of(payload);
    if (next.isEmpty) {
      updated.remove('bookSourceGroup');
    } else {
      updated['bookSourceGroup'] = joinGroups(next);
    }
    await _dao.updatePayload(
      id: row.id,
      url: row.url,
      fingerprint: row.fingerprint,
      payload: jsonEncode(updated),
      name: row.name,
      sourceType: row.sourceType,
      weight: row.weight,
      lastUpdateTime: row.lastUpdateTime,
    );
  }

  @override
  Future<void> setGroupFor(List<int> ids, String? group) async {
    for (final int id in ids) {
      final BookSourceRow? row = await _dao.findById(id);
      if (row == null) {
        continue;
      }
      final Map<String, Object?>? payload = _payloadOf(row);
      if (payload == null) {
        continue;
      }
      // 只动 `bookSourceGroup`：其余键（包括未建模的 extra）逐字保留，导出仍然保真。
      final Map<String, Object?> next = Map<String, Object?>.of(payload);
      if (group == null || group.isEmpty) {
        next.remove('bookSourceGroup');
      } else {
        next['bookSourceGroup'] = group;
      }
      await _dao.updatePayload(
        id: id,
        url: row.url,
        fingerprint: row.fingerprint,
        payload: jsonEncode(next),
        name: row.name,
        sourceType: row.sourceType,
        weight: row.weight,
        lastUpdateTime: row.lastUpdateTime,
      );
    }
  }

  @override
  Future<BookSourceEditOutcome> update({
    required int id,
    required Map<String, Object?> entry,
  }) async {
    final BookSourceRow? row = await _dao.findById(id);
    if (row == null) {
      return BookSourceEditOutcome.sourceMissing;
    }

    final String url = _text(entry['bookSourceUrl']);
    final String fingerprint = bookSourceFingerprint(entry);
    final BookSourceRow? colliding = await _dao.findIdentity(
      url: url,
      fingerprint: fingerprint,
    );
    if (colliding != null && colliding.id != id) {
      // 身份冲突是显式失败：合并会删掉用户可能正在用的那一行，共存会撞唯一索引
      // （ADR-0050 §决策 3）。名字写进日志供排查，界面自己再提示一次。
      _logger.warning(
        'Book source edit would duplicate an existing row: edited=$id '
        'existing=${colliding.id} url=$url',
      );

      return BookSourceEditOutcome.identityConflict;
    }

    await _dao.updatePayload(
      id: id,
      url: url,
      fingerprint: fingerprint,
      payload: jsonEncode(entry),
      name: _text(entry['bookSourceName']),
      sourceType: _number(entry['bookSourceType']),
      weight: _number(entry['weight']),
      lastUpdateTime: _numberOrNull(entry['lastUpdateTime']),
    );

    return BookSourceEditOutcome.saved;
  }

  /// The stored payload of [row] as a map, or `null` plus a warning when it no longer parses.
  Map<String, Object?>? _payloadOf(BookSourceRow row) {
    final Object? decoded;
    try {
      decoded = jsonDecode(row.payload);
    } on FormatException {
      _skip(row, 'the stored payload is not JSON');

      return null;
    }
    if (decoded is! Map<String, Object?>) {
      _skip(row, 'the stored payload is not a JSON object');

      return null;
    }

    return decoded;
  }

  /// Turns one row into a [StoredBookSource], or `null` plus a warning when its payload is broken.
  ///
  /// A row whose payload no longer parses is a **data defect** (the importer only stores what it
  /// validated), so it is skipped — one bad row must not cost the whole source list — and the
  /// warning names the row and its URL, never the payload (C-SEC-4, C-ERR-8). Only nameable
  /// exceptions are caught: storage failures keep travelling (C-ERR-2, ADR-0033 §决策 1).
  StoredBookSource? _toStored(
    BookSourceRow row, {
    SourceCheckRecord? lastCheck,
  }) {
    final Map<String, Object?>? decodedPayload = _payloadOf(row);
    if (decodedPayload == null) {
      return null;
    }
    final Map<String, Object?> decoded = decodedPayload;

    final BookSource source;
    try {
      source = BookSource.fromLegadoJson(decoded);
    } on CheckedFromJsonException {
      return _skip(row, 'the stored payload no longer parses');
    }

    return StoredBookSource(
      id: row.id,
      // 用户态以列为准：负载里那份可能在导入后被用户改过。
      source: source.copyWith(isEnabled: row.isEnabled),
      isEnabled: row.isEnabled,
      isExploreEnabled: row.isExploreEnabled,
      customOrder: row.customOrder,
      importedAt: row.importedAt,
      // 校验结果写的是列（ADR-0043 §决策 1），所以列投影必须一起交给界面，
      // 否则列表永远显示校验之前的分组 / 注释（ADR-0045 §决策 1）。
      groupName: row.groupName,
      lastCheck: lastCheck,
      lastUpdateTime: row.lastUpdateTime,
      respondTime: row.respondTime,
      weight: row.weight,
      comment: row.comment,
    );
  }

  /// Maps a stored history row onto the domain projection.
  ///
  /// An unknown status name (a database written by a newer build) becomes `cancelled`: it carries
  /// no verdict, which is exactly what "I cannot read this run" should look like — never a green
  /// light (ADR-0052 §决策 2).
  SourceCheckRecord _toRecord(SourceCheckRow row) => SourceCheckRecord(
    sourceId: row.sourceId,
    checkedAt: row.checkedAt,
    status: _statusOf(row.status),
    elapsedMillis: row.elapsedMillis,
    invalidGroups: splitGroups(row.invalidGroups),
    errorComment: row.errorComment,
  );

  /// Maps a stored status name onto [SourceCheckStatus].
  SourceCheckStatus _statusOf(String stored) {
    for (final SourceCheckStatus status in SourceCheckStatus.values) {
      if (status.name == stored) {
        return status;
      }
    }

    return SourceCheckStatus.cancelled;
  }

  /// Logs the skipped row and answers “no source”.
  StoredBookSource? _skip(BookSourceRow row, String reason) {
    _logger.warning(
      'Stored book source ${row.id} (${row.url}) was skipped: $reason.',
    );

    return null;
  }
}

/// A non-empty [String] projection, or `''` when the raw value is missing or of another type.
String _text(Object? value) => value is String ? value : '';

/// A nullable [String] projection.
String? _textOrNull(Object? value) => value is String ? value : null;

/// An `int` projection, or 0 when the raw value is missing or of another type.
int _number(Object? value) => value is int ? value : 0;

/// A nullable `int` projection.
int? _numberOrNull(Object? value) => value is int ? value : null;
