// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the platform facts every other layer is allowed to branch on
/// (C-PLT-1).
///
/// Tests override it with a fake to simulate Android or a desktop host.

@ProviderFor(platformInfo)
final platformInfoProvider = PlatformInfoProvider._();

/// Provides the platform facts every other layer is allowed to branch on
/// (C-PLT-1).
///
/// Tests override it with a fake to simulate Android or a desktop host.

final class PlatformInfoProvider
    extends $FunctionalProvider<PlatformInfo, PlatformInfo, PlatformInfo>
    with $Provider<PlatformInfo> {
  /// Provides the platform facts every other layer is allowed to branch on
  /// (C-PLT-1).
  ///
  /// Tests override it with a fake to simulate Android or a desktop host.
  PlatformInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformInfoHash();

  @$internal
  @override
  $ProviderElement<PlatformInfo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlatformInfo create(Ref ref) {
    return platformInfo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlatformInfo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlatformInfo>(value),
    );
  }
}

String _$platformInfoHash() => r'ac1b6ad7f08ed596944a3dc7d4daea8f0278565a';

/// Provides the platform dynamic color source, or `null` when the platform has
/// none (`docs/dev/platform.md` §3).
///
/// Named `platformDynamicColor` on purpose: the generated provider class is
/// `<function>Provider`, so a function named `dynamicColor` would declare
/// `DynamicColorProvider` and collide with the platform interface of the same
/// name.
///
/// Consumers must handle `null` by falling back to the seed color; tests pin the
/// fallback with `platformDynamicColorProvider.overrideWithValue(null)`
/// (`docs/dev/testing.md` §5).

@ProviderFor(platformDynamicColor)
final platformDynamicColorProvider = PlatformDynamicColorProvider._();

/// Provides the platform dynamic color source, or `null` when the platform has
/// none (`docs/dev/platform.md` §3).
///
/// Named `platformDynamicColor` on purpose: the generated provider class is
/// `<function>Provider`, so a function named `dynamicColor` would declare
/// `DynamicColorProvider` and collide with the platform interface of the same
/// name.
///
/// Consumers must handle `null` by falling back to the seed color; tests pin the
/// fallback with `platformDynamicColorProvider.overrideWithValue(null)`
/// (`docs/dev/testing.md` §5).

final class PlatformDynamicColorProvider
    extends
        $FunctionalProvider<
          DynamicColorProvider?,
          DynamicColorProvider?,
          DynamicColorProvider?
        >
    with $Provider<DynamicColorProvider?> {
  /// Provides the platform dynamic color source, or `null` when the platform has
  /// none (`docs/dev/platform.md` §3).
  ///
  /// Named `platformDynamicColor` on purpose: the generated provider class is
  /// `<function>Provider`, so a function named `dynamicColor` would declare
  /// `DynamicColorProvider` and collide with the platform interface of the same
  /// name.
  ///
  /// Consumers must handle `null` by falling back to the seed color; tests pin the
  /// fallback with `platformDynamicColorProvider.overrideWithValue(null)`
  /// (`docs/dev/testing.md` §5).
  PlatformDynamicColorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformDynamicColorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformDynamicColorHash();

  @$internal
  @override
  $ProviderElement<DynamicColorProvider?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DynamicColorProvider? create(Ref ref) {
    return platformDynamicColor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DynamicColorProvider? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DynamicColorProvider?>(value),
    );
  }
}

String _$platformDynamicColorHash() =>
    r'2e2a1cce18f3fde23676be4d723a6b63a58fe1a2';

/// Provides the platform file picker for book source imports (`PLAN.md` 5.8, C-PLT-1).
///
/// Every target this app ships (Android, iOS, Windows) has a real dialog through `file_selector`;
/// anything else gets the fallback that answers “nothing picked”, so an unsupported platform
/// degrades instead of throwing (`docs/dev/platform.md` §2). Tests override the port, never the
/// plugin (`docs/dev/testing.md` §4).

@ProviderFor(bookSourceFilePicker)
final bookSourceFilePickerProvider = BookSourceFilePickerProvider._();

/// Provides the platform file picker for book source imports (`PLAN.md` 5.8, C-PLT-1).
///
/// Every target this app ships (Android, iOS, Windows) has a real dialog through `file_selector`;
/// anything else gets the fallback that answers “nothing picked”, so an unsupported platform
/// degrades instead of throwing (`docs/dev/platform.md` §2). Tests override the port, never the
/// plugin (`docs/dev/testing.md` §4).

final class BookSourceFilePickerProvider
    extends
        $FunctionalProvider<
          BookSourceFilePicker,
          BookSourceFilePicker,
          BookSourceFilePicker
        >
    with $Provider<BookSourceFilePicker> {
  /// Provides the platform file picker for book source imports (`PLAN.md` 5.8, C-PLT-1).
  ///
  /// Every target this app ships (Android, iOS, Windows) has a real dialog through `file_selector`;
  /// anything else gets the fallback that answers “nothing picked”, so an unsupported platform
  /// degrades instead of throwing (`docs/dev/platform.md` §2). Tests override the port, never the
  /// plugin (`docs/dev/testing.md` §4).
  BookSourceFilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceFilePickerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceFilePickerHash();

  @$internal
  @override
  $ProviderElement<BookSourceFilePicker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookSourceFilePicker create(Ref ref) {
    return bookSourceFilePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookSourceFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookSourceFilePicker>(value),
    );
  }
}

String _$bookSourceFilePickerHash() =>
    r'03ffd09c149b1f20aaab463e862cc267bead4c59';
