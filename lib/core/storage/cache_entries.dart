// coverage:ignore-file
import 'package:drift/drift.dart';

/// Cached network payloads with a time-to-live.
///
/// The key is a digest, so the table cannot leak what the user requested.
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

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{cacheKey};
}
