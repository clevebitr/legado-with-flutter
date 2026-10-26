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
/// `book_source`, `settings`, `reader` or `rules`: the composition root binds the real push
/// functions. The cache entry deliberately lives in settings only — two "clear cache" buttons would
/// be two answers to the same question.
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
        padding: EdgeInsets.only(bottom: tokens.spacing.xl),
        children: <Widget>[
          _section(context, l10n.mySectionContent, <Widget>[
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l10n.myBookSources),
              subtitle: Text(l10n.myBookSourcesBody),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openBookSources(context),
            ),
            // 书签与阅读记录是阅读产物，页面归 `reader`；这里只发一个导航请求
            // （ADR-0066 §决策 7）。
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: Text(l10n.myBookmarks),
              subtitle: Text(l10n.myBookmarksBody),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openBookmarks(context),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.myReadingRecords),
              subtitle: Text(l10n.myReadingRecordsBody),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openReadingRecords(context),
            ),
          ]),
          // 四类规则各自一页（M20，ADR-0070 §决策 1）：它们同构，但一处入口进一类，
          // 免得「在净化列表里看到字典规则」。
          _section(context, l10n.mySectionRules, <Widget>[
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: Text(l10n.rulesReplaceTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openReplaceRules(context),
            ),
            ListTile(
              leading: const Icon(Icons.format_list_bulleted),
              title: Text(l10n.rulesTocTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openTocRules(context),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l10n.rulesDictTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openDictRules(context),
            ),
            ListTile(
              leading: const Icon(Icons.brush_outlined),
              title: Text(l10n.rulesHighlightTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openHighlightRules(context),
            ),
          ]),
          // 数据面：缓存（按源）与 Cookie 罐（ADR-0072）。两者都是「看得到才敢动」的东西。
          _section(context, l10n.mySectionData, <Widget>[
            ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: Text(l10n.cacheManageTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openCacheManage(context),
            ),
            ListTile(
              leading: const Icon(Icons.cookie_outlined),
              title: Text(l10n.myCookies),
              subtitle: Text(l10n.myCookiesBody),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openCookies(context),
            ),
            // 备份与恢复也是数据面：导出的 zip 带走用户数据，恢复把它拿回来（M22，ADR-0073）。
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: Text(l10n.myBackup),
              subtitle: Text(l10n.myBackupBody),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openBackup(context),
            ),
          ]),
          _section(context, l10n.mySectionApp, <Widget>[
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.settingsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openSettings(context),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.aboutTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => navigation.openAbout(context),
            ),
          ]),
        ],
      ),
    );
  }

  /// One section: a heading followed by its rows inside a single card.
  ///
  /// The rows stay plain [ListTile]s, so each one keeps its own semantics and is independently
  /// reachable by a screen reader (C-UI-7).
  Widget _section(BuildContext context, String label, List<Widget> rows) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.lg,
        right: tokens.spacing.lg,
        top: tokens.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(
              left: tokens.spacing.sm,
              bottom: tokens.spacing.sm,
            ),
            child: Text(label, style: tokens.typography.base.titleSmall),
          ),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: tokens.colors.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}
