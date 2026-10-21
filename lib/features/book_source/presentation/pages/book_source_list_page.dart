import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Lists the imported book sources and manages the selected one (`docs/dev/roadmap.md` 5.1).
///
/// Accessibility (C-UI-7): the import action is an [IconButton] with a tooltip, the "current"
/// marker and the per-row actions carry their own labels, and every row is a [ListTile], whose
/// text is its semantics label.
class BookSourceListPage extends ConsumerWidget {
  /// Creates the page.
  const BookSourceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<StoredBookSource>> sources = ref.watch(
      bookSourceListProvider,
    );
    final int? selectedId = ref.watch(selectedBookSourceProvider).value?.id;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceListTitle),
        backgroundColor: tokens.colors.surface,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: l10n.bookSourceCheckTitle,
            onPressed: () => pushBookSourceRoute(
              context,
              const BookSourceRoute.checkSources(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.actionImport,
            onPressed: () => pushBookSourceRoute(
              context,
              const BookSourceRoute.importSources(),
            ),
          ),
        ],
      ),
      body: switch (sources) {
        AsyncLoading<List<StoredBookSource>>() => const Center(
          child: CircularProgressIndicator(),
        ),
        // 存储层自己是唯一会在这里抛异常的地方（C-ERR-2 允许 presentation 兜底）：
        // 给一条可重试的说明，而不是一个空白页。
        AsyncError<List<StoredBookSource>>() => _loadFailed(context, ref, l10n),
        AsyncData<List<StoredBookSource>>(
          :final List<StoredBookSource> value,
        ) =>
          value.isEmpty
              ? _empty(context, l10n)
              : _sources(context, ref, l10n, value, selectedId),
      },
    );
  }

  /// The state shown when reading the stored sources failed.
  Widget _loadFailed(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.bookSourceListLoadFailed,
              textAlign: TextAlign.center,
              style: tokens.typography.base.bodyLarge,
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton(
              onPressed: () => ref.invalidate(bookSourceListProvider),
              child: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }

  /// The state shown while no source is stored: the way in is the import screen.
  Widget _empty(BuildContext context, AppLocalizations l10n) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.bookSourceListEmpty,
              textAlign: TextAlign.center,
              style: tokens.typography.base.bodyLarge,
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton(
              onPressed: () => pushBookSourceRoute(
                context,
                const BookSourceRoute.importSources(),
              ),
              child: Text(l10n.actionImport),
            ),
          ],
        ),
      ),
    );
  }

  /// The lazily built source list (C-PERF-2).
  Widget _sources(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<StoredBookSource> sources,
    int? selectedId,
  ) => ListView.builder(
    itemCount: sources.length,
    itemBuilder: (BuildContext context, int index) {
      final StoredBookSource source = sources[index];

      return _BookSourceTile(
        source: source,
        isSelected: source.id == selectedId,
        // 同 URL 的多条变体在列表里逐条呈现（ADR-0040 §决策 3），但用户得知道
        // 「这几条是同一站点的不同规则串」，否则会以为是重复行。
        hasVariant: _hasVariant(sources, source),
        onSelect: () => unawaited(
          ref.read(selectedBookSourceProvider.notifier).select(source.id),
        ),
        onToggle: (bool isEnabled) => unawaited(
          ref
              .read(selectedBookSourceProvider.notifier)
              .toggleEnabled(id: source.id, isEnabled: isEnabled),
        ),
        onDelete: () => unawaited(_confirmDelete(context, ref, l10n, source)),
      );
    },
  );

  /// Whether another stored source shares this one's URL.
  bool _hasVariant(List<StoredBookSource> sources, StoredBookSource source) {
    for (final StoredBookSource other in sources) {
      if (other.id != source.id && other.source.url == source.source.url) {
        return true;
      }

      continue;
    }

    return false;
  }

  /// Asks before deleting, then deletes and lets the selection fall back.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    StoredBookSource source,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.bookSourceListDeleteTitle),
            content: Text(l10n.bookSourceListDeleteBody(source.source.name)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.actionDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    await ref.read(selectedBookSourceProvider.notifier).remove(source.id);
  }
}

/// One row of the source list.
class _BookSourceTile extends StatelessWidget {
  /// Creates the row.
  const _BookSourceTile({
    required this.source,
    required this.isSelected,
    required this.hasVariant,
    required this.onSelect,
    required this.onToggle,
    required this.onDelete,
  });

  /// The row's source.
  final StoredBookSource source;

  /// Whether this row is the one the pages work with.
  final bool isSelected;

  /// Whether another row shares the same `bookSourceUrl`.
  final bool hasVariant;

  /// Called when the user taps the row.
  final VoidCallback onSelect;

  /// Called when the user flips the enable switch.
  final ValueChanged<bool> onToggle;

  /// Called when the user asks to delete the row.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return ListTile(
      onTap: onSelect,
      selected: isSelected,
      leading: isSelected
          ? Icon(
              Icons.check_circle,
              color: tokens.colors.primary,
              semanticLabel: l10n.bookSourceCurrentLabel,
            )
          : const Icon(Icons.circle_outlined),
      title: Text(source.source.name),
      subtitle: Text(
        <String>[
          source.source.url,
          if (hasVariant) l10n.bookSourceVariantLabel,
        ].join('\n'),
      ),
      isThreeLine: hasVariant,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch(value: source.isEnabled, onChanged: onToggle),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.actionDelete,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
