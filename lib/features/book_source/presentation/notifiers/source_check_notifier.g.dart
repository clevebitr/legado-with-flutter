// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_check_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs the batch check and writes each verdict back.
///
/// Owns concurrency, the long-task marker and write-back; kept alive so a run survives navigation.

@ProviderFor(SourceCheck)
final sourceCheckProvider = SourceCheckProvider._();

/// Runs the batch check and writes each verdict back.
///
/// Owns concurrency, the long-task marker and write-back; kept alive so a run survives navigation.
final class SourceCheckProvider
    extends $NotifierProvider<SourceCheck, SourceCheckState> {
  /// Runs the batch check and writes each verdict back.
  ///
  /// Owns concurrency, the long-task marker and write-back; kept alive so a run survives navigation.
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

/// Runs the batch check and writes each verdict back.
///
/// Owns concurrency, the long-task marker and write-back; kept alive so a run survives navigation.

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
