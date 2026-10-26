import 'package:flutter_reader/core/js/source_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/storage/cache_failure_absorber.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/source_variable_dao.dart';

/// [SourceVariableRepository] backed by the app database's `source_variables` table.
///
/// Every operation goes through [absorbCacheFailure]: a lost variable costs one extra fetch, and a
/// `@js:` rule must not fail over it (a variable is a crib sheet, not a record).
final class SourceVariableDaoRepository implements SourceVariableRepository {
  /// Creates the repository.
  const SourceVariableDaoRepository(this._dao, {required this._logger});

  final SourceVariableDao _dao;
  final AppLogger _logger;

  // 稳定字符串，便于在日志中检索。
  static const String _scope = 'Source variables';

  @override
  Future<Map<String, String>> read(String sourceUrl) async {
    final List<SourceVariableRow>? rows =
        await absorbCacheFailure<List<SourceVariableRow>>(
          () => _dao.findAll(sourceUrl),
          logger: _logger,
          scope: _scope,
          url: sourceUrl,
        );

    return <String, String>{
      for (final SourceVariableRow row in rows ?? const <SourceVariableRow>[])
        row.name: row.value,
    };
  }

  @override
  Future<void> write(String sourceUrl, Map<String, String?> values) async {
    for (final MapEntry<String, String?> entry in values.entries) {
      final String? value = entry.value;
      await absorbCacheFailure<bool>(
        () async {
          if (value == null) {
            await _dao.deleteOne(sourceUrl: sourceUrl, name: entry.key);
          } else {
            await _dao.upsert(
              sourceUrl: sourceUrl,
              name: entry.key,
              value: value,
            );
          }

          return true;
        },
        logger: _logger,
        scope: _scope,
        url: sourceUrl,
      );
    }
  }
}
