import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';

/// Everything one backup carries (`docs/dev/roadmap.md` M22, ADR-0073 §决策 1).
///
/// The rows are plain JSON objects keyed by **table column name** (`camelCase`): the domain moves
/// them, the data layer owns their shape, and neither reinterprets a column it does not know.
final class BackupContents {
  /// Creates the contents.
  const BackupContents({required this.tables, required this.preferences});

  /// One row list per table; a table that is present but empty maps to an empty list.
  final Map<BackupTable, List<Map<String, Object?>>> tables;

  /// The `shared_preferences` snapshot: setting key → primitive value.
  ///
  /// Carried whole on purpose (`ADR-0073` §决策 4): the backup feature never learns a `settings.*`
  /// or `reader.*` key name, so a setting added later is backed up without touching this feature.
  final Map<String, Object?> preferences;

  /// How many rows [table] holds.
  int countOf(BackupTable table) => tables[table]?.length ?? 0;

  /// How many rows the whole backup holds, which is what the page reports after an export.
  int get totalRows => tables.values.fold(
    0,
    (int sum, List<Map<String, Object?>> rows) => sum + rows.length,
  );
}
