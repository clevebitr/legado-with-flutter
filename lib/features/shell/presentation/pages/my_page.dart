import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/router/app_navigation.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The 「我的」 tab: an entry aggregator, no business logic of its own
/// (`docs/dev/roadmap.md` §3.11 M18, ADR-0055 §决策 3).
///
/// Every row calls a method on the [AppNavigation] port (ADR-0042), so this page does not import
/// `book_source`, `settings` or `reader`: the composition root binds the real push functions. The cache
/// entry deliberately lives in settings only — two "clear cache" buttons would be two answers to
/// the same question.
class MyPage extends ConsumerWidget {
  /// Creates the page.
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AppNavigation navigation = ref.watch(appNavigationProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.myTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: ListView(
        children: <Widget>[
          _heading(context, l10n.mySectionContent),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.myBookSources),
            subtitle: Text(l10n.myBookSourcesBody),
            onTap: () => navigation.openBookSources(context),
          ),
          // 书签与阅读记录是阅读产物，页面归 `reader`；这里只发一个导航请求（ADR-0066 §决策 7）。
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: Text(l10n.myBookmarks),
            subtitle: Text(l10n.myBookmarksBody),
            onTap: () => navigation.openBookmarks(context),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.myReadingRecords),
            subtitle: Text(l10n.myReadingRecordsBody),
            onTap: () => navigation.openReadingRecords(context),
          ),
          _heading(context, l10n.mySectionApp),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.settingsTitle),
            onTap: () => navigation.openSettings(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.aboutTitle),
            onTap: () => navigation.openAbout(context),
          ),
        ],
      ),
    );
  }

  /// One section label; a plain text node so the rows below stay independently reachable.
  Widget _heading(BuildContext context, String label) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.xs,
      ),
      child: Text(label, style: tokens.typography.base.titleSmall),
    );
  }
}
