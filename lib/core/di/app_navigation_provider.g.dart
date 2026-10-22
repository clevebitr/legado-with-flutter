// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_navigation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the cross-feature destinations (ADR-0042).
///
/// The composition root overrides this with the real implementation
/// (`appProviderOverrides` in `lib/app.dart`); the default is the unbound no-op, so a page can
/// always call it and tests that do not care about navigation need no override.

@ProviderFor(appNavigation)
final appNavigationProvider = AppNavigationProvider._();

/// Provides the cross-feature destinations (ADR-0042).
///
/// The composition root overrides this with the real implementation
/// (`appProviderOverrides` in `lib/app.dart`); the default is the unbound no-op, so a page can
/// always call it and tests that do not care about navigation need no override.

final class AppNavigationProvider
    extends $FunctionalProvider<AppNavigation, AppNavigation, AppNavigation>
    with $Provider<AppNavigation> {
  /// Provides the cross-feature destinations (ADR-0042).
  ///
  /// The composition root overrides this with the real implementation
  /// (`appProviderOverrides` in `lib/app.dart`); the default is the unbound no-op, so a page can
  /// always call it and tests that do not care about navigation need no override.
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
