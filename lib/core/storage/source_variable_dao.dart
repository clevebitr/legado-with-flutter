import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/source_variables.dart';
import 'package:flutter_reader/core/utils/clock.dart';

part 'source_variable_dao.g.dart';

/// Row-level access to the per-source variable map (`ADR-0076 §决策 1`).
///
/// The map is small and always read whole, so the DAO offers「read them all」 rather than paging:
/// the sandbox seeds one job with the entire map of the source it runs for.
@DriftAccessor(tables: <Type>[SourceVariables])
class SourceVariableDao extends DatabaseAccessor<ReaderDatabase>
    with _$SourceVariableDaoMixin {
  /// Creates the DAO with an injected clock.
  SourceVariableDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Every variable [sourceUrl] holds, ordered by name for a stable test and a predictable log.
  Future<List<SourceVariableRow>> findAll(String sourceUrl) =>
      (select(sourceVariables)
            ..where(
              ($SourceVariablesTable table) =>
                  table.sourceUrl.equals(sourceUrl),
            )
            ..orderBy(<OrderClauseGenerator<$SourceVariablesTable>>[
              ($SourceVariablesTable table) => OrderingTerm.asc(table.name),
            ]))
          .get();

  /// Writes [value] under [name], replacing the previous one.
  Future<void> upsert({
    required String sourceUrl,
    required String name,
    required String value,
  }) => into(sourceVariables).insert(
    SourceVariablesCompanion.insert(
      sourceUrl: sourceUrl,
      name: name,
      value: value,
      updatedAt: _clock.now(),
    ),
    onConflict: DoUpdate(
      ($SourceVariablesTable _) => SourceVariablesCompanion(
        value: Value<String>(value),
        updatedAt: Value<DateTime>(_clock.now()),
      ),
      target: <Column<Object>>[sourceVariables.sourceUrl, sourceVariables.name],
    ),
  );

  /// Removes [name]; a missing row is not an error.
  Future<int> deleteOne({required String sourceUrl, required String name}) =>
      (delete(sourceVariables)..where(
            ($SourceVariablesTable table) =>
                table.sourceUrl.equals(sourceUrl) & table.name.equals(name),
          ))
          .go();

  /// Removes every variable of [sourceUrl]; used when the source itself is deleted.
  Future<int> deleteAll(String sourceUrl) =>
      (delete(sourceVariables)..where(
            ($SourceVariablesTable table) => table.sourceUrl.equals(sourceUrl),
          ))
          .go();
}
