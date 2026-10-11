// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the application database (ADR-0003).

@ProviderFor(readerDatabase)
final readerDatabaseProvider = ReaderDatabaseProvider._();

/// Provides the application database (ADR-0003).

final class ReaderDatabaseProvider
    extends $FunctionalProvider<ReaderDatabase, ReaderDatabase, ReaderDatabase>
    with $Provider<ReaderDatabase> {
  /// Provides the application database (ADR-0003).
  ReaderDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerDatabaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerDatabaseHash();

  @$internal
  @override
  $ProviderElement<ReaderDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReaderDatabase create(Ref ref) {
    return readerDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReaderDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReaderDatabase>(value),
    );
  }
}

String _$readerDatabaseHash() => r'f606a4fcbc572f992c56ff05fb855e56c463d1f0';

/// Provides the TTL cache for network payloads (C-NET-6).

@ProviderFor(cacheDao)
final cacheDaoProvider = CacheDaoProvider._();

/// Provides the TTL cache for network payloads (C-NET-6).

final class CacheDaoProvider
    extends $FunctionalProvider<CacheDao, CacheDao, CacheDao>
    with $Provider<CacheDao> {
  /// Provides the TTL cache for network payloads (C-NET-6).
  CacheDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheDaoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheDaoHash();

  @$internal
  @override
  $ProviderElement<CacheDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CacheDao create(Ref ref) {
    return cacheDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CacheDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CacheDao>(value),
    );
  }
}

String _$cacheDaoHash() => r'4ac549853cf2d91614cb0c24570a9f68e458110d';
