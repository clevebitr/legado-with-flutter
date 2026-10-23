// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the platform facts other layers branch on.
///
/// Tests override it with a fake to simulate Android or a desktop host.

@ProviderFor(platformInfo)
final platformInfoProvider = PlatformInfoProvider._();

/// Provides the platform facts other layers branch on.
///
/// Tests override it with a fake to simulate Android or a desktop host.

final class PlatformInfoProvider
    extends $FunctionalProvider<PlatformInfo, PlatformInfo, PlatformInfo>
    with $Provider<PlatformInfo> {
  /// Provides the platform facts other layers branch on.
  ///
  /// Tests override it with a fake to simulate Android or a desktop host.
  PlatformInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformInfoProvider',
        isAutoDispose: false,
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

String _$platformInfoHash() => r'cac1cdfd452c2761363bd21226093e0ef4f8783c';

/// Provides the platform dynamic color source, or `null` when it has none.
///
/// The name avoids a generated-class collision with [DynamicColorProvider].

@ProviderFor(platformDynamicColor)
final platformDynamicColorProvider = PlatformDynamicColorProvider._();

/// Provides the platform dynamic color source, or `null` when it has none.
///
/// The name avoids a generated-class collision with [DynamicColorProvider].

final class PlatformDynamicColorProvider
    extends
        $FunctionalProvider<
          DynamicColorProvider?,
          DynamicColorProvider?,
          DynamicColorProvider?
        >
    with $Provider<DynamicColorProvider?> {
  /// Provides the platform dynamic color source, or `null` when it has none.
  ///
  /// The name avoids a generated-class collision with [DynamicColorProvider].
  PlatformDynamicColorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformDynamicColorProvider',
        isAutoDispose: false,
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
    r'e65a7da4798de930ff708a4e625ff68248e4c2ac';

/// Provides the platform file picker for book-source imports.
///
/// Unsupported platforms get a no-op picker instead of an exception.

@ProviderFor(bookSourceFilePicker)
final bookSourceFilePickerProvider = BookSourceFilePickerProvider._();

/// Provides the platform file picker for book-source imports.
///
/// Unsupported platforms get a no-op picker instead of an exception.

final class BookSourceFilePickerProvider
    extends
        $FunctionalProvider<
          BookSourceFilePicker,
          BookSourceFilePicker,
          BookSourceFilePicker
        >
    with $Provider<BookSourceFilePicker> {
  /// Provides the platform file picker for book-source imports.
  ///
  /// Unsupported platforms get a no-op picker instead of an exception.
  BookSourceFilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceFilePickerProvider',
        isAutoDispose: false,
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
    r'f7d7e3123b6a021aa45663689c93ced0c7b1817a';

/// Provides the platform save dialog for single-source export.
///
/// Unsupported platforms report `not saved` instead of throwing.

@ProviderFor(bookSourceFileSaver)
final bookSourceFileSaverProvider = BookSourceFileSaverProvider._();

/// Provides the platform save dialog for single-source export.
///
/// Unsupported platforms report `not saved` instead of throwing.

final class BookSourceFileSaverProvider
    extends
        $FunctionalProvider<
          BookSourceFileSaver,
          BookSourceFileSaver,
          BookSourceFileSaver
        >
    with $Provider<BookSourceFileSaver> {
  /// Provides the platform save dialog for single-source export.
  ///
  /// Unsupported platforms report `not saved` instead of throwing.
  BookSourceFileSaverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceFileSaverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceFileSaverHash();

  @$internal
  @override
  $ProviderElement<BookSourceFileSaver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookSourceFileSaver create(Ref ref) {
    return bookSourceFileSaver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookSourceFileSaver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookSourceFileSaver>(value),
    );
  }
}

String _$bookSourceFileSaverHash() =>
    r'324c249ec6b41181bbadd92c67a5496c0926efbf';

/// Provides the long-task marker a batch check holds while it runs.
///
/// Only Android has a real one; other platforms get a no-op.

@ProviderFor(longRunningTask)
final longRunningTaskProvider = LongRunningTaskProvider._();

/// Provides the long-task marker a batch check holds while it runs.
///
/// Only Android has a real one; other platforms get a no-op.

final class LongRunningTaskProvider
    extends
        $FunctionalProvider<LongRunningTask, LongRunningTask, LongRunningTask>
    with $Provider<LongRunningTask> {
  /// Provides the long-task marker a batch check holds while it runs.
  ///
  /// Only Android has a real one; other platforms get a no-op.
  LongRunningTaskProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'longRunningTaskProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$longRunningTaskHash();

  @$internal
  @override
  $ProviderElement<LongRunningTask> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LongRunningTask create(Ref ref) {
    return longRunningTask(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LongRunningTask value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LongRunningTask>(value),
    );
  }
}

String _$longRunningTaskHash() => r'c4f24b2ab4e07af40943e68f73e182a163752df6';

/// Provides visible-WebView verification, unbound by default.
///
/// An unbound port answers `isSupported == false`, which surfaces as
/// `unsupportedRule`.

@ProviderFor(sourceVerification)
final sourceVerificationProvider = SourceVerificationProvider._();

/// Provides visible-WebView verification, unbound by default.
///
/// An unbound port answers `isSupported == false`, which surfaces as
/// `unsupportedRule`.

final class SourceVerificationProvider
    extends
        $FunctionalProvider<
          SourceVerification,
          SourceVerification,
          SourceVerification
        >
    with $Provider<SourceVerification> {
  /// Provides visible-WebView verification, unbound by default.
  ///
  /// An unbound port answers `isSupported == false`, which surfaces as
  /// `unsupportedRule`.
  SourceVerificationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceVerificationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceVerificationHash();

  @$internal
  @override
  $ProviderElement<SourceVerification> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SourceVerification create(Ref ref) {
    return sourceVerification(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceVerification value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceVerification>(value),
    );
  }
}

String _$sourceVerificationHash() =>
    r'f8f51b442facda34452fd3c221f42a3f012cdeb3';
