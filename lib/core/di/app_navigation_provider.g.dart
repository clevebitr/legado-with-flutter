// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_navigation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the cross-feature destinations.
///
/// Defaults to the unbound no-op; the composition root may override it.

@ProviderFor(appNavigation)
final appNavigationProvider = AppNavigationProvider._();

/// Provides the cross-feature destinations.
///
/// Defaults to the unbound no-op; the composition root may override it.

final class AppNavigationProvider
    extends $FunctionalProvider<AppNavigation, AppNavigation, AppNavigation>
    with $Provider<AppNavigation> {
  /// Provides the cross-feature destinations.
  ///
  /// Defaults to the unbound no-op; the composition root may override it.
  AppNavigationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appNavigationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appNavigationHash();

  @$internal
  @override
  $ProviderElement<AppNavigation> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppNavigation create(Ref ref) {
    return appNavigation(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppNavigation value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppNavigation>(value),
    );
  }
}

String _$appNavigationHash() => r'd6180e7439ec8aa4bd5c663f4b7602fc3f6eac56';
