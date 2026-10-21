// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'di.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the settings persistence (`docs/dev/roadmap.md` 5.6)。

@ProviderFor(settingsRepository)
final settingsRepositoryProvider = SettingsRepositoryProvider._();

/// Provides the settings persistence (`docs/dev/roadmap.md` 5.6)。

final class SettingsRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SettingsRepository>,
          SettingsRepository,
          FutureOr<SettingsRepository>
        >
    with
        $FutureModifier<SettingsRepository>,
        $FutureProvider<SettingsRepository> {
  /// Provides the settings persistence (`docs/dev/roadmap.md` 5.6)。
  SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<SettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SettingsRepository> create(Ref ref) {
    return settingsRepository(ref);
  }
}

String _$settingsRepositoryHash() =>
    r'b8ace07bde4bde58300579bd95460694c166ad3d';

/// Provides the cache purge the settings page offers (`docs/dev/roadmap.md` 5.7 ①)。

@ProviderFor(cachePurger)
final cachePurgerProvider = CachePurgerProvider._();

/// Provides the cache purge the settings page offers (`docs/dev/roadmap.md` 5.7 ①)。

final class CachePurgerProvider
    extends $FunctionalProvider<CachePurger, CachePurger, CachePurger>
    with $Provider<CachePurger> {
  /// Provides the cache purge the settings page offers (`docs/dev/roadmap.md` 5.7 ①)。
  CachePurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cachePurgerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cachePurgerHash();

  @$internal
  @override
  $ProviderElement<CachePurger> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CachePurger create(Ref ref) {
    return cachePurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CachePurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CachePurger>(value),
    );
  }
}

String _$cachePurgerHash() => r'7a53849bb357e049a78f3da2c19556dcaafa2207';
