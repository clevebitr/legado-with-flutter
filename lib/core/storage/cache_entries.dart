// coverage:ignore-file
import 'package:drift/drift.dart';

/// Cached network payloads with a time-to-live.
///
/// The key is a digest, so the table cannot leak what the user requested.
@TableIndex(name: 'cache_entries_source', columns: {#sourceKey})
class CacheEntries extends Table {
  /// Stable digest of「书源 ID + 规则字段 + URL + 页码」.
  TextColumn get cacheKey => text()();

  /// The cached payload, for example a decoded page body.
  TextColumn get payload => text()();

  /// Instant after which the entry must be ignored and purged.
  DateTimeColumn get expiresAt => dateTime()();

  /// Digest of the book identity the entry belongs to, or `null` for older rows.
  ///
  /// Takes no part in the lookup key; it only supports per-book cache views.
  TextColumn get scopeKey => text().nullable()();

  /// Digest of the book source the entry came from (`ADR-0072 §决策 1`).
  ///
  /// Like [scopeKey] it is a view column, not part of the key: the per-source cache page counts and
  /// clears by it. `null` only for rows written before v10 — the migration drops those, so the
  /// page never shows a count it cannot justify.
  TextColumn get sourceKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{cacheKey};
}
