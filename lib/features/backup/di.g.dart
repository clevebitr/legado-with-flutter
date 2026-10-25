// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'di.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the backup repository over every table it carries (`ADR-0073` §决策 4).

@ProviderFor(backupRepository)
final backupRepositoryProvider = BackupRepositoryProvider._();

/// Provides the backup repository over every table it carries (`ADR-0073` §决策 4).

final class BackupRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<BackupRepository>,
          BackupRepository,
          FutureOr<BackupRepository>
        >
    with $FutureModifier<BackupRepository>, $FutureProvider<BackupRepository> {
  /// Provides the backup repository over every table it carries (`ADR-0073` §决策 4).
  BackupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<BackupRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BackupRepository> create(Ref ref) {
    return backupRepository(ref);
  }
}

String _$backupRepositoryHash() => r'0603242df6acd7647b55df889e96de1185dd7180';

/// Provides the backup settings and the two key-store secrets (`ADR-0074` §决策 1/5).

@ProviderFor(backupSettingsRepository)
final backupSettingsRepositoryProvider = BackupSettingsRepositoryProvider._();

/// Provides the backup settings and the two key-store secrets (`ADR-0074` §决策 1/5).

final class BackupSettingsRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<BackupSettingsRepository>,
          BackupSettingsRepository,
          FutureOr<BackupSettingsRepository>
        >
    with
        $FutureModifier<BackupSettingsRepository>,
        $FutureProvider<BackupSettingsRepository> {
  /// Provides the backup settings and the two key-store secrets (`ADR-0074` §决策 1/5).
  BackupSettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupSettingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupSettingsRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<BackupSettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BackupSettingsRepository> create(Ref ref) {
    return backupSettingsRepository(ref);
  }
}

String _$backupSettingsRepositoryHash() =>
    r'a90bd81ca53fc59c29e6def8759830c59591f7be';

/// Provides the local archive store (`ADR-0074` §决策 1/2).

@ProviderFor(localBackupStore)
final localBackupStoreProvider = LocalBackupStoreProvider._();

/// Provides the local archive store (`ADR-0074` §决策 1/2).

final class LocalBackupStoreProvider
    extends
        $FunctionalProvider<
          LocalBackupStore,
          LocalBackupStore,
          LocalBackupStore
        >
    with $Provider<LocalBackupStore> {
  /// Provides the local archive store (`ADR-0074` §决策 1/2).
  LocalBackupStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localBackupStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localBackupStoreHash();

  @$internal
  @override
  $ProviderElement<LocalBackupStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalBackupStore create(Ref ref) {
    return localBackupStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalBackupStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalBackupStore>(value),
    );
  }
}

String _$localBackupStoreHash() => r'9860e41436a43cba9f9d4cc8786e2cd767260545';

/// Provides the WebDAV side of the backup (`ADR-0074` §决策 6).

@ProviderFor(remoteBackupStore)
final remoteBackupStoreProvider = RemoteBackupStoreProvider._();

/// Provides the WebDAV side of the backup (`ADR-0074` §决策 6).

final class RemoteBackupStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<RemoteBackupStore>,
          RemoteBackupStore,
          FutureOr<RemoteBackupStore>
        >
    with
        $FutureModifier<RemoteBackupStore>,
        $FutureProvider<RemoteBackupStore> {
  /// Provides the WebDAV side of the backup (`ADR-0074` §决策 6).
  RemoteBackupStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteBackupStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteBackupStoreHash();

  @$internal
  @override
  $FutureProviderElement<RemoteBackupStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RemoteBackupStore> create(Ref ref) {
    return remoteBackupStore(ref);
  }
}

String _$remoteBackupStoreHash() => r'0621ddd6ca919d8db5a3bd9d9f07429fd263de58';

/// Provides the export use case (`ADR-0073` §决策 2).

@ProviderFor(createBackup)
final createBackupProvider = CreateBackupProvider._();

/// Provides the export use case (`ADR-0073` §决策 2).

final class CreateBackupProvider
    extends
        $FunctionalProvider<
          AsyncValue<CreateBackup>,
          CreateBackup,
          FutureOr<CreateBackup>
        >
    with $FutureModifier<CreateBackup>, $FutureProvider<CreateBackup> {
  /// Provides the export use case (`ADR-0073` §决策 2).
  CreateBackupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'createBackupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$createBackupHash();

  @$internal
  @override
  $FutureProviderElement<CreateBackup> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CreateBackup> create(Ref ref) {
    return createBackup(ref);
  }
}

String _$createBackupHash() => r'6cf257d8812b7f6879fc4f155badb95214fe9d62';

/// Provides the "encode and write to the backup location" use case (`ADR-0074` §决策 1/2).

@ProviderFor(saveBackup)
final saveBackupProvider = SaveBackupProvider._();

/// Provides the "encode and write to the backup location" use case (`ADR-0074` §决策 1/2).

final class SaveBackupProvider
    extends
        $FunctionalProvider<
          AsyncValue<SaveBackup>,
          SaveBackup,
          FutureOr<SaveBackup>
        >
    with $FutureModifier<SaveBackup>, $FutureProvider<SaveBackup> {
  /// Provides the "encode and write to the backup location" use case (`ADR-0074` §决策 1/2).
  SaveBackupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveBackupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveBackupHash();

  @$internal
  @override
  $FutureProviderElement<SaveBackup> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SaveBackup> create(Ref ref) {
    return saveBackup(ref);
  }
}

