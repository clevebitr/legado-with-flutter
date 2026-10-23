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

String _$jsBridgeHash() => r'69f5374c6d7b08f8fbeb9e5234a4554f1159e4b5';

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
