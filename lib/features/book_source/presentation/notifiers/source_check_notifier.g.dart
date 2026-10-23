// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_check_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs the batch check (`docs/dev/roadmap.md` §5.10) and writes each verdict back.
///
/// The notifier owns three things the domain does not:
///
/// * **concurrency**: at most the user's per-source budget runs at once
///   (`concurrencySettingProvider`, the same number the request layer honours), because a batch of
///   ten sources must not open ten times the connections one source is allowed;
/// * **the long-task marker**: `LongRunningTask` is acquired for the whole batch and released in
///   `finally`, so Android keeps the process awake without the UI having to know about it
///   (ADR-0043 §决策 3);
/// * **write-back and its two failures**: a deleted row becomes [SourceCheckFailure.sourceMissing]
///   and a failed write becomes [SourceCheckFailure.saveFailed]; a **cancelled** report writes
///   nothing at all (ADR-0043 §后果).
///
/// It is `keepAlive` so walking to the debug console and back does not lose a running batch: a
/// check is minutes of work and must not be tied to one screen's lifetime.

@ProviderFor(SourceCheck)
final sourceCheckProvider = SourceCheckProvider._();

/// Runs the batch check (`docs/dev/roadmap.md` §5.10) and writes each verdict back.
///
/// The notifier owns three things the domain does not:
///
/// * **concurrency**: at most the user's per-source budget runs at once
///   (`concurrencySettingProvider`, the same number the request layer honours), because a batch of
///   ten sources must not open ten times the connections one source is allowed;
/// * **the long-task marker**: `LongRunningTask` is acquired for the whole batch and released in
///   `finally`, so Android keeps the process awake without the UI having to know about it
///   (ADR-0043 §决策 3);
/// * **write-back and its two failures**: a deleted row becomes [SourceCheckFailure.sourceMissing]
///   and a failed write becomes [SourceCheckFailure.saveFailed]; a **cancelled** report writes
///   nothing at all (ADR-0043 §后果).
///
/// It is `keepAlive` so walking to the debug console and back does not lose a running batch: a
/// check is minutes of work and must not be tied to one screen's lifetime.
final class SourceCheckProvider
    extends $NotifierProvider<SourceCheck, SourceCheckState> {
  /// Runs the batch check (`docs/dev/roadmap.md` §5.10) and writes each verdict back.
  ///
  /// The notifier owns three things the domain does not:
  ///
  /// * **concurrency**: at most the user's per-source budget runs at once
  ///   (`concurrencySettingProvider`, the same number the request layer honours), because a batch of
  ///   ten sources must not open ten times the connections one source is allowed;
  /// * **the long-task marker**: `LongRunningTask` is acquired for the whole batch and released in
  ///   `finally`, so Android keeps the process awake without the UI having to know about it
  ///   (ADR-0043 §决策 3);
  /// * **write-back and its two failures**: a deleted row becomes [SourceCheckFailure.sourceMissing]
  ///   and a failed write becomes [SourceCheckFailure.saveFailed]; a **cancelled** report writes
  ///   nothing at all (ADR-0043 §后果).
  ///
  /// It is `keepAlive` so walking to the debug console and back does not lose a running batch: a
  /// check is minutes of work and must not be tied to one screen's lifetime.
  SourceCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceCheckProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceCheckHash();

  @$internal
  @override
  SourceCheck create() => SourceCheck();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceCheckState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceCheckState>(value),
    );
  }
}

String _$sourceCheckHash() => r'39821ecb534234831c7535eae1ad85fc86d81bfe';

/// Runs the batch check (`docs/dev/roadmap.md` §5.10) and writes each verdict back.
///
/// The notifier owns three things the domain does not:
///
/// * **concurrency**: at most the user's per-source budget runs at once
///   (`concurrencySettingProvider`, the same number the request layer honours), because a batch of
///   ten sources must not open ten times the connections one source is allowed;
/// * **the long-task marker**: `LongRunningTask` is acquired for the whole batch and released in
///   `finally`, so Android keeps the process awake without the UI having to know about it
///   (ADR-0043 §决策 3);
/// * **write-back and its two failures**: a deleted row becomes [SourceCheckFailure.sourceMissing]
///   and a failed write becomes [SourceCheckFailure.saveFailed]; a **cancelled** report writes
///   nothing at all (ADR-0043 §后果).
///
/// It is `keepAlive` so walking to the debug console and back does not lose a running batch: a
/// check is minutes of work and must not be tied to one screen's lifetime.

abstract class _$SourceCheck extends $Notifier<SourceCheckState> {
  SourceCheckState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SourceCheckState, SourceCheckState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SourceCheckState, SourceCheckState>,
              SourceCheckState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
