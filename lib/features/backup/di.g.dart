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

/// Provides the restore use case (`ADR-0073` §决策 3).

@ProviderFor(restoreBackup)
final restoreBackupProvider = RestoreBackupProvider._();

/// Provides the restore use case (`ADR-0073` §决策 3).

final class RestoreBackupProvider
    extends
        $FunctionalProvider<
          AsyncValue<RestoreBackup>,
          RestoreBackup,
          FutureOr<RestoreBackup>
        >
    with $FutureModifier<RestoreBackup>, $FutureProvider<RestoreBackup> {
  /// Provides the restore use case (`ADR-0073` §决策 3).
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

String _$restoreBackupHash() => r'5888f09a6a0b52a8825ff6c9507dd978e34292fa';

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
