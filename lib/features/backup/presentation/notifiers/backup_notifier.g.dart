// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives every backup action (`docs/dev/roadmap.md` M22, ADR-0073 / ADR-0074).
///
/// Three orders are owned here because they *are* the feature:
///
/// * an archive is decoded and validated completely before a single row is written;
/// * an overwrite restore writes a safety copy first and aborts when that copy fails;
/// * an encrypted archive asks for its password only after the codec said it needs one.

@ProviderFor(Backup)
final backupProvider = BackupProvider._();

/// Drives every backup action (`docs/dev/roadmap.md` M22, ADR-0073 / ADR-0074).
///
/// Three orders are owned here because they *are* the feature:
///
/// * an archive is decoded and validated completely before a single row is written;
/// * an overwrite restore writes a safety copy first and aborts when that copy fails;
/// * an encrypted archive asks for its password only after the codec said it needs one.
final class BackupProvider extends $NotifierProvider<Backup, BackupState> {
  /// Drives every backup action (`docs/dev/roadmap.md` M22, ADR-0073 / ADR-0074).
  ///
  /// Three orders are owned here because they *are* the feature:
  ///
  /// * an archive is decoded and validated completely before a single row is written;
  /// * an overwrite restore writes a safety copy first and aborts when that copy fails;
  /// * an encrypted archive asks for its password only after the codec said it needs one.
  BackupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupHash();

  @$internal
  @override
  Backup create() => Backup();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupState>(value),
    );
  }
}

String _$backupHash() => r'8be8f1459c47a6945fa2af83e47ee4fde36f953f';

/// Drives every backup action (`docs/dev/roadmap.md` M22, ADR-0073 / ADR-0074).
///
/// Three orders are owned here because they *are* the feature:
///
/// * an archive is decoded and validated completely before a single row is written;
/// * an overwrite restore writes a safety copy first and aborts when that copy fails;
/// * an encrypted archive asks for its password only after the codec said it needs one.

abstract class _$Backup extends $Notifier<BackupState> {
  BackupState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BackupState, BackupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BackupState, BackupState>,
              BackupState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
