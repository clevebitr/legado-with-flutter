import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/cache_entries.dart';
import 'package:flutter_reader/core/storage/cache_key.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';

part 'cache_dao.g.dart';

/// Time-to-live cache for network payloads.
///
/// Expired entries read as misses; [deleteExpired] purges them.
@DriftAccessor(tables: <Type>[CacheEntries])
class CacheDao extends DatabaseAccessor<ReaderDatabase> with _$CacheDaoMixin {
  /// Creates the DAO with an injected clock.
  CacheDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Stores [payload] for the request described by the other arguments.
  ///
  /// An existing entry for the same request is replaced, so [ttl] counts from this write.
  Future<void> put({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
    required String payload,
    required Duration ttl,
    String? scopeKey,
  }) async {
    await into(cacheEntries).insertOnConflictUpdate(
      CacheEntriesCompanion.insert(
        cacheKey: cacheKeyFor(
          sourceId: sourceId,
          ruleField: ruleField,
          url: url,
          page: page,
        ),
        payload: payload,
        expiresAt: _clock.now().add(ttl),
        scopeKey: Value<String?>(scopeKey),
      ),
    );
  }

  /// Returns the cached payload, or `null` when it is missing or expired.
  Future<String?> get({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
  }) async {
    final CacheEntry? entry =
        await (select(cacheEntries)..where(
              (CacheEntries table) => table.cacheKey.equals(
                cacheKeyFor(
                  sourceId: sourceId,
                  ruleField: ruleField,
                  url: url,
                  page: page,
                ),
              ),
            ))
            .getSingleOrNull();

    if (entry == null || !entry.expiresAt.isAfter(_clock.now())) {
      return null;
    }

    return entry.payload;
  }

  /// Deletes every expired entry and returns how many rows were removed.
  Future<int> deleteExpired() =>
      (delete(cacheEntries)..where(
            (CacheEntries table) =>
                table.expiresAt.isSmallerOrEqualValue(_clock.now()),
          ))
          .go();

  /// Counts the entries written for one book.
  ///
  /// [scopeKey] comes from [cacheScopeKeyFor], so the count needs no URL.
  Future<int> countByScope(String scopeKey) async {
    final QueryRow row = await customSelect(
      'SELECT COUNT(*) AS c FROM ${cacheEntries.actualTableName} '
      'WHERE scope_key = ?',
      variables: <Variable<Object>>[Variable<String>(scopeKey)],
    ).getSingle();

    return row.data['c'] as int? ?? 0;
  }

  /// Deletes one book's entries and returns how many rows were removed.
  Future<int> deleteByScope(String scopeKey) => (delete(
    cacheEntries,
  )..where((CacheEntries table) => table.scopeKey.equals(scopeKey))).go();

  /// Deletes **every** entry and returns how many rows were removed.
  Future<int> deleteAll() => delete(cacheEntries).go();
}
