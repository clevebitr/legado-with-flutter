// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preference_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the key-value store for light switches (C-NET-9).
///
/// `keepAlive` because opening the platform store is the expensive part and every settings read
/// goes through it; tests inject a fake by overriding this provider
/// (`ProviderScope(overrides: …)`, `docs/dev/testing.md` §4).

@ProviderFor(preferenceStore)
final preferenceStoreProvider = PreferenceStoreProvider._();

/// Provides the key-value store for light switches (C-NET-9).
///
/// `keepAlive` because opening the platform store is the expensive part and every settings read
/// goes through it; tests inject a fake by overriding this provider
/// (`ProviderScope(overrides: …)`, `docs/dev/testing.md` §4).

final class PreferenceStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<PreferenceStore>,
          PreferenceStore,
          FutureOr<PreferenceStore>
        >
    with $FutureModifier<PreferenceStore>, $FutureProvider<PreferenceStore> {
  /// Provides the key-value store for light switches (C-NET-9).
  ///
  /// `keepAlive` because opening the platform store is the expensive part and every settings read
  /// goes through it; tests inject a fake by overriding this provider
  /// (`ProviderScope(overrides: …)`, `docs/dev/testing.md` §4).
  PreferenceStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preferenceStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preferenceStoreHash();

  @$internal
  @override
  $FutureProviderElement<PreferenceStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PreferenceStore> create(Ref ref) {
    return preferenceStore(ref);
  }
}

String _$preferenceStoreHash() => r'f8dc51e1b9ae4eb178ce9ae3ed90c6473c67a0ee';
