// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'js_bridge_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the shared `@js:` sandbox for rule evaluation.
///
/// The worker is created on first use, and scripts share the app HTTP client's
/// cookies and per-source concurrency budget.

@ProviderFor(jsBridge)
final jsBridgeProvider = JsBridgeProvider._();

/// Provides the shared `@js:` sandbox for rule evaluation.
///
/// The worker is created on first use, and scripts share the app HTTP client's
/// cookies and per-source concurrency budget.

final class JsBridgeProvider
    extends $FunctionalProvider<JsBridge, JsBridge, JsBridge>
    with $Provider<JsBridge> {
  /// Provides the shared `@js:` sandbox for rule evaluation.
  ///
  /// The worker is created on first use, and scripts share the app HTTP client's
  /// cookies and per-source concurrency budget.
  JsBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jsBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jsBridgeHash();

  @$internal
  @override
  $ProviderElement<JsBridge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JsBridge create(Ref ref) {
    return jsBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JsBridge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JsBridge>(value),
    );
  }
}

String _$jsBridgeHash() => r'ef2509fcbad82a4f9653adda92877edfcc2a12d4';

/// Provides the per-source `infoMap` (`book-source.md` §6, M25/S3b).
///
/// In memory only, like `cache.*`: it is explore state, not a record, and it is read and written by
/// every job, so a rebuild between two stages must not wipe it — hence `keepAlive`.

@ProviderFor(sourceInfoMapStore)
final sourceInfoMapStoreProvider = SourceInfoMapStoreProvider._();

/// Provides the per-source `infoMap` (`book-source.md` §6, M25/S3b).
///
/// In memory only, like `cache.*`: it is explore state, not a record, and it is read and written by
/// every job, so a rebuild between two stages must not wipe it — hence `keepAlive`.

final class SourceInfoMapStoreProvider
    extends
        $FunctionalProvider<
          SourceInfoMapStore,
          SourceInfoMapStore,
          SourceInfoMapStore
        >
    with $Provider<SourceInfoMapStore> {
  /// Provides the per-source `infoMap` (`book-source.md` §6, M25/S3b).
  ///
  /// In memory only, like `cache.*`: it is explore state, not a record, and it is read and written by
  /// every job, so a rebuild between two stages must not wipe it — hence `keepAlive`.
  SourceInfoMapStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceInfoMapStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceInfoMapStoreHash();

  @$internal
  @override
  $ProviderElement<SourceInfoMapStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SourceInfoMapStore create(Ref ref) {
    return sourceInfoMapStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceInfoMapStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceInfoMapStore>(value),
    );
  }
}

String _$sourceInfoMapStoreHash() =>
    r'14de203b059a85667e2da16b9320749ea3dda959';

/// Provides the rule variables shared by `@put:` / `@get:` and `java.put` /
/// `java.get`.
///
/// One store per provider scope; nothing survives the operation that created it.

@ProviderFor(jsVariableStore)
final jsVariableStoreProvider = JsVariableStoreProvider._();

/// Provides the rule variables shared by `@put:` / `@get:` and `java.put` /
/// `java.get`.
///
/// One store per provider scope; nothing survives the operation that created it.

final class JsVariableStoreProvider
    extends
        $FunctionalProvider<JsVariableStore, JsVariableStore, JsVariableStore>
    with $Provider<JsVariableStore> {
  /// Provides the rule variables shared by `@put:` / `@get:` and `java.put` /
  /// `java.get`.
  ///
  /// One store per provider scope; nothing survives the operation that created it.
  JsVariableStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jsVariableStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jsVariableStoreHash();

  @$internal
  @override
  $ProviderElement<JsVariableStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JsVariableStore create(Ref ref) {
    return jsVariableStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JsVariableStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JsVariableStore>(value),
    );
  }
}

String _$jsVariableStoreHash() => r'c6e15401e66da680841340a4e08b1644de9e2c08';

/// Provides the resolver for a book source's own JavaScript library (`jsLib`, ADR-0078 S1).
///
/// `keepAlive` matters: the store caches the resolved text per library, so one page with twenty
/// `@js:` fields downloads the library once — and a rebuild between stages would throw that away.

@ProviderFor(jsLibStore)
final jsLibStoreProvider = JsLibStoreProvider._();

/// Provides the resolver for a book source's own JavaScript library (`jsLib`, ADR-0078 S1).
///
/// `keepAlive` matters: the store caches the resolved text per library, so one page with twenty
/// `@js:` fields downloads the library once — and a rebuild between stages would throw that away.

final class JsLibStoreProvider
    extends $FunctionalProvider<JsLibStore, JsLibStore, JsLibStore>
    with $Provider<JsLibStore> {
  /// Provides the resolver for a book source's own JavaScript library (`jsLib`, ADR-0078 S1).
  ///
  /// `keepAlive` matters: the store caches the resolved text per library, so one page with twenty
  /// `@js:` fields downloads the library once — and a rebuild between stages would throw that away.
  JsLibStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jsLibStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jsLibStoreHash();

  @$internal
  @override
  $ProviderElement<JsLibStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JsLibStore create(Ref ref) {
    return jsLibStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JsLibStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JsLibStore>(value),
    );
  }
}

String _$jsLibStoreHash() => r'a1fd59f7223168f628175c97b83ad7bae1edbe58';
