// coverage:ignore-file
import 'package:drift/drift.dart';

/// Cached network payloads with a time-to-live (C-NET-6).
///
/// 本文件是 **drift 代码生成器的输入**：列 getter 与 `primaryKey` 只在生成期被分析，
/// 运行时不可达（drift 源码 `lib/src/dsl/columns.dart` 明确写着这些方法
/// 「not meant to be called at runtime」，`ColumnBuilder` 甚至是空标记类）。
/// 因此它按 ADR-0019 登记在 `tool/coverage_allowlist.txt` 中豁免；表结构的正确性
/// 由 `test/core/storage/migration_test.dart` 与 `drift_schemas/` 的比对保证。
///
/// The key is a digest, never the URL itself, so the table cannot leak what the
/// user requested; see `cacheKeyFor`.
class CacheEntries extends Table {
  /// Stable digest of「书源 ID + 规则字段 + URL + 页码」.
  TextColumn get cacheKey => text()();

  /// The cached payload, for example a decoded page body.
  TextColumn get payload => text()();

  /// Instant after which the entry must be ignored and purged.
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{cacheKey};
}
