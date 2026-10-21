import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/features/settings/domain/repositories/settings_repository.dart';

/// [CachePurger] on top of the TTL cache (`docs/dev/roadmap.md` 5.6 / 5.7 ①)。
///
/// A full purge needs no schema change: every cache row is derived data, so the DAO's
/// `deleteAll` is the whole operation. Purging by book source (5.7 ②) would need a new column
/// and waits for a real requirement.
final class CacheDaoCachePurger implements CachePurger {
  /// Creates the purger.
  const CacheDaoCachePurger(this._dao);

  final CacheDao _dao;

  @override
  Future<int> purgeAll() => _dao.deleteAll();
}
