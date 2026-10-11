// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_executor_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(databaseExecutor)
final databaseExecutorProvider = DatabaseExecutorProvider._();

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

final class DatabaseExecutorProvider
    extends $FunctionalProvider<QueryExecutor, QueryExecutor, QueryExecutor>
    with $Provider<QueryExecutor> {
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
  DatabaseExecutorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseExecutorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseExecutorHash();

  @$internal
  @override
  $ProviderElement<QueryExecutor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QueryExecutor create(Ref ref) {
    return databaseExecutor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QueryExecutor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QueryExecutor>(value),
    );
  }
}

String _$databaseExecutorHash() => r'b1cafcd50e2efd40e42daaa6ec73a59314bd81a8';
