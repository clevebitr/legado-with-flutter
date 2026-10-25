import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/features/rules/di.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rules_list_notifier.g.dart';

/// The rules of one [RuleKind], in manual order (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// One notifier serves all four kinds because their list operations are identical: enable, delete,
/// reorder, save. Only the edit form knows which kind it is editing.
///
/// Every write reloads the list instead of patching it in place — the stored rows are the truth, and
/// a reload is what proves the write landed (the same stance as the shelf and the bookmark list).
@riverpod
class RulesList extends _$RulesList {
  @override
  Future<List<Rule>> build(RuleKind kind) async {
    final RuleRepository repository = await ref.watch(
      ruleRepositoryProvider.future,
    );

    return repository.ofKind(kind);
  }

  /// Turns one rule on or off and reloads.
  Future<void> setEnabled({required int id, required bool isEnabled}) => _apply(
    (RuleRepository repository) =>
        repository.setEnabled(id: id, isEnabled: isEnabled),
  );

  /// Deletes one rule and reloads.
  Future<void> remove(int id) =>
      _apply((RuleRepository repository) => repository.delete(id));

  /// Rewrites the order of this kind from [orderedIds] and reloads.
  Future<void> reorder(List<int> orderedIds) => _apply(
    (RuleRepository repository) =>
        repository.reorder(kind: kind, orderedIds: orderedIds),
  );

  /// Creates a rule from [draft], or rewrites the rule [id] — then reloads.
  ///
  /// The kind never changes and the two fields the form does not own (`isBuiltIn`, `sortOrder`)
  /// come from the stored row, so editing a built-in rule keeps it marked as one.
  Future<void> save({required RuleDraft draft, int? id}) =>
      _apply((RuleRepository repository) async {
        final Rule? existing = id == null ? null : _find(id);
        if (id == null) {
          await repository.create(draft);

          return;
        }
        if (existing == null) {
          // 行在别的路径上被删了（例如另一个页面）：什么也不做，重载后它自然消失。
          return;
        }
        await repository.save(
          existing.copyWith(
            name: draft.name,
            payload: draft.payload,
            isEnabled: draft.isEnabled,
          ),
        );
      });

  /// The rule with [id] in the current list, or `null` when it is not there (yet).
  Rule? _find(int id) {
    for (final Rule rule in state.value ?? const <Rule>[]) {
      if (rule.id == id) {
        return rule;
      }
    }

    return null;
  }

  /// Runs [write] and reloads; a failed write leaves the list as it was.
  ///
  /// Swallowing the failure at this boundary is C-ERR-2's presentation fallback: the row is still in
  /// the table (that is what "the write failed" means), so the honest view is the unchanged list plus
  /// a log record — turning the page into an error screen would hide rules that are still there.
  Future<void> _apply(
    Future<void> Function(RuleRepository repository) write,
  ) async {
    final RuleRepository repository = await ref.read(
      ruleRepositoryProvider.future,
    );

    try {
      await write(repository);
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('Writing a rule failed.', error, stackTrace);

      return;
    }

    state = await AsyncValue.guard<List<Rule>>(() => repository.ofKind(kind));
  }
}
