// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shelf_add_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Adds a book to the shelf from the detail page.
///
/// The write goes through the shelf port, so this feature knows no shelf type.

@ProviderFor(ShelfAdd)
final shelfAddProvider = ShelfAddProvider._();

/// Adds a book to the shelf from the detail page.
///
/// The write goes through the shelf port, so this feature knows no shelf type.
final class ShelfAddProvider
    extends $NotifierProvider<ShelfAdd, AsyncValue<void>> {
  /// Adds a book to the shelf from the detail page.
  ///
  /// The write goes through the shelf port, so this feature knows no shelf type.
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

/// Adds a book to the shelf from the detail page.
///
/// The write goes through the shelf port, so this feature knows no shelf type.

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
