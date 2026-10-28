// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'explore_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the discover page: reads the categories once, then one category at a time.

@ProviderFor(ExploreNotifier)
final exploreProvider = ExploreNotifierProvider._();

/// Drives the discover page: reads the categories once, then one category at a time.
final class ExploreNotifierProvider
    extends $NotifierProvider<ExploreNotifier, ExploreState> {
  /// Drives the discover page: reads the categories once, then one category at a time.
  ExploreNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exploreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exploreNotifierHash();

  @$internal
  @override
  ExploreNotifier create() => ExploreNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExploreState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExploreState>(value),
    );
  }
}

String _$exploreNotifierHash() => r'1097f3fe407fcf1483bcdf518bcedeccb15568a7';

/// Drives the discover page: reads the categories once, then one category at a time.

abstract class _$ExploreNotifier extends $Notifier<ExploreState> {
  ExploreState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ExploreState, ExploreState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ExploreState, ExploreState>,
              ExploreState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
