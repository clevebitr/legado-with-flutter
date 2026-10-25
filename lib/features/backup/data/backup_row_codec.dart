/// Typed reads of one row of a backup file (`docs/dev/roadmap.md` M22, ADR-0073 §决策 2).
///
/// Every reader either answers a value of the right type or throws [BadBackupRow]; the repository
/// catches that per row and counts it as `skipped`, so one bad entry cannot drop a whole table
/// (ADR-0073 §决策 3). A missing mandatory column is an error; a missing optional one is `null`.
library;

/// A row this build cannot use: a missing identity column, or a value of the wrong type.
final class BadBackupRow implements Exception {
  /// Creates the failure for [column].
  const BadBackupRow(this.column);

  /// The column that could not be read.
  final String column;

  @override
  String toString() => 'BadBackupRow($column)';
}

/// Reads the mandatory text [column].
String stringOf(Map<String, Object?> row, String column) {
  final Object? value = row[column];
  if (value is! String) {
    throw BadBackupRow(column);
  }

  return value;
}

/// Reads the optional text [column]; a value of another type is still an error.
String? optionalStringOf(Map<String, Object?> row, String column) {
  final Object? value = row[column];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw BadBackupRow(column);
  }

  return value;
}

/// Reads the optional integer [column].
int? optionalIntOf(Map<String, Object?> row, String column) {
  final Object? value = row[column];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw BadBackupRow(column);
  }

  return value;
}

/// Reads the optional flag [column], falling back to [fallback] when absent.
bool optionalBoolOf(
  Map<String, Object?> row,
  String column, {
  required bool fallback,
}) {
  final Object? value = row[column];
  if (value == null) {
    return fallback;
  }
  if (value is! bool) {
    throw BadBackupRow(column);
  }

  return value;
}

/// Reads the mandatory ISO-8601 instant [column].
DateTime dateOf(Map<String, Object?> row, String column) {
  final DateTime? value = _parseDate(row[column], column);
  if (value == null) {
    throw BadBackupRow(column);
  }

  return value;
}

/// Reads the optional ISO-8601 instant [column].
DateTime? optionalDateOf(Map<String, Object?> row, String column) =>
    _parseDate(row[column], column);

DateTime? _parseDate(Object? value, String column) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw BadBackupRow(column);
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw BadBackupRow(column);
  }

  return parsed;
}

/// Writes one instant as the ISO-8601 UTC text the format uses.
///
/// Drift stores seconds, so this keeps the instant and drops nothing a round trip could notice.
String dateToJson(DateTime instant) => instant.toUtc().toIso8601String();
