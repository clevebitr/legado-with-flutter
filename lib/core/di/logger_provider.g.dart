// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logger_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the application logger, the only log entry point (ADR-0006).
///
/// Tests inject a capturing printer with
/// `appLoggerProvider.overrideWithValue(...)`.

@ProviderFor(appLogger)
final appLoggerProvider = AppLoggerProvider._();

/// Provides the application logger, the only log entry point (ADR-0006).
///
/// Tests inject a capturing printer with
/// `appLoggerProvider.overrideWithValue(...)`.

final class AppLoggerProvider
    extends $FunctionalProvider<AppLogger, AppLogger, AppLogger>
    with $Provider<AppLogger> {
  /// Provides the application logger, the only log entry point (ADR-0006).
  ///
  /// Tests inject a capturing printer with
  /// `appLoggerProvider.overrideWithValue(...)`.
  AppLoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLoggerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLoggerHash();

  @$internal
  @override
  $ProviderElement<AppLogger> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppLogger create(Ref ref) {
    return appLogger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLogger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLogger>(value),
    );
  }
}

String _$appLoggerHash() => r'3f9551965c51d55bc377cf04fd8695745353150d';
