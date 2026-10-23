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
        isAutoDispose: false,
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

String _$appLoggerHash() => r'3d6582c2c07f187b0607e00d8b7eeefb78431e54';
