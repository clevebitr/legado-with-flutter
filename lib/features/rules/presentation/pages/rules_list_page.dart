import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/presentation/notifiers/rules_list_notifier.dart';
import 'package:flutter_reader/features/rules/presentation/rules_route.dart';
import 'package:flutter_reader/features/rules/presentation/rules_strings.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// One kind's rules: switch them on and off, drag them into order, delete, edit
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// Four kinds share this page — the operations are the same code, and the rows differ only in what
/// their payload is summarised as. Tapping a row opens the kind's form; the order is meaningful for
/// 「替换净化」 (the rules run top to bottom) and harmless for the others.
class RulesListPage extends ConsumerWidget {
  /// Creates the page for [kind].
  const RulesListPage({required this.kind, super.key});

  /// Which rules this page manages.
  final RuleKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<Rule>> rules = ref.watch(rulesListProvider(kind));

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(rulesTitle(l10n, kind)),
        backgroundColor: tokens.colors.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => pushRulesRoute(context, RulesRoute.edit(kind: kind)),
        icon: const Icon(Icons.add),
        label: Text(l10n.rulesAdd),
      ),
      body: switch (rules) {
        AsyncData<List<Rule>>(:final List<Rule> value) =>
          value.isEmpty
              ? StateMessage(message: l10n.rulesEmpty)
              : _list(context, ref, value, tokens, l10n),
        // 读不出来与「一条规则也没有」是两件事：空态会让人以为规则被删光了。
        AsyncError<List<Rule>>() => StateMessage(message: l10n.rulesLoadFailed),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Builds the draggable list (C-PERF-2: lazily built, so a long import still scrolls).
  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<Rule> rules,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => ReorderableListView.builder(
    padding: EdgeInsets.only(
      top: tokens.spacing.sm,
      // FAB 会盖住最后一行：给它留出一颗按钮的高度。
      bottom: tokens.spacing.xxl * 2,
    ),
    itemCount: rules.length,
    // `onReorderItem` 已经把「先移除再插入」的下标差算好了，不需要自己减一。
    onReorderItem: (int oldIndex, int newIndex) =>
        _onReorder(ref, rules, oldIndex, newIndex),
    itemBuilder: (BuildContext context, int index) {
      final Rule rule = rules[index];

      return _Row(
        // 拖动的身份是行 id，不是下标：重排过程中下标会变。
        key: ValueKey<int>(rule.id),
        kind: kind,
        rule: rule,
        index: index,
        tokens: tokens,
        l10n: l10n,
        onEnabledChanged: (bool isEnabled) => ref
            .read(rulesListProvider(kind).notifier)
            .setEnabled(id: rule.id, isEnabled: isEnabled),
        onDelete: () =>
            ref.read(rulesListProvider(kind).notifier).remove(rule.id),
        onTap: () => pushRulesRoute(
          context,
          RulesRoute.edit(kind: kind, ruleId: rule.id),
        ),
      );
    },
  );

  /// Turns a drag into the kind's new id order and stores it.
  void _onReorder(WidgetRef ref, List<Rule> rules, int oldIndex, int newIndex) {
    // 两个下标都是**移除之前**的坐标系，所以先取出被拖的那一行再插入目标位置。
    final int moved = rules[oldIndex].id;
    final List<int> order = <int>[for (final Rule rule in rules) rule.id]
      ..removeAt(oldIndex);
    order.insert(newIndex, moved);

    ref.read(rulesListProvider(kind).notifier).reorder(order);
  }
}

/// One stored rule as a list row.
class _Row extends StatelessWidget {
  const _Row({
    required this.kind,
    required this.rule,
    required this.index,
    required this.tokens,
    required this.l10n,
    required this.onEnabledChanged,
    required this.onDelete,
    required this.onTap,
    super.key,
  });

  final RuleKind kind;
  final Rule rule;
  final int index;
  final M3ETheme tokens;
  final AppLocalizations l10n;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isBroken = rule.payload is MalformedPayload;

    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: Icon(Icons.drag_handle, semanticLabel: l10n.rulesReorderHandle),
      ),
      title: Text(rule.name),
      subtitle: Text(
        <String>[
          if (isBroken) l10n.rulesBroken else ruleSummary(l10n, rule.payload),
          if (rule.isBuiltIn) l10n.rulesBuiltIn,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: isBroken
            ? tokens.typography.base.bodySmall?.copyWith(
                color: tokens.colors.error,
              )
            : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch(value: rule.isEnabled, onChanged: onEnabledChanged),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.actionDelete,
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
