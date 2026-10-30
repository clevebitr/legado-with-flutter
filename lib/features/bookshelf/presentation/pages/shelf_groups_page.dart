import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_group.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/shelf_groups_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Creates, renames, reorders and deletes the shelf groups (`docs/dev/roadmap.md` M19).
///
/// Reordering is drag-and-drop on a [ReorderableListView] and every write goes through
/// [ShelfGroups], so the page never touches the repository. Deleting a group keeps its books
/// (ADR-0066 §决策 2) and the confirmation says so, because 「删除分组」 reads like 「删除这些书」.
class ShelfGroupsPage extends ConsumerWidget {
  /// Creates the page.
  const ShelfGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<ShelfGroup>> groups = ref.watch(shelfGroupsProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.shelfGroupsTitle),
        backgroundColor: tokens.colors.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_create(context, ref, l10n)),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: Text(l10n.shelfGroupCreate),
      ),
      body: switch (groups) {
        AsyncData<List<ShelfGroup>>(:final List<ShelfGroup> value) =>
          value.isEmpty
              ? StateMessage(
                  message: l10n.shelfGroupsEmpty,
                  icon: Icons.folder_outlined,
                )
              : _list(context, ref, value, tokens, l10n),
        AsyncError<List<ShelfGroup>>() => StateMessage(
          message: l10n.shelfLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Builds the draggable list of groups.
  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<ShelfGroup> groups,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => ReorderableListView.builder(
    padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
    itemCount: groups.length,
    // 拖拽结束才写：`sortOrder` 是归一化后的整体顺序，逐帧写会发出 n 次更新。
    // `onReorderItem` 已经替调用方修正过 newIndex（旧 `onReorder` 需要自己 -1）。
    onReorderItem: (int oldIndex, int newIndex) {
      final List<ShelfGroup> next = List<ShelfGroup>.of(groups);
      next.insert(newIndex, next.removeAt(oldIndex));
      unawaited(
        _run(
          context,
          () => ref
              .read(shelfGroupsProvider.notifier)
              .reorder(next.map((ShelfGroup group) => group.id).toList()),
          l10n,
        ),
      );
    },
    itemBuilder: (BuildContext context, int index) {
      final ShelfGroup group = groups[index];

      return ListTile(
        key: ValueKey<int>(group.id),
        leading: const Icon(Icons.folder_outlined),
        title: Text(group.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.shelfGroupRename,
              onPressed: () => unawaited(_rename(context, ref, group, l10n)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.shelfGroupDelete,
              onPressed: () => unawaited(_delete(context, ref, group, l10n)),
            ),
          ],
        ),
      );
    },
  );

  /// Asks for a name and creates a group.
  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final String? name = await _askName(context, l10n, l10n.shelfGroupCreate);
    if (name == null || !context.mounted) {
      return;
    }
    await _run(
      context,
      () => ref.read(shelfGroupsProvider.notifier).create(name),
      l10n,
    );
  }

  /// Asks for a new name and renames [group].
  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ShelfGroup group,
    AppLocalizations l10n,
  ) async {
    final String? name = await _askName(
      context,
      l10n,
      l10n.shelfGroupRenameTitle,
      initial: group.name,
    );
    if (name == null || !context.mounted) {
      return;
    }
    await _run(
      context,
      () => ref
          .read(shelfGroupsProvider.notifier)
          .rename(id: group.id, name: name),
      l10n,
    );
  }

  /// Confirms and deletes [group] (its books stay on the shelf).
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ShelfGroup group,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.shelfGroupDeleteTitle),
        content: Text(l10n.shelfGroupDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await _run(
      context,
      () => ref.read(shelfGroupsProvider.notifier).delete(group.id),
      l10n,
    );
  }

  /// Asks for a group name; `null` means the dialog was dismissed.
  Future<String?> _askName(
    BuildContext context,
    AppLocalizations l10n,
    String title, {
    String initial = '',
  }) => showDialog<String>(
    context: context,
    builder: (BuildContext context) =>
        _GroupNameDialog(title: title, initial: initial, l10n: l10n),
  );

  /// Runs one write and reports a failure the same way the shelf page does.
  Future<void> _run(
    BuildContext context,
    Future<ParseResult<void>> Function() action,
    AppLocalizations l10n,
  ) async {
    final ParseResult<void> result = await action();
    if (!context.mounted || result is! ParseFailure<void>) {
      return;
    }
    // 重名与空名是可预期结果（`ShelfGroups` 返回失败值），不是崩溃：一条提示就够了。
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.shelfGroupNameTaken)));
  }
}

/// The dialog that asks for one group name.
///
/// It is a [StatefulWidget] so the [TextEditingController] belongs to a state object: the page
/// cannot dispose it right after `showDialog` returns, because the dialog's exit animation still
/// builds the field for a few frames (a controller disposed there throws “used after disposed”).
class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({
    required this.title,
    required this.initial,
    required this.l10n,
  });

  final String title;
  final String initial;
  final AppLocalizations l10n;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

/// State of [_GroupNameDialog]: owns the controller.
class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(hintText: widget.l10n.shelfGroupNameHint),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.l10n.actionCancel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: Text(widget.l10n.actionSave),
      ),
    ],
  );
}
