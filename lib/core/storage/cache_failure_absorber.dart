import 'package:drift/drift.dart'
    show DriftWrappedException, InvalidDataException;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';

/// Runs one cache operation and turns the database's failure surface into “no cache”.
///
/// A lost cache entry costs a detection or one request, never a page, so the failure is recorded at
/// `debug` level (the URL's digest and the error's digest, C-SEC-4) and reported as a miss.
///
/// **This is the single implementation point of that absorption.** Every cache adapter of the app
/// routes through it, which is what keeps the `on Exception` clause below existing exactly once:
/// C-ERR-2 allows that clause in the `presentation/` Notifiers alone, so a cache adapter may only
/// name what it can name. [scope] names the cache in the log line (`Charset cache`,
/// `Chapter cache`), so the line stays searchable without the adapter repeating the logger call.
///
/// `Error` stays **uncaught**, as ADR-0022 requires: a programming bug must not be filed under
/// “cache miss”.
///
/// **The `on Exception` clause is an exemption pinned by ADR-0033** — its revision note moved the
/// anchor from `CacheDaoCharsetCache._absorb` to this function when the chapter cache arrived.
/// Reason it exists: drift's `ConnectionClosedException` (“the background isolate was closed”) is
/// not exported by drift 2.35.2, so it cannot be named, and letting it escape would break C-ERR-1.
/// The named clauses come first, `Error` is never caught, and the exemption must be replaced by a
/// named clause the moment drift exports the type.
Future<T?> absorbCacheFailure<T>(
  Future<T> Function() operation, {
  required AppLogger logger,
  required String scope,
  required String url,
}) async {
  try {
    return await operation();
  } on SqliteException catch (error, stackTrace) {
    _report(logger, scope, error, stackTrace, url);
  } on DriftRemoteException catch (error, stackTrace) {
    _report(logger, scope, error, stackTrace, url);
  } on DriftWrappedException catch (error, stackTrace) {
    _report(logger, scope, error, stackTrace, url);
  } on InvalidDataException catch (error, stackTrace) {
    _report(logger, scope, error, stackTrace, url);
  } on Exception catch (error, stackTrace) {
    _report(logger, scope, error, stackTrace, url);
  }

  return null;
}

/// Records one absorbed cache failure; never a page body, never a cleartext URL.
void _report(
  AppLogger logger,
  String scope,
  Object error,
  StackTrace stackTrace,
  String url,
) {
  logger.debug(
    '$scope unavailable: url=${redactUrl(url)}',
    describeError(error),
    stackTrace,
  );
}
