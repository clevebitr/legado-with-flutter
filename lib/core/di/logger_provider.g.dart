// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logger_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The on-disk log, or `null` when the assembly root did not wire one (tests).
///
/// `main()` resolves the platform directory (it already awaits the cookie jar and the install id)
/// and overrides this provider, which keeps `appLogger` synchronous and keeps `core/logging` free of
/// `path_provider`.

@ProviderFor(logFile)
final logFileProvider = LogFileProvider._();

/// The on-disk log, or `null` when the assembly root did not wire one (tests).
///
/// `main()` resolves the platform directory (it already awaits the cookie jar and the install id)
/// and overrides this provider, which keeps `appLogger` synchronous and keeps `core/logging` free of
/// `path_provider`.

final class LogFileProvider
    extends $FunctionalProvider<LogFile?, LogFile?, LogFile?>
    with $Provider<LogFile?> {
  /// The on-disk log, or `null` when the assembly root did not wire one (tests).
  ///
  /// `main()` resolves the platform directory (it already awaits the cookie jar and the install id)
  /// and overrides this provider, which keeps `appLogger` synchronous and keeps `core/logging` free of
  /// `path_provider`.
  LogFileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logFileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logFileHash();

  @$internal
  @override
  $ProviderElement<LogFile?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LogFile? create(Ref ref) {
    return logFile(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogFile? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogFile?>(value),
    );
  }
}

String _$logFileHash() => r'03c7d70f0aebf2f3d407dcbe4e6f290b88f3dcd6';

/// Provides the application logger, the only log entry point.
///
/// Tests override it with a capturing printer; production attaches the [LogFile] above.

@ProviderFor(appLogger)
final appLoggerProvider = AppLoggerProvider._();

/// Provides the application logger, the only log entry point.
///
/// Tests override it with a capturing printer; production attaches the [LogFile] above.

final class AppLoggerProvider
    extends $FunctionalProvider<AppLogger, AppLogger, AppLogger>
    with $Provider<AppLogger> {
  /// Provides the application logger, the only log entry point.
  ///
  /// Tests override it with a capturing printer; production attaches the [LogFile] above.
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

String _$appLoggerHash() => r'e1a8dc2241f9ec1c346acb51d4a4fccb16b225a7';
