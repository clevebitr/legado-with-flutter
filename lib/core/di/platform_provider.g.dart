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

@ProviderFor(jsonFilePicker)
final jsonFilePickerProvider = JsonFilePickerProvider._();

/// Provides the platform file picker for book-source imports.
///
/// Unsupported platforms get a no-op picker instead of an exception.

final class JsonFilePickerProvider
    extends $FunctionalProvider<JsonFilePicker, JsonFilePicker, JsonFilePicker>
    with $Provider<JsonFilePicker> {
  /// Provides the platform file picker for book-source imports.
  ///
  /// Unsupported platforms get a no-op picker instead of an exception.
  JsonFilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jsonFilePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jsonFilePickerHash();

  @$internal
  @override
  $ProviderElement<JsonFilePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JsonFilePicker create(Ref ref) {
    return jsonFilePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JsonFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JsonFilePicker>(value),
    );
  }
}

String _$jsonFilePickerHash() => r'2c6acd27ff8a29e555afbdc24db48da8f0c725e9';

/// Provides the system share sheet, or a no-op on platforms without one (`ADR-0083`).
///
/// Only mobile uses it today: on Android/iOS the export and log directories are private, while a
/// desktop already has a save dialog and a reachable folder. Capability detection, not a platform
/// branch in the UI, decides whether the log page offers sharing.

@ProviderFor(fileSharer)
final fileSharerProvider = FileSharerProvider._();

/// Provides the system share sheet, or a no-op on platforms without one (`ADR-0083`).
///
/// Only mobile uses it today: on Android/iOS the export and log directories are private, while a
/// desktop already has a save dialog and a reachable folder. Capability detection, not a platform
/// branch in the UI, decides whether the log page offers sharing.

final class FileSharerProvider
    extends $FunctionalProvider<FileSharer, FileSharer, FileSharer>
    with $Provider<FileSharer> {
  /// Provides the system share sheet, or a no-op on platforms without one (`ADR-0083`).
  ///
  /// Only mobile uses it today: on Android/iOS the export and log directories are private, while a
  /// desktop already has a save dialog and a reachable folder. Capability detection, not a platform
  /// branch in the UI, decides whether the log page offers sharing.
  FileSharerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileSharerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileSharerHash();

  @$internal
  @override
  $ProviderElement<FileSharer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileSharer create(Ref ref) {
    return fileSharer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileSharer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileSharer>(value),
    );
  }
}

String _$fileSharerHash() => r'2b9d48b785ff6afdcacd01a37b1cd9e848dd6ff3';

/// Provides the platform save path for single-source export.
///
/// Mobile platforms have no save dialog, so they hand the document to the system share sheet
/// (`ADR-0083`). Unsupported platforms report `not saved` instead of throwing.

@ProviderFor(jsonFileSaver)
final jsonFileSaverProvider = JsonFileSaverProvider._();

/// Provides the platform save path for single-source export.
///
/// Mobile platforms have no save dialog, so they hand the document to the system share sheet
/// (`ADR-0083`). Unsupported platforms report `not saved` instead of throwing.

final class JsonFileSaverProvider
    extends $FunctionalProvider<JsonFileSaver, JsonFileSaver, JsonFileSaver>
    with $Provider<JsonFileSaver> {
  /// Provides the platform save path for single-source export.
  ///
  /// Mobile platforms have no save dialog, so they hand the document to the system share sheet
  /// (`ADR-0083`). Unsupported platforms report `not saved` instead of throwing.
  JsonFileSaverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jsonFileSaverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jsonFileSaverHash();

  @$internal
  @override
  $ProviderElement<JsonFileSaver> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JsonFileSaver create(Ref ref) {
    return jsonFileSaver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JsonFileSaver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JsonFileSaver>(value),
    );
  }
}

String _$jsonFileSaverHash() => r'dd7cd423ca70e9787c788f80a30a9506fa6bb021';

/// Provides the platform save path for backups (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// Mobile platforms share the archive instead of opening a save dialog (`ADR-0083`). Unsupported
/// platforms report `not saved` instead of throwing.

@ProviderFor(backupArchiveSaver)
final backupArchiveSaverProvider = BackupArchiveSaverProvider._();

/// Provides the platform save path for backups (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// Mobile platforms share the archive instead of opening a save dialog (`ADR-0083`). Unsupported
/// platforms report `not saved` instead of throwing.

final class BackupArchiveSaverProvider
    extends
        $FunctionalProvider<
          BackupArchiveSaver,
          BackupArchiveSaver,
          BackupArchiveSaver
        >
    with $Provider<BackupArchiveSaver> {
  /// Provides the platform save path for backups (`docs/dev/roadmap.md` M22, ADR-0073).
  ///
  /// Mobile platforms share the archive instead of opening a save dialog (`ADR-0083`). Unsupported
  /// platforms report `not saved` instead of throwing.
  BackupArchiveSaverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupArchiveSaverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupArchiveSaverHash();

  @$internal
  @override
  $ProviderElement<BackupArchiveSaver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackupArchiveSaver create(Ref ref) {
    return backupArchiveSaver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupArchiveSaver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupArchiveSaver>(value),
    );
  }
}

