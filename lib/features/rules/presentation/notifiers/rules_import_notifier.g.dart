// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rules_import_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs one replace-rule import (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
///
/// Same shape as the book-source import: preview first, commit what the user ticked, never touch a
/// rule the file does not mention.

@ProviderFor(RulesImportNotifier)
final rulesImportProvider = RulesImportNotifierProvider._();

/// Runs one replace-rule import (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
///
/// Same shape as the book-source import: preview first, commit what the user ticked, never touch a
/// rule the file does not mention.
final class RulesImportNotifierProvider
    extends $NotifierProvider<RulesImportNotifier, RulesImportState> {
  /// Runs one replace-rule import (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
  ///
  /// Same shape as the book-source import: preview first, commit what the user ticked, never touch a
  /// rule the file does not mention.
  RulesImportNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rulesImportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rulesImportNotifierHash();

  @$internal
  @override
  RulesImportNotifier create() => RulesImportNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RulesImportState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RulesImportState>(value),
    );
  }
}

String _$rulesImportNotifierHash() =>
    r'7b821be7d64dd922be4d5d75f698d26b1c771c45';

/// Runs one replace-rule import (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
///
/// Same shape as the book-source import: preview first, commit what the user ticked, never touch a
/// rule the file does not mention.

abstract class _$RulesImportNotifier extends $Notifier<RulesImportState> {
  RulesImportState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RulesImportState, RulesImportState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RulesImportState, RulesImportState>,
              RulesImportState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
