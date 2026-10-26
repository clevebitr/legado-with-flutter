// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shelf_cover_picker_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the cover picker of the shelf feature (`docs/dev/roadmap.md` M19).
///
/// The directory is resolved lazily per pick, because a provider that awaited `path_provider` would
/// make the shelf page depend on a platform channel just to render.

@ProviderFor(shelfCoverPicker)
final shelfCoverPickerProvider = ShelfCoverPickerProvider._();

/// Provides the cover picker of the shelf feature (`docs/dev/roadmap.md` M19).
///
/// The directory is resolved lazily per pick, because a provider that awaited `path_provider` would
/// make the shelf page depend on a platform channel just to render.

final class ShelfCoverPickerProvider
    extends
        $FunctionalProvider<
          ShelfCoverPicker,
          ShelfCoverPicker,
          ShelfCoverPicker
        >
    with $Provider<ShelfCoverPicker> {
  /// Provides the cover picker of the shelf feature (`docs/dev/roadmap.md` M19).
  ///
  /// The directory is resolved lazily per pick, because a provider that awaited `path_provider` would
  /// make the shelf page depend on a platform channel just to render.
  ShelfCoverPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shelfCoverPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shelfCoverPickerHash();

  @$internal
  @override
  $ProviderElement<ShelfCoverPicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShelfCoverPicker create(Ref ref) {
    return shelfCoverPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShelfCoverPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShelfCoverPicker>(value),
    );
  }
}

String _$shelfCoverPickerHash() => r'd5e328596c55e1a75b4d563e1c9764ebdd59a1d5';
