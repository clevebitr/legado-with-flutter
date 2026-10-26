import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/cache_manage_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The cache of every book source, and the ways to drop it
/// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 1).
///
/// Upstream caches chapter bodies as files per book and offers「全部」/「按书」clearing; this page is
/// the per-source view our single cache table can answer, plus the two maintenance actions a cache
/// needs anyway (expired entries, everything).
class CacheManagePage extends ConsumerWidget {
  /// Creates the page.
  const CacheManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<CacheUsage> usage = ref.watch(cacheManageProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.cacheManageTitle),
        backgroundColor: tokens.colors.surface,
        actions: <Widget>[
          PopupMenuButton<_CacheAction>(
            tooltip: l10n.cacheManageMore,
            onSelected: (_CacheAction action) => switch (action) {
              _CacheAction.expired => unawaited(
                ref.read(cacheManageProvider.notifier).clearExpired(),
              ),
              _CacheAction.all => unawaited(
                _confirmClearAll(context, ref, l10n),
              ),
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_CacheAction>>[
                  PopupMenuItem<_CacheAction>(
                    value: _CacheAction.expired,
                    child: Text(l10n.cacheManageClearExpired),
                  ),
                  PopupMenuItem<_CacheAction>(
                    value: _CacheAction.all,
                    child: Text(l10n.cacheManageClearAll),
                  ),
                ],
          ),
        ],
      ),
      body: switch (usage) {
        AsyncData<CacheUsage>(:final CacheUsage value) => _body(
          context,
          ref,
          value,
          l10n,
          tokens,
        ),
        AsyncError<CacheUsage>() => StateMessage(
          message: l10n.cacheManageLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// The totals line plus one row per source that actually holds something.
  Widget _body(
    BuildContext context,
    WidgetRef ref,
    CacheUsage usage,
    AppLocalizations l10n,
    M3ETheme tokens,
  ) {
    final List<CacheSourceUsage> used = <CacheSourceUsage>[
      for (final CacheSourceUsage source in usage.sources)
        if (source.count > 0) source,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.xs,
          ),
          child: Text(
            l10n.cacheManageTotal(usage.total),
            style: tokens.typography.base.labelLarge,
          ),
        ),
        Expanded(
          child: used.isEmpty
              ? StateMessage(
                  message: l10n.cacheManageEmpty,
                  icon: Icons.cloud_off_outlined,
                )
              : ListView.builder(
                  itemCount: used.length,
                  itemBuilder: (BuildContext context, int index) {
                    final CacheSourceUsage source = used[index];

                    return ListTile(
                      title: Text(source.name),
                      subtitle: Text(l10n.cacheManageSourceCount(source.count)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l10n.cacheManageClearSource,
                        onPressed: () => unawaited(
                          ref
                              .read(cacheManageProvider.notifier)
                              .clearSource(source.url),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Asks before dropping the whole cache: it is the one action here that cannot be undone.
  Future<void> _confirmClearAll(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.cacheManageClearAllTitle),
        content: Text(l10n.cacheManageClearAllBody),
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
    if (confirmed ?? false) {
      await ref.read(cacheManageProvider.notifier).clearAll();
    }
  }
}

/// What the page's overflow menu can do.
enum _CacheAction { expired, all }
