import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reader/features/shell/presentation/app_info.dart';
import 'package:flutter_reader/features/shell/presentation/shell_route.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// The about page: version, the legal-notices entry and where the source lives
/// (`docs/dev/roadmap.md` §3.11 M18, ADR-0055 §决策 4).
///
/// The source address is shown as selectable text plus a copy button instead of opening a browser:
/// that keeps the GPL-3.0 §6 entry ("where to obtain the Corresponding Source") without taking a
/// `url_launcher` dependency (C-DEP-1).
class AboutPage extends StatelessWidget {
  /// Creates the page.
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.lg),
        children: <Widget>[
          // 应用标识：圆形色块里的书本，与「我的」入口卡片形成一致的视觉锚点。
          Center(
            child: Container(
              width: tokens.spacing.xxl * 2.5,
              height: tokens.spacing.xxl * 2.5,
              decoration: BoxDecoration(
                color: tokens.colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories,
                size: tokens.spacing.xxl,
                color: tokens.colors.onPrimaryContainer,
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          Text(
            l10n.appTitle,
            textAlign: TextAlign.center,
            style: tokens.typography.base.headlineSmall,
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            l10n.aboutVersion(appVersion),
            textAlign: TextAlign.center,
            style: tokens.typography.base.bodyMedium?.copyWith(
              color: tokens.colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spacing.lg),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.aboutLicenses),
            subtitle: Text(l10n.legalNoticesTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                pushShellRoute(context, const ShellRoute.legalNotices()),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.aboutSourceCode),
            subtitle: const SelectableText(appRepositoryUrl),
            trailing: IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: l10n.aboutCopySource,
              onPressed: () => _copy(context, l10n),
            ),
          ),
        ],
      ),
    );
  }

  /// Puts the source address on the clipboard and confirms it.
  ///
  /// The clipboard write is **not awaited**: it is a platform channel, and a host that never
  /// answers it must not turn a copy into a hang (the same reason the export path does not await).
  void _copy(BuildContext context, AppLocalizations l10n) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    unawaited(
      Clipboard.setData(const ClipboardData(text: appRepositoryUrl)).then((_) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.aboutCopied)));
      }),
    );
  }
}
