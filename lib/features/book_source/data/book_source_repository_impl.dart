import 'dart:convert';

import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/features/book_source/domain/book_source_fingerprint.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
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
  Future<List<StoredBookSource>> getAll() async {
    final List<StoredBookSource> sources = <StoredBookSource>[];
    for (final BookSourceRow row in await _dao.findAll()) {
      final StoredBookSource? stored = _toStored(row);
      if (stored != null) {
        sources.add(stored);
      }
    }

    return sources;
  }

  @override
  Future<StoredBookSource?> findById(int id) async {
    final BookSourceRow? row = await _dao.findById(id);

    return row == null ? null : _toStored(row);
  }

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

    await _dao.writeCheckState(
      id: id,
      groupName: report.invalidGroups.isEmpty
          ? groups
          : withGroups(groups, report.invalidGroups),
      comment: errorComment == null
          ? comment
          : withErrorComment(comment, errorComment),
      respondTime: report.elapsedMillis,
    );

    return true;
  }

  @override
  Future<void> delete(int id) async {
    await _dao.deleteById(id);
  }

  /// Turns one row into a [StoredBookSource], or `null` plus a warning when its payload is broken.
  ///
  /// A row whose payload no longer parses is a **data defect** (the importer only stores what it
  /// validated), so it is skipped — one bad row must not cost the whole source list — and the
  /// warning names the row and its URL, never the payload (C-SEC-4, C-ERR-8). Only nameable
  /// exceptions are caught: storage failures keep travelling (C-ERR-2, ADR-0033 §决策 1).
  StoredBookSource? _toStored(BookSourceRow row) {
    final Object? decoded;
    try {
      decoded = jsonDecode(row.payload);
    } on FormatException {
      return _skip(row, 'the stored payload is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      return _skip(row, 'the stored payload is not a JSON object');
    }

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
      customOrder: row.customOrder,
      importedAt: row.importedAt,
    );
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
