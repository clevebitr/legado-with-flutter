import 'package:drift/drift.dart'
    show DriftWrappedException, InvalidDataException;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/error_text.dart';

/// Runs one cache operation and turns a database failure into a cache miss.
///
/// `Error` stays uncaught; the bare `on Exception` covers drift's unexported errors.
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

// Records one absorbed cache failure; never a page body, never a cleartext URL.
void _report(
  AppLogger logger,
  String scope,
  Object error,
  StackTrace stackTrace,
  String url,
) {
  logger.debug(
    '$scope unavailable: url=$url',
    describeError(error),
    stackTrace,
  );
}
