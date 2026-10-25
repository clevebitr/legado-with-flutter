// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives export and restore (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// The notifier owns the order the restore needs — read and preview first, write only after the user
/// confirms — because that order *is* the feature: an archive is decoded and validated completely
/// before a single row is written (ADR-0073 §决策 3).

@ProviderFor(Backup)
final backupProvider = BackupProvider._();

/// Drives export and restore (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// The notifier owns the order the restore needs — read and preview first, write only after the user
/// confirms — because that order *is* the feature: an archive is decoded and validated completely
/// before a single row is written (ADR-0073 §决策 3).
final class BackupProvider extends $NotifierProvider<Backup, BackupState> {
  /// Drives export and restore (`docs/dev/roadmap.md` M22, ADR-0073).
  ///
  /// The notifier owns the order the restore needs — read and preview first, write only after the user
  /// confirms — because that order *is* the feature: an archive is decoded and validated completely
  /// before a single row is written (ADR-0073 §决策 3).
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

String _$backupHash() => r'bb4001d0210d4bd79129dce9e59ef2b20784862e';

/// Drives export and restore (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// The notifier owns the order the restore needs — read and preview first, write only after the user
/// confirms — because that order *is* the feature: an archive is decoded and validated completely
/// before a single row is written (ADR-0073 §决策 3).

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