String _$backupArchiveSaverHash() =>
    r'c611ae117e9419c77e47dae2c6db5e87ec0a04b3';

/// Provides the platform open dialog for backups (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// Unsupported platforms answer “nothing picked” instead of throwing.

@ProviderFor(backupArchivePicker)
final backupArchivePickerProvider = BackupArchivePickerProvider._();

/// Provides the platform open dialog for backups (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// Unsupported platforms answer “nothing picked” instead of throwing.

final class BackupArchivePickerProvider
    extends
        $FunctionalProvider<
          BackupArchivePicker,
          BackupArchivePicker,
          BackupArchivePicker
        >
    with $Provider<BackupArchivePicker> {
  /// Provides the platform open dialog for backups (`docs/dev/roadmap.md` M22, ADR-0073).
  ///
  /// Unsupported platforms answer “nothing picked” instead of throwing.
  BackupArchivePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupArchivePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupArchivePickerHash();

  @$internal
  @override
  $ProviderElement<BackupArchivePicker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackupArchivePicker create(Ref ref) {
    return backupArchivePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupArchivePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupArchivePicker>(value),
    );
  }
}

String _$backupArchivePickerHash() =>
    r'b418885595d7f2608a7a967a19cea0fea085e17b';

/// Provides the platform key store for the backup and WebDAV passwords
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 5).
///
/// Only Android / iOS / Windows ship a key store here; the other platforms answer “not stored” and
/// the backup page says the archive stays unencrypted rather than pretending otherwise.

@ProviderFor(secretStore)
final secretStoreProvider = SecretStoreProvider._();

/// Provides the platform key store for the backup and WebDAV passwords
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 5).
///
/// Only Android / iOS / Windows ship a key store here; the other platforms answer “not stored” and
/// the backup page says the archive stays unencrypted rather than pretending otherwise.

final class SecretStoreProvider
    extends $FunctionalProvider<SecretStore, SecretStore, SecretStore>
    with $Provider<SecretStore> {
  /// Provides the platform key store for the backup and WebDAV passwords
  /// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 5).
  ///
  /// Only Android / iOS / Windows ship a key store here; the other platforms answer “not stored” and
  /// the backup page says the archive stays unencrypted rather than pretending otherwise.
  SecretStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secretStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secretStoreHash();

  @$internal
  @override
  $ProviderElement<SecretStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecretStore create(Ref ref) {
    return secretStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecretStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecretStore>(value),
    );
  }
}

String _$secretStoreHash() => r'665c45ceb4c7ded7b53c4b086b4b6b9b4b86940c';

/// Provides the folder dialog the backup location is chosen with (ADR-0074 §决策 1).

@ProviderFor(backupDirectoryPicker)
final backupDirectoryPickerProvider = BackupDirectoryPickerProvider._();

/// Provides the folder dialog the backup location is chosen with (ADR-0074 §决策 1).

final class BackupDirectoryPickerProvider
    extends
        $FunctionalProvider<
          BackupDirectoryPicker,
          BackupDirectoryPicker,
          BackupDirectoryPicker
        >
    with $Provider<BackupDirectoryPicker> {
  /// Provides the folder dialog the backup location is chosen with (ADR-0074 §决策 1).
  BackupDirectoryPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupDirectoryPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupDirectoryPickerHash();

  @$internal
  @override
  $ProviderElement<BackupDirectoryPicker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackupDirectoryPicker create(Ref ref) {
    return backupDirectoryPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupDirectoryPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupDirectoryPicker>(value),
    );
  }
}

String _$backupDirectoryPickerHash() =>
    r'916608672e8264703ff018e74bef6d355a0bf1b6';

/// Provides the image dialog the theme background is chosen with (`ADR-0075` §决策 1).

@ProviderFor(backgroundImagePicker)
final backgroundImagePickerProvider = BackgroundImagePickerProvider._();

/// Provides the image dialog the theme background is chosen with (`ADR-0075` §决策 1).

final class BackgroundImagePickerProvider
    extends
        $FunctionalProvider<
          BackgroundImagePicker,
          BackgroundImagePicker,
          BackgroundImagePicker
        >
    with $Provider<BackgroundImagePicker> {
  /// Provides the image dialog the theme background is chosen with (`ADR-0075` §决策 1).
  BackgroundImagePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundImagePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundImagePickerHash();

  @$internal
  @override
  $ProviderElement<BackgroundImagePicker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackgroundImagePicker create(Ref ref) {
    return backgroundImagePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundImagePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundImagePicker>(value),
    );
  }
}

String _$backgroundImagePickerHash() =>
    r'66a3dc5328016972bafc548f424c00a9cefe7cf4';

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

