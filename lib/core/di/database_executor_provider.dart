// coverage:ignore-file
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_reader/core/di/database_path_provider.dart';
import 'package:flutter_reader/core/storage/database_path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_executor_provider.g.dart';

/// Provides the executor of the on-disk database (ADR-0003).
///
/// `drift_flutter` supplies the platform SQLite library and runs SQLite in a
/// background isolate. That isolate cannot be reached from `flutter test`
/// (`Channel was closed before receiving a response`), so this file is exempt
/// from the coverage gate under ADR-0019's second category and must be verified
/// by running the app or an integration test instead:
///
/// ```bash
/// flutter run -d windows   # 首次启动即建库，日志无 DriftRemoteException 即通过
/// ```
@Riverpod(keepAlive: true)
QueryExecutor databaseExecutor(Ref ref) {
  final Future<String> path = ref.watch(databaseFilePathProvider.future);

  return driftDatabase(
    name: databaseFileName,
    native: DriftNativeOptions(databasePath: () => path),
  );
}
