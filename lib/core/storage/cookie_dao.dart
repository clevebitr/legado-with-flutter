import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/cookies.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/utils/clock.dart';

part 'cookie_dao.g.dart';

/// Row-level access to the persisted cookie jar.
///
/// Keyed by `(domain, path, name)`; expiry is judged by the caller.
@DriftAccessor(tables: <Type>[Cookies])
class CookieDao extends DatabaseAccessor<ReaderDatabase> with _$CookieDaoMixin {
  /// Creates the DAO with an injected clock.
  CookieDao(super.attachedDatabase, {required this._clock});

  final Clock _clock;

  /// Every stored cookie, ordered for a stable test and a predictable log.
  Future<List<CookieRow>> findAll() =>
      (select(cookies)..orderBy(<OrderClauseGenerator<$CookiesTable>>[
            ($CookiesTable table) => OrderingTerm.asc(table.domain),
            ($CookiesTable table) => OrderingTerm.asc(table.path),
            ($CookiesTable table) => OrderingTerm.asc(table.name),
          ]))
          .get();

  /// Inserts or replaces one cookie (same domain / path / name).
  Future<void> upsert({
    required String domain,
    required String path,
    required String name,
    required String value,
    required bool isSecure,
    required DateTime? expiresAt,
  }) => into(cookies).insert(
    CookiesCompanion.insert(
      domain: domain,
      path: path,
      name: name,
      value: value,
      isSecure: Value<bool>(isSecure),
      expiresAt: Value<DateTime?>(expiresAt),
      createdAt: _clock.now(),
    ),
    onConflict: DoUpdate(
      ($CookiesTable _) => CookiesCompanion(
        value: Value<String>(value),
        isSecure: Value<bool>(isSecure),
        expiresAt: Value<DateTime?>(expiresAt),
        createdAt: Value<DateTime>(_clock.now()),
      ),
      // 冲突目标就是表上的唯一键：同一 (domain, path, name) 只留一行。
      target: <Column<Object>>[cookies.domain, cookies.path, cookies.name],
    ),
  );

  /// Deletes the cookie identified by [domain] / [path] / [name].
  Future<int> deleteOne({
    required String domain,
    required String path,
    required String name,
  }) =>
      (delete(cookies)..where(
            ($CookiesTable table) =>
                table.domain.equals(domain) &
                table.path.equals(path) &
                table.name.equals(name),
          ))
          .go();

  /// Deletes every cookie that has expired at [now], and answers how many went away.
  Future<int> deleteExpired(DateTime now) =>
      (delete(cookies)..where(
            ($CookiesTable table) => table.expiresAt.isSmallerOrEqualValue(now),
          ))
          .go();

  /// Deletes the whole jar (settings' "clear cache" and tests).
  Future<int> deleteAll() => delete(cookies).go();
}