/// Provides the install id `java.androidId` answers with (M25/S3b).
///
/// The holder is read **synchronously** from every job, so `main()` awaits `InstallId.hydrate`
/// before the first frame (the cookie jar's pattern, ADR-0068 §决策 4). A build that never hydrated
/// it answers `''`, which is what the sandbox does when the host has no id.

@ProviderFor(installId)
final installIdProvider = InstallIdProvider._();

/// Provides the install id `java.androidId` answers with (M25/S3b).
///
/// The holder is read **synchronously** from every job, so `main()` awaits `InstallId.hydrate`
/// before the first frame (the cookie jar's pattern, ADR-0068 §决策 4). A build that never hydrated
/// it answers `''`, which is what the sandbox does when the host has no id.

final class InstallIdProvider
    extends $FunctionalProvider<InstallId, InstallId, InstallId>
    with $Provider<InstallId> {
  /// Provides the install id `java.androidId` answers with (M25/S3b).
  ///
  /// The holder is read **synchronously** from every job, so `main()` awaits `InstallId.hydrate`
  /// before the first frame (the cookie jar's pattern, ADR-0068 §决策 4). A build that never hydrated
  /// it answers `''`, which is what the sandbox does when the host has no id.
  InstallIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installIdHash();

  @$internal
  @override
  $ProviderElement<InstallId> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InstallId create(Ref ref) {
    return installId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallId value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallId>(value),
    );
  }
}

String _$installIdHash() => r'b9731d8589a58bb8598e109e9f1cb435b1782733';

/// Provides the confirmation dialog `java.openUrl` shows before a rule opens an address.
///
/// Silent by default for the same reason as [sourceVerification]: `core/` cannot show a widget, so
/// the composition root binds the real one. A build without the override still runs every rule —
/// the bridge logs the address it refused to open.

@ProviderFor(externalUrlOpener)
final externalUrlOpenerProvider = ExternalUrlOpenerProvider._();

/// Provides the confirmation dialog `java.openUrl` shows before a rule opens an address.
///
/// Silent by default for the same reason as [sourceVerification]: `core/` cannot show a widget, so
/// the composition root binds the real one. A build without the override still runs every rule —
/// the bridge logs the address it refused to open.

final class ExternalUrlOpenerProvider
    extends
        $FunctionalProvider<
          ExternalUrlOpener,
          ExternalUrlOpener,
          ExternalUrlOpener
        >
    with $Provider<ExternalUrlOpener> {
  /// Provides the confirmation dialog `java.openUrl` shows before a rule opens an address.
  ///
  /// Silent by default for the same reason as [sourceVerification]: `core/` cannot show a widget, so
  /// the composition root binds the real one. A build without the override still runs every rule —
  /// the bridge logs the address it refused to open.
  ExternalUrlOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalUrlOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalUrlOpenerHash();

  @$internal
  @override
  $ProviderElement<ExternalUrlOpener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExternalUrlOpener create(Ref ref) {
    return externalUrlOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExternalUrlOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExternalUrlOpener>(value),
    );
  }
}

String _$externalUrlOpenerHash() => r'4c8d2aed52e421567304648d3d1b4a4bd7260fa7';

/// Provides WebView support for `,{webView:…}` rules and `java.webView`; unsupported by default.
///
/// It lives in `core/di/` because two features use it (the source engine's page fetch and the JS
/// sandbox) and `core/` may not import `features/` (C-ARCH-2). The real implementation is bound by
/// the composition root; the default answers `unsupportedRule`, which makes a forgotten binding a
/// readable failure instead of a rule that silently sees an unrendered page.

@ProviderFor(webPageFetcher)
final webPageFetcherProvider = WebPageFetcherProvider._();

/// Provides WebView support for `,{webView:…}` rules and `java.webView`; unsupported by default.
///
/// It lives in `core/di/` because two features use it (the source engine's page fetch and the JS
/// sandbox) and `core/` may not import `features/` (C-ARCH-2). The real implementation is bound by
/// the composition root; the default answers `unsupportedRule`, which makes a forgotten binding a
/// readable failure instead of a rule that silently sees an unrendered page.

final class WebPageFetcherProvider
    extends $FunctionalProvider<WebPageFetcher, WebPageFetcher, WebPageFetcher>
    with $Provider<WebPageFetcher> {
  /// Provides WebView support for `,{webView:…}` rules and `java.webView`; unsupported by default.
  ///
  /// It lives in `core/di/` because two features use it (the source engine's page fetch and the JS
  /// sandbox) and `core/` may not import `features/` (C-ARCH-2). The real implementation is bound by
  /// the composition root; the default answers `unsupportedRule`, which makes a forgotten binding a
  /// readable failure instead of a rule that silently sees an unrendered page.
  WebPageFetcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webPageFetcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webPageFetcherHash();

  @$internal
  @override
  $ProviderElement<WebPageFetcher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WebPageFetcher create(Ref ref) {
    return webPageFetcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebPageFetcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebPageFetcher>(value),
    );
  }
}

String _$webPageFetcherHash() => r'e258afa898dc2d848748bdf28feb5fe1fe8478d9';
