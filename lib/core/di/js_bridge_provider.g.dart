// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'js_bridge_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the `@js:` sandbox every rule evaluation shares (C-SRC-2, C-SRC-3).
///
/// The worker is created **lazily** by the bridge on the first `@js:` rule and released
/// with this provider (ADR-0030 §决策 6), so an app that never meets a JS rule never
/// pays for an isolate or a QuickJS runtime. Everything the bridge needs — the isolate,
/// the engine and the JS prelude — stays behind the launcher, which is why `domain/`
/// only ever sees [JsBridge] (ADR-0029 §决策 2).
///
/// The bridge also gets the app-wide HTTP client, because §6 binds `http.*` to the rule
/// sandbox and C-NET-1 makes that client the only door to the network: a rule's request
/// shares the same cookies and the same per-source concurrency budget (`book-source.md`
/// §8) as the page that carried the rule.
///
/// The provider is autoDispose: the budget dies with the scope, so one operation's
/// batch shares one worker (see `PLAN.md` §3.7 for the batch-download follow-up).

@ProviderFor(jsBridge)
final jsBridgeProvider = JsBridgeProvider._();

/// Provides the `@js:` sandbox every rule evaluation shares (C-SRC-2, C-SRC-3).
///
/// The worker is created **lazily** by the bridge on the first `@js:` rule and released
/// with this provider (ADR-0030 §决策 6), so an app that never meets a JS rule never
/// pays for an isolate or a QuickJS runtime. Everything the bridge needs — the isolate,
/// the engine and the JS prelude — stays behind the launcher, which is why `domain/`
/// only ever sees [JsBridge] (ADR-0029 §决策 2).
///
/// The bridge also gets the app-wide HTTP client, because §6 binds `http.*` to the rule
/// sandbox and C-NET-1 makes that client the only door to the network: a rule's request
/// shares the same cookies and the same per-source concurrency budget (`book-source.md`
/// §8) as the page that carried the rule.
///
/// The provider is autoDispose: the budget dies with the scope, so one operation's
/// batch shares one worker (see `PLAN.md` §3.7 for the batch-download follow-up).

final class JsBridgeProvider
    extends $FunctionalProvider<JsBridge, JsBridge, JsBridge>
    with $Provider<JsBridge> {
  /// Provides the `@js:` sandbox every rule evaluation shares (C-SRC-2, C-SRC-3).
  ///
  /// The worker is created **lazily** by the bridge on the first `@js:` rule and released
  /// with this provider (ADR-0030 §决策 6), so an app that never meets a JS rule never
  /// pays for an isolate or a QuickJS runtime. Everything the bridge needs — the isolate,
  /// the engine and the JS prelude — stays behind the launcher, which is why `domain/`
  /// only ever sees [JsBridge] (ADR-0029 §决策 2).
  ///
  /// The bridge also gets the app-wide HTTP client, because §6 binds `http.*` to the rule
  /// sandbox and C-NET-1 makes that client the only door to the network: a rule's request
  /// shares the same cookies and the same per-source concurrency budget (`book-source.md`
  /// §8) as the page that carried the rule.
  ///
  /// The provider is autoDispose: the budget dies with the scope, so one operation's
  /// batch shares one worker (see `PLAN.md` §3.7 for the batch-download follow-up).
  JsBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jsBridgeProvider',
        isAutoDispose: true,
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

String _$jsBridgeHash() => r'1345804b08bde31f4aebebabbeaeb4da22b9fc5e';

/// Provides the rule variables `@put:` / `@get:` and `java.put` / `java.get` share
/// (`docs/dev/book-source.md` §4 and §6, matrix #16 / #17).
///
/// It is one instance per provider scope, keyed by book source inside, and it is watched by
/// both the engine and the bridge because the two are the two ends of one contract: the
/// engine reads and writes it while parsing, the bridge applies what a script wrote
/// (ADR-0034 §决策 1). A scope owns the variables' lifetime, so nothing survives the
/// operation that created it — which is the registered difference from upstream's
/// persisted per-book variables (ADR-0034 §决策 2).

@ProviderFor(jsVariableStore)
final jsVariableStoreProvider = JsVariableStoreProvider._();

/// Provides the rule variables `@put:` / `@get:` and `java.put` / `java.get` share
/// (`docs/dev/book-source.md` §4 and §6, matrix #16 / #17).
///
/// It is one instance per provider scope, keyed by book source inside, and it is watched by
/// both the engine and the bridge because the two are the two ends of one contract: the
/// engine reads and writes it while parsing, the bridge applies what a script wrote
/// (ADR-0034 §决策 1). A scope owns the variables' lifetime, so nothing survives the
/// operation that created it — which is the registered difference from upstream's
/// persisted per-book variables (ADR-0034 §决策 2).

final class JsVariableStoreProvider
    extends
        $FunctionalProvider<JsVariableStore, JsVariableStore, JsVariableStore>
    with $Provider<JsVariableStore> {
  /// Provides the rule variables `@put:` / `@get:` and `java.put` / `java.get` share
  /// (`docs/dev/book-source.md` §4 and §6, matrix #16 / #17).
  ///
  /// It is one instance per provider scope, keyed by book source inside, and it is watched by
  /// both the engine and the bridge because the two are the two ends of one contract: the
  /// engine reads and writes it while parsing, the bridge applies what a script wrote
  /// (ADR-0034 §决策 1). A scope owns the variables' lifetime, so nothing survives the
  /// operation that created it — which is the registered difference from upstream's
  /// persisted per-book variables (ADR-0034 §决策 2).
  JsVariableStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jsVariableStoreProvider',
        isAutoDispose: true,
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

String _$jsVariableStoreHash() => r'2757af5cd35b30cfd6127455a7f867c15cc9c1fd';
