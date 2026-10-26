// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rules_list_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The rules of one [RuleKind], in manual order (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// One notifier serves all four kinds because their list operations are identical: enable, delete,
/// reorder, save. Only the edit form knows which kind it is editing.
///
/// Every write reloads the list instead of patching it in place — the stored rows are the truth, and
/// a reload is what proves the write landed (the same stance as the shelf and the bookmark list).

@ProviderFor(RulesList)
final rulesListProvider = RulesListFamily._();

/// The rules of one [RuleKind], in manual order (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// One notifier serves all four kinds because their list operations are identical: enable, delete,
/// reorder, save. Only the edit form knows which kind it is editing.
///
/// Every write reloads the list instead of patching it in place — the stored rows are the truth, and
/// a reload is what proves the write landed (the same stance as the shelf and the bookmark list).
final class RulesListProvider
    extends $AsyncNotifierProvider<RulesList, List<Rule>> {
  /// The rules of one [RuleKind], in manual order (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
  ///
  /// One notifier serves all four kinds because their list operations are identical: enable, delete,
  /// reorder, save. Only the edit form knows which kind it is editing.
  ///
  /// Every write reloads the list instead of patching it in place — the stored rows are the truth, and
  /// a reload is what proves the write landed (the same stance as the shelf and the bookmark list).
  RulesListProvider._({
    required RulesListFamily super.from,
    required RuleKind super.argument,
  }) : super(
         retry: null,
         name: r'rulesListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rulesListHash();

  @override
  String toString() {
    return r'rulesListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RulesList create() => RulesList();

  @override
  bool operator ==(Object other) {
    return other is RulesListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rulesListHash() => r'99f8568a367dee7f9c102d834ea5d6d174673a27';

/// The rules of one [RuleKind], in manual order (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// One notifier serves all four kinds because their list operations are identical: enable, delete,
/// reorder, save. Only the edit form knows which kind it is editing.
///
/// Every write reloads the list instead of patching it in place — the stored rows are the truth, and
/// a reload is what proves the write landed (the same stance as the shelf and the bookmark list).

final class RulesListFamily extends $Family
    with
        $ClassFamilyOverride<
          RulesList,
          AsyncValue<List<Rule>>,
          List<Rule>,
          FutureOr<List<Rule>>,
          RuleKind
        > {
  RulesListFamily._()
    : super(
        retry: null,
        name: r'rulesListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The rules of one [RuleKind], in manual order (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
  ///
  /// One notifier serves all four kinds because their list operations are identical: enable, delete,
  /// reorder, save. Only the edit form knows which kind it is editing.
  ///
  /// Every write reloads the list instead of patching it in place — the stored rows are the truth, and
  /// a reload is what proves the write landed (the same stance as the shelf and the bookmark list).

  RulesListProvider call(RuleKind kind) =>
      RulesListProvider._(argument: kind, from: this);

  @override
  String toString() => r'rulesListProvider';
}

/// The rules of one [RuleKind], in manual order (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// One notifier serves all four kinds because their list operations are identical: enable, delete,
/// reorder, save. Only the edit form knows which kind it is editing.
///
/// Every write reloads the list instead of patching it in place — the stored rows are the truth, and
/// a reload is what proves the write landed (the same stance as the shelf and the bookmark list).

abstract class _$RulesList extends $AsyncNotifier<List<Rule>> {
  late final _$args = ref.$arg as RuleKind;
  RuleKind get kind => _$args;

  FutureOr<List<Rule>> build(RuleKind kind);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Rule>>, List<Rule>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Rule>>, List<Rule>>,
              AsyncValue<List<Rule>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
