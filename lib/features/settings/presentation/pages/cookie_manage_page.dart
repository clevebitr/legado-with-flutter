import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/settings/presentation/notifiers/cookie_manage_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The stored cookie jar: what is there, and how to drop it
/// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 2).
///
/// The values are **not** shown: they are session credentials, and「有没有这条、什么时候过期」is
/// what a user (or a support answer) actually needs. Upstream only offers「clear this source's
/// cookies」from the editor; a list is the smallest addition that keeps that possible and makes it
/// visible.
class CookieManagePage extends ConsumerWidget {
  /// Creates the page.
  const CookieManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<CookieDomainGroup>> groups = ref.watch(
      cookieManageProvider,
    );

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.cookieManageTitle),
        backgroundColor: tokens.colors.surface,
        actions: <Widget>[
          PopupMenuButton<_CookieAction>(
            tooltip: l10n.cookieManageMore,
            onSelected: (_CookieAction action) => switch (action) {
              _CookieAction.expired => unawaited(
                ref.read(cookieManageProvider.notifier).clearExpired(),
              ),
              _CookieAction.all => unawaited(
                _confirmClearAll(context, ref, l10n),
              ),
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_CookieAction>>[
                  PopupMenuItem<_CookieAction>(
                    value: _CookieAction.expired,
                    child: Text(l10n.cookieManageClearExpired),
                  ),
                  PopupMenuItem<_CookieAction>(
                    value: _CookieAction.all,
                    child: Text(l10n.cookieManageClearAll),
                  ),
                ],
          ),
        ],
      ),
      body: switch (groups) {
        AsyncData<List<CookieDomainGroup>>(
          :final List<CookieDomainGroup> value,
        ) =>
          value.isEmpty
              ? StateMessage(message: l10n.cookieManageEmpty)
              : _list(ref, value, l10n, tokens),
        AsyncError<List<CookieDomainGroup>>() => StateMessage(
          message: l10n.cookieManageLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// One section per domain, one row per cookie.
  Widget _list(
    WidgetRef ref,
    List<CookieDomainGroup> groups,
    AppLocalizations l10n,
    M3ETheme tokens,
  ) => ListView.builder(
    itemCount: groups.length,
    itemBuilder: (BuildContext context, int index) {
      final CookieDomainGroup group = groups[index];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.md,
              tokens.spacing.xs,
              EdgeInsets.zero.top,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    group.domain,
                    style: tokens.typography.base.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: l10n.cookieManageClearDomain,
                  onPressed: () => unawaited(
                    ref
                        .read(cookieManageProvider.notifier)
                        .clearDomain(group.domain),
                  ),
                ),
              ],
            ),
          ),
          for (final StoredCookie cookie in group.cookies)
            ListTile(
              title: Text(cookie.name),
              // 只显示「什么时候过期」：值本身是凭据，不往屏幕上印（ADR-0072 §决策 2）。
              subtitle: Text(_expiryOf(cookie, l10n)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.cookieManageDelete,
                onPressed: () => unawaited(
                  ref.read(cookieManageProvider.notifier).remove(cookie),
                ),
              ),
            ),
        ],
      );
    },
  );

  /// The row's second line: a session cookie, or when this one stops being valid.
  String _expiryOf(StoredCookie cookie, AppLocalizations l10n) {
    final DateTime? expiresAt = cookie.expiresAt;
    if (expiresAt == null) {
      return l10n.cookieManageSession;
    }

    return l10n.cookieManageExpiresAt(expiresAt.toLocal().toString());
  }

  /// Asks before emptying the jar: it logs the user out of every source.
  Future<void> _confirmClearAll(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.cookieManageClearAllTitle),
        content: Text(l10n.cookieManageClearAllBody),
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
      await ref.read(cookieManageProvider.notifier).clearAll();
    }
  }
}

/// What the page's overflow menu can do.
enum _CookieAction { expired, all }
