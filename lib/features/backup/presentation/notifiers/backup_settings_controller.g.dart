// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The backup settings and the only place that writes them
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/5).
///
/// Reading and writing go through [BackupSettingsRepository], so this class never touches
/// `shared_preferences` or the key store; it only turns user intents into a saved entity.

@ProviderFor(BackupSettingsController)
final backupSettingsControllerProvider = BackupSettingsControllerProvider._();

/// The backup settings and the only place that writes them
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/5).
///
/// Reading and writing go through [BackupSettingsRepository], so this class never touches
/// `shared_preferences` or the key store; it only turns user intents into a saved entity.
final class BackupSettingsControllerProvider
    extends $AsyncNotifierProvider<BackupSettingsController, BackupSettings> {
  /// The backup settings and the only place that writes them
  /// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/5).
  ///
  /// Reading and writing go through [BackupSettingsRepository], so this class never touches
  /// `shared_preferences` or the key store; it only turns user intents into a saved entity.
  BackupSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupSettingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupSettingsControllerHash();

  @$internal
  @override
  BackupSettingsController create() => BackupSettingsController();
}

String _$backupSettingsControllerHash() =>
    r'fb1913b45b7a089f02502bf48f9a959a1d131032';

/// The backup settings and the only place that writes them
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1/5).
///
/// Reading and writing go through [BackupSettingsRepository], so this class never touches
/// `shared_preferences` or the key store; it only turns user intents into a saved entity.

abstract class _$BackupSettingsController
    extends $AsyncNotifier<BackupSettings> {
  FutureOr<BackupSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BackupSettings>, BackupSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BackupSettings>, BackupSettings>,
              AsyncValue<BackupSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
