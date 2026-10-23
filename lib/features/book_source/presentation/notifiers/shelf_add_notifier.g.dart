// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shelf_add_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The 「加入书架」 action of the detail page (`docs/dev/roadmap.md` 5.4)。
///
/// It exists as a Notifier rather than a call inside the page because C-STATE-4 keeps business
/// calls out of widgets; the loading state is what disables the button while a write is in
/// flight. The **port** does the cross-feature part: nothing here knows what a shelf is
/// (ADR-0041 §决策 2).

@ProviderFor(ShelfAdd)
final shelfAddProvider = ShelfAddProvider._();

/// The 「加入书架」 action of the detail page (`docs/dev/roadmap.md` 5.4)。
///
/// It exists as a Notifier rather than a call inside the page because C-STATE-4 keeps business
/// calls out of widgets; the loading state is what disables the button while a write is in
/// flight. The **port** does the cross-feature part: nothing here knows what a shelf is
/// (ADR-0041 §决策 2).
final class ShelfAddProvider
    extends $NotifierProvider<ShelfAdd, AsyncValue<void>> {
  /// The 「加入书架」 action of the detail page (`docs/dev/roadmap.md` 5.4)。
  ///
  /// It exists as a Notifier rather than a call inside the page because C-STATE-4 keeps business
  /// calls out of widgets; the loading state is what disables the button while a write is in
  /// flight. The **port** does the cross-feature part: nothing here knows what a shelf is
  /// (ADR-0041 §决策 2).
  ShelfAddProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shelfAddProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shelfAddHash();

  @$internal
  @override
  ShelfAdd create() => ShelfAdd();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$shelfAddHash() => r'6a68328b9b2988a5fc6f2f9c82e8fa5955b06b48';

/// The 「加入书架」 action of the detail page (`docs/dev/roadmap.md` 5.4)。
///
/// It exists as a Notifier rather than a call inside the page because C-STATE-4 keeps business
/// calls out of widgets; the loading state is what disables the button while a write is in
/// flight. The **port** does the cross-feature part: nothing here knows what a shelf is
/// (ADR-0041 §决策 2).

abstract class _$ShelfAdd extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
