// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_debug_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives one debug console: the target / query the user picked and the event stream of the run.
///
/// The notifier is a thin adapter on purpose — the chain itself is `RunSourceDebug` in `domain/`,
/// and every line it reports is already a typed [SourceDebugEvent]. What lives here is the state
/// machine the UI needs: which target is selected, whether a run is in flight, and the two ways a
/// run ends (its own status, or a stop the user asked for).
///
/// A stop is cooperative like the batch check's (ADR-0043 §后果): the token is set and the run
/// ends between two steps, so the console reports `cancelled` instead of a failure.

@ProviderFor(SourceDebug)
final sourceDebugProvider = SourceDebugProvider._();

/// Drives one debug console: the target / query the user picked and the event stream of the run.
///
/// The notifier is a thin adapter on purpose — the chain itself is `RunSourceDebug` in `domain/`,
/// and every line it reports is already a typed [SourceDebugEvent]. What lives here is the state
/// machine the UI needs: which target is selected, whether a run is in flight, and the two ways a
/// run ends (its own status, or a stop the user asked for).
///
/// A stop is cooperative like the batch check's (ADR-0043 §后果): the token is set and the run
/// ends between two steps, so the console reports `cancelled` instead of a failure.
final class SourceDebugProvider
    extends $NotifierProvider<SourceDebug, SourceDebugState> {
  /// Drives one debug console: the target / query the user picked and the event stream of the run.
  ///
  /// The notifier is a thin adapter on purpose — the chain itself is `RunSourceDebug` in `domain/`,
  /// and every line it reports is already a typed [SourceDebugEvent]. What lives here is the state
  /// machine the UI needs: which target is selected, whether a run is in flight, and the two ways a
  /// run ends (its own status, or a stop the user asked for).
  ///
  /// A stop is cooperative like the batch check's (ADR-0043 §后果): the token is set and the run
  /// ends between two steps, so the console reports `cancelled` instead of a failure.
  SourceDebugProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceDebugProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceDebugHash();

  @$internal
  @override
  SourceDebug create() => SourceDebug();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceDebugState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceDebugState>(value),
    );
  }
}

String _$sourceDebugHash() => r'bf45f3d0d6c306e36c3c71e62ff1d41ab202dcf4';

/// Drives one debug console: the target / query the user picked and the event stream of the run.
///
/// The notifier is a thin adapter on purpose — the chain itself is `RunSourceDebug` in `domain/`,
/// and every line it reports is already a typed [SourceDebugEvent]. What lives here is the state
/// machine the UI needs: which target is selected, whether a run is in flight, and the two ways a
/// run ends (its own status, or a stop the user asked for).
///
/// A stop is cooperative like the batch check's (ADR-0043 §后果): the token is set and the run
/// ends between two steps, so the console reports `cancelled` instead of a failure.

abstract class _$SourceDebug extends $Notifier<SourceDebugState> {
  SourceDebugState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SourceDebugState, SourceDebugState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SourceDebugState, SourceDebugState>,
              SourceDebugState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