String _$saveBackupHash() => r'4fa8317d36098e09bcd45d553eb96e5602194df5';

/// Provides the daily automatic backup (`ADR-0074` §决策 2).

@ProviderFor(autoBackup)
final autoBackupProvider = AutoBackupProvider._();

/// Provides the daily automatic backup (`ADR-0074` §决策 2).

final class AutoBackupProvider
    extends
        $FunctionalProvider<
          AsyncValue<AutoBackup>,
          AutoBackup,
          FutureOr<AutoBackup>
        >
    with $FutureModifier<AutoBackup>, $FutureProvider<AutoBackup> {
  /// Provides the daily automatic backup (`ADR-0074` §决策 2).
  AutoBackupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoBackupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoBackupHash();

  @$internal
  @override
  $FutureProviderElement<AutoBackup> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AutoBackup> create(Ref ref) {
    return autoBackup(ref);
  }
}

String _$autoBackupHash() => r'f30a5cbec63415a49bea891c93d2fef7755d8581';

/// Provides the preview use case.

@ProviderFor(inspectBackup)
final inspectBackupProvider = InspectBackupProvider._();

/// Provides the preview use case.

final class InspectBackupProvider
    extends $FunctionalProvider<InspectBackup, InspectBackup, InspectBackup>
    with $Provider<InspectBackup> {
  /// Provides the preview use case.
  InspectBackupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inspectBackupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inspectBackupHash();

  @$internal
  @override
  $ProviderElement<InspectBackup> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InspectBackup create(Ref ref) {
    return inspectBackup(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InspectBackup value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InspectBackup>(value),
    );
  }
}

String _$inspectBackupHash() => r'f26f04301f68cd90432c3e38cae8c5b535d5ad50';

/// Provides the restore use case (`ADR-0073` §决策 3 / `ADR-0074` §决策 3).

@ProviderFor(restoreBackup)
final restoreBackupProvider = RestoreBackupProvider._();

/// Provides the restore use case (`ADR-0073` §决策 3 / `ADR-0074` §决策 3).

final class RestoreBackupProvider
    extends
        $FunctionalProvider<
          AsyncValue<RestoreBackup>,
          RestoreBackup,
          FutureOr<RestoreBackup>
        >
    with $FutureModifier<RestoreBackup>, $FutureProvider<RestoreBackup> {
  /// Provides the restore use case (`ADR-0073` §决策 3 / `ADR-0074` §决策 3).
  RestoreBackupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restoreBackupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restoreBackupHash();

  @$internal
  @override
  $FutureProviderElement<RestoreBackup> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RestoreBackup> create(Ref ref) {
    return restoreBackup(ref);
  }
}

String _$restoreBackupHash() => r'4d08484d90a4f7676c4f826ea9a001cfed5d220c';

/// Provides the post-restore notification, **unbound** by default.
///
/// The composition root overrides it to invalidate `Settings` and the reader's style provider
/// (`ADR-0073` §决策 3). The default only warns, so a forgotten binding costs a stale theme, not a
/// broken restore.

@ProviderFor(restoreCompletionHook)
final restoreCompletionHookProvider = RestoreCompletionHookProvider._();

/// Provides the post-restore notification, **unbound** by default.
///
/// The composition root overrides it to invalidate `Settings` and the reader's style provider
/// (`ADR-0073` §决策 3). The default only warns, so a forgotten binding costs a stale theme, not a
/// broken restore.

final class RestoreCompletionHookProvider
    extends
        $FunctionalProvider<
          RestoreCompletionHook,
          RestoreCompletionHook,
          RestoreCompletionHook
        >
    with $Provider<RestoreCompletionHook> {
  /// Provides the post-restore notification, **unbound** by default.
  ///
  /// The composition root overrides it to invalidate `Settings` and the reader's style provider
  /// (`ADR-0073` §决策 3). The default only warns, so a forgotten binding costs a stale theme, not a
  /// broken restore.
  RestoreCompletionHookProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restoreCompletionHookProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restoreCompletionHookHash();

  @$internal
  @override
  $ProviderElement<RestoreCompletionHook> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RestoreCompletionHook create(Ref ref) {
    return restoreCompletionHook(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RestoreCompletionHook value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RestoreCompletionHook>(value),
    );
  }
}

String _$restoreCompletionHookHash() =>
    r'f4abb4cb072255e0c5d7ce6f54a4723b9a52659e';

/// The archives already in the configured location, newest first (`ADR-0074` §决策 2).

@ProviderFor(localBackups)
final localBackupsProvider = LocalBackupsProvider._();

/// The archives already in the configured location, newest first (`ADR-0074` §决策 2).

final class LocalBackupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StoredBackup>>,
          List<StoredBackup>,
          FutureOr<List<StoredBackup>>
        >
    with
        $FutureModifier<List<StoredBackup>>,
        $FutureProvider<List<StoredBackup>> {
  /// The archives already in the configured location, newest first (`ADR-0074` §决策 2).
  LocalBackupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localBackupsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localBackupsHash();

  @$internal
  @override
  $FutureProviderElement<List<StoredBackup>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StoredBackup>> create(Ref ref) {
    return localBackups(ref);
  }
}

String _$localBackupsHash() => r'd680c082fc75ab5a6f2eec3bb073e42dd805cbf1';
