// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_source_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The change-source page's state machine: search → pick a source → pick a chapter.
///
/// It is a family keyed by [ChangeSourceTarget] and auto-disposed, so leaving the page drops the
/// run; the switch itself is **not** performed here — the page answers the picked source and
/// chapter, and the caller (the detail page or the composition root) applies it (ADR-0091 §决策 1).

@ProviderFor(ChangeSourceController)
final changeSourceControllerProvider = ChangeSourceControllerFamily._();

/// The change-source page's state machine: search → pick a source → pick a chapter.
///
/// It is a family keyed by [ChangeSourceTarget] and auto-disposed, so leaving the page drops the
/// run; the switch itself is **not** performed here — the page answers the picked source and
/// chapter, and the caller (the detail page or the composition root) applies it (ADR-0091 §决策 1).
final class ChangeSourceControllerProvider
    extends $NotifierProvider<ChangeSourceController, ChangeSourceState> {
  /// The change-source page's state machine: search → pick a source → pick a chapter.
  ///
  /// It is a family keyed by [ChangeSourceTarget] and auto-disposed, so leaving the page drops the
  /// run; the switch itself is **not** performed here — the page answers the picked source and
  /// chapter, and the caller (the detail page or the composition root) applies it (ADR-0091 §决策 1).
  ChangeSourceControllerProvider._({
    required ChangeSourceControllerFamily super.from,
    required ChangeSourceTarget super.argument,
  }) : super(
         retry: null,
         name: r'changeSourceControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$changeSourceControllerHash();

  @override
  String toString() {
    return r'changeSourceControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChangeSourceController create() => ChangeSourceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChangeSourceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChangeSourceState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChangeSourceControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$changeSourceControllerHash() =>
    r'd68a1984176347d791523ee6a2ac0e231ceca27e';

/// The change-source page's state machine: search → pick a source → pick a chapter.
///
/// It is a family keyed by [ChangeSourceTarget] and auto-disposed, so leaving the page drops the
/// run; the switch itself is **not** performed here — the page answers the picked source and
/// chapter, and the caller (the detail page or the composition root) applies it (ADR-0091 §决策 1).

final class ChangeSourceControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ChangeSourceController,
          ChangeSourceState,
          ChangeSourceState,
          ChangeSourceState,
          ChangeSourceTarget
        > {
  ChangeSourceControllerFamily._()
    : super(
        retry: null,
        name: r'changeSourceControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The change-source page's state machine: search → pick a source → pick a chapter.
  ///
  /// It is a family keyed by [ChangeSourceTarget] and auto-disposed, so leaving the page drops the
  /// run; the switch itself is **not** performed here — the page answers the picked source and
  /// chapter, and the caller (the detail page or the composition root) applies it (ADR-0091 §决策 1).

  ChangeSourceControllerProvider call(ChangeSourceTarget target) =>
      ChangeSourceControllerProvider._(argument: target, from: this);

  @override
  String toString() => r'changeSourceControllerProvider';
}

/// The change-source page's state machine: search → pick a source → pick a chapter.
///
/// It is a family keyed by [ChangeSourceTarget] and auto-disposed, so leaving the page drops the
/// run; the switch itself is **not** performed here — the page answers the picked source and
/// chapter, and the caller (the detail page or the composition root) applies it (ADR-0091 §决策 1).

abstract class _$ChangeSourceController extends $Notifier<ChangeSourceState> {
  late final _$args = ref.$arg as ChangeSourceTarget;
  ChangeSourceTarget get target => _$args;

  ChangeSourceState build(ChangeSourceTarget target);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChangeSourceState, ChangeSourceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChangeSourceState, ChangeSourceState>,
              ChangeSourceState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The stored change-source scope; the only place that changes it (ADR-0091 §决策 5).

@ProviderFor(ChangeSourceScopeSelection)
final changeSourceScopeSelectionProvider =
    ChangeSourceScopeSelectionProvider._();

/// The stored change-source scope; the only place that changes it (ADR-0091 §决策 5).
final class ChangeSourceScopeSelectionProvider
    extends
        $AsyncNotifierProvider<ChangeSourceScopeSelection, BookSearchScope> {
  /// The stored change-source scope; the only place that changes it (ADR-0091 §决策 5).
  ChangeSourceScopeSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'changeSourceScopeSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$changeSourceScopeSelectionHash();

  @$internal
  @override
  ChangeSourceScopeSelection create() => ChangeSourceScopeSelection();
}

String _$changeSourceScopeSelectionHash() =>
    r'62236054b0931c4283495585193338a1c8c50bcc';

/// The stored change-source scope; the only place that changes it (ADR-0091 §决策 5).

abstract class _$ChangeSourceScopeSelection
    extends $AsyncNotifier<BookSearchScope> {
  FutureOr<BookSearchScope> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BookSearchScope>, BookSearchScope>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BookSearchScope>, BookSearchScope>,
              AsyncValue<BookSearchScope>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
