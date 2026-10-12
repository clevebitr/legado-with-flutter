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

String _$jsBridgeHash() => r'e932d992d458fc1cd9fadfcefc571f324d06af86';
