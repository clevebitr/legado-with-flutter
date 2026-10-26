// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_executor_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the executor of the on-disk database.
///
/// SQLite runs in a background isolate that `flutter test` cannot reach, so this
/// path is verified by running the app.

@ProviderFor(databaseExecutor)
final databaseExecutorProvider = DatabaseExecutorProvider._();

/// Provides the executor of the on-disk database.
///
/// SQLite runs in a background isolate that `flutter test` cannot reach, so this
/// path is verified by running the app.

final class DatabaseExecutorProvider
    extends $FunctionalProvider<QueryExecutor, QueryExecutor, QueryExecutor>
    with $Provider<QueryExecutor> {
  /// Provides the executor of the on-disk database.
  ///
  /// SQLite runs in a background isolate that `flutter test` cannot reach, so this
  /// path is verified by running the app.
  DatabaseExecutorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseExecutorProvider',
        isAutoDispose: false,
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

String _$databaseExecutorHash() => r'57ccdecc39a69e1fa7793a2cf18e2fec0a49eb9b';
