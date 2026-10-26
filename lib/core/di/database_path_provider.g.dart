// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_path_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the on-disk database path: `<application support>/reader.db`.
///
/// Isolated so tests can fake the platform lookup without opening a database.

@ProviderFor(databaseFilePath)
final databaseFilePathProvider = DatabaseFilePathProvider._();

/// Provides the on-disk database path: `<application support>/reader.db`.
///
/// Isolated so tests can fake the platform lookup without opening a database.

final class DatabaseFilePathProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Provides the on-disk database path: `<application support>/reader.db`.
  ///
  /// Isolated so tests can fake the platform lookup without opening a database.
  DatabaseFilePathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseFilePathProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseFilePathHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return databaseFilePath(ref);
  }
}

String _$databaseFilePathHash() => r'98b9222a6a572e19f7e172322e97139c739e9ed6';
