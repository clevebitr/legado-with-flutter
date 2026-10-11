// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_path_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the on-disk database path: `<application support>/reader.db`
/// (`docs/dev/platform.md` §5).
///
/// The platform lookup is isolated here so tests can assert the resolved path
/// without opening a file database: they fake the `path_provider` channel
/// instead of touching the real application directory.

@ProviderFor(databaseFilePath)
final databaseFilePathProvider = DatabaseFilePathProvider._();

/// Provides the on-disk database path: `<application support>/reader.db`
/// (`docs/dev/platform.md` §5).
///
/// The platform lookup is isolated here so tests can assert the resolved path
/// without opening a file database: they fake the `path_provider` channel
/// instead of touching the real application directory.

final class DatabaseFilePathProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Provides the on-disk database path: `<application support>/reader.db`
  /// (`docs/dev/platform.md` §5).
  ///
  /// The platform lookup is isolated here so tests can assert the resolved path
  /// without opening a file database: they fake the `path_provider` channel
  /// instead of touching the real application directory.
  DatabaseFilePathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseFilePathProvider',
        isAutoDispose: true,
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

String _$databaseFilePathHash() => r'f4f82349a8e36dd7520d9d50abcce88cc9cd77a5';
