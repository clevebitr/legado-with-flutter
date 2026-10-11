import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/cache_entries.dart';
import 'package:flutter_reader/core/storage/cache_key.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';

part 'cache_dao.g.dart';

/// Time-to-live cache for network payloads (C-NET-6).
///
/// Every entry carries an expiry, reads treat an expired entry as a miss and
/// [deleteExpired] removes them, so the cache can never grow without bound.
@DriftAccessor(tables: <Type>[CacheEntries])
class CacheDao extends DatabaseAccessor<ReaderDatabase> with _$CacheDaoMixin {
  /// Creates the DAO; `clock` decides when an entry has expired
  /// (`docs/dev/testing.md` §4).
  CacheDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Stores [payload] for the request described by the other arguments.
  ///
  /// An existing entry for the same request is replaced, so [ttl] always counts
  /// from the moment of the write.
  Future<void> put({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
    required String payload,
    required Duration ttl,
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
}
