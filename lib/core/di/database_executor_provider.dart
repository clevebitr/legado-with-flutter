// coverage:ignore-file
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_reader/core/di/database_path_provider.dart';
import 'package:flutter_reader/core/storage/database_path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_executor_provider.g.dart';

/// Provides the executor of the on-disk database.
///
/// SQLite runs in a background isolate that `flutter test` cannot reach, so this
/// path is verified by running the app.
@Riverpod(keepAlive: true)
QueryExecutor databaseExecutor(Ref ref) {
  final Future<String> path = ref.watch(databaseFilePathProvider.future);

  return driftDatabase(
    name: databaseFileName,
    native: DriftNativeOptions(databasePath: () => path),
  );
}
