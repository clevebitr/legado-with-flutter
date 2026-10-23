import 'package:flutter_reader/core/network/cookie_manager.dart';

/// Persistence for the cookie jar.
///
/// Failures are swallowed: a lost cookie costs a re-login, never a request.
abstract interface class CookieStore {
  /// Every stored cookie, expired ones included.
  Future<List<StoredCookie>> loadAll();

  /// Inserts or replaces one cookie.
  Future<void> save(StoredCookie cookie);

  /// Removes the cookie identified by [cookie]'s domain / path / name.
  Future<void> remove(StoredCookie cookie);

  /// Deletes every expired cookie and answers how many went away.
  Future<int> deleteExpired(DateTime now);
}
