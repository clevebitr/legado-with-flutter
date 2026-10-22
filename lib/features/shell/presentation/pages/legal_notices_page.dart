import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reader/features/shell/presentation/app_info.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// The legal notices required by C-UI-9: copyright, no warranty, prohibited use, the GPL-3.0 text
/// and where the Corresponding Source lives (`docs/dev/roadmap.md` §3.11 M18, ADR-0055 §决策 4).
///
/// The license text is a **bundled asset** (`assets/legal/gpl-3.0.txt`, a copy of the root
/// `LICENSE`), so the full text is readable offline and without a browser. Loading it can fail on a
/// broken asset bundle; that path shows a retryable message instead of a blank page (C-ERR-1 精神).
class LegalNoticesPage extends StatelessWidget {
  /// Creates the page.
  const LegalNoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.legalNoticesTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: ListView(
        padding: EdgeInsets.all(tokens.spacing.lg),
        children: <Widget>[
          _paragraph(context, l10n.legalNoticesCopyright),
          _paragraph(context, l10n.legalNoticesNoWarranty),
          _paragraph(context, l10n.legalNoticesProhibitedUse),
          SizedBox(height: tokens.spacing.lg),
          Text(
            l10n.legalNoticesCorrespondingSource,
            style: tokens.typography.base.titleSmall,
          ),
          SizedBox(height: tokens.spacing.xs),
          const SelectableText(appRepositoryUrl),
          SizedBox(height: tokens.spacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _copy(context, l10n),
              icon: const Icon(Icons.copy_outlined),
              label: Text(l10n.aboutCopySource),
            ),
          ),
          SizedBox(height: tokens.spacing.lg),
          FilledButton.tonalIcon(
            onPressed: () => unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const _LicenseTextPage(),
                ),
              ),
            ),
            icon: const Icon(Icons.description_outlined),
            label: Text(l10n.legalNoticesViewLicense),
          ),
        ],
      ),
    );
  }

  /// One body paragraph, spaced by the token scale.
  Widget _paragraph(BuildContext context, String text) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.md),
      child: Text(text, style: tokens.typography.base.bodyMedium),
    );
  }

  /// Puts the source address on the clipboard; not awaited for the same reason as the about page.
  void _copy(BuildContext context, AppLocalizations l10n) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    unawaited(
      Clipboard.setData(const ClipboardData(text: appRepositoryUrl)).then((_) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.aboutCopied)));
      }),
    );
  }
}

/// The GPL-3.0 text, read from the bundled asset.
class _LicenseTextPage extends StatelessWidget {
  const _LicenseTextPage();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.legalNoticesLicenseTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/gpl-3.0.txt'),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          final String? text = snapshot.data;
          if (text != null) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: SelectableText(
                text,
                style: tokens.typography.base.bodySmall,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.legalNoticesLicenseFailed,
                      textAlign: TextAlign.center,
                      style: tokens.typography.base.bodyLarge,
                    ),
                  ],
                ),
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
