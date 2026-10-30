// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'explore_layout_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The discover page's layout, and the only place that changes it
/// (`docs/dev/roadmap.md` §3.12, `DECISIONS.md` #77).

@ProviderFor(ExploreLayoutController)
final exploreLayoutControllerProvider = ExploreLayoutControllerProvider._();

/// The discover page's layout, and the only place that changes it
/// (`docs/dev/roadmap.md` §3.12, `DECISIONS.md` #77).
final class ExploreLayoutControllerProvider
    extends $AsyncNotifierProvider<ExploreLayoutController, ExploreLayout> {
  /// The discover page's layout, and the only place that changes it
  /// (`docs/dev/roadmap.md` §3.12, `DECISIONS.md` #77).
  ExploreLayoutControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exploreLayoutControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exploreLayoutControllerHash();

  @$internal
  @override
  ExploreLayoutController create() => ExploreLayoutController();
}

String _$exploreLayoutControllerHash() =>
    r'ee67a12c8af2014d4b984742aca34d348253a643';

/// The discover page's layout, and the only place that changes it
/// (`docs/dev/roadmap.md` §3.12, `DECISIONS.md` #77).

abstract class _$ExploreLayoutController extends $AsyncNotifier<ExploreLayout> {
  FutureOr<ExploreLayout> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ExploreLayout>, ExploreLayout>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ExploreLayout>, ExploreLayout>,
              AsyncValue<ExploreLayout>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
