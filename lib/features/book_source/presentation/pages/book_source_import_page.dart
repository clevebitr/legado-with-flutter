import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_import_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Imports book sources by pasting JSON or downloading a URL (`docs/dev/roadmap.md` 5.1, ADR-0040 §决策 9).
///
/// Accessibility (C-UI-7): both fields are labelled by their hints, the submit button by its
/// icon's tooltip, and the outcome is text, never colour alone.
class BookSourceImportPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const BookSourceImportPage({super.key});

  @override
  ConsumerState<BookSourceImportPage> createState() =>
      _BookSourceImportPageState();
}

class _BookSourceImportPageState extends ConsumerState<BookSourceImportPage> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _url = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    _url.dispose();
    super.dispose();
  }

  /// Submits whichever field the user filled in.
  ///
  /// The pasted text wins when both are non-empty: it is the one the user can see in full, and
  /// the file-level failures of a wrong paste are in front of them rather than at the end of a
  /// download. A blank form submits nothing instead of guessing.
  void _submit() {
    final String text = _text.text.trim();
    final String url = _url.text.trim();
    final BookSourceImportInput input = text.isNotEmpty
        ? BookSourceImportText(text)
        : BookSourceImportUrl(url);
    if (text.isEmpty && url.isEmpty) {
      return;
    }

    unawaited(ref.read(bookSourceImportProvider.notifier).submit(input));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final BookSourceImportState state = ref.watch(bookSourceImportProvider);
    final bool isImporting = state is BookSourceImporting;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceImportTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: l10n.bookSourceImportTextLabel,
                hintText: l10n.bookSourceImportTextHint,
              ),
            ),
            SizedBox(height: tokens.spacing.lg),
            TextField(
              controller: _url,
              decoration: InputDecoration(
                labelText: l10n.bookSourceImportUrlLabel,
                hintText: l10n.bookSourceImportUrlHint,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: tokens.spacing.lg),
            IconButton.filled(
              onPressed: isImporting ? null : _submit,
              icon: const Icon(Icons.file_download_outlined),
              tooltip: l10n.actionImport,
            ),
            SizedBox(height: tokens.spacing.lg),
            // 直接选文件是 5.8 提前落地的部分（ADR-0040 §决策 9 的修订注记）：文本与 URL 之外
            // 的第三条入口，走 core/platform 的选择器端口，页面上看不到任何平台代码（C-PLT-1）。
            FilledButton.tonalIcon(
              onPressed: isImporting
                  ? null
                  : () => unawaited(
                      ref.read(bookSourceImportProvider.notifier).pickFile(),
                    ),
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.bookSourceImportFileAction),
            ),
            SizedBox(height: tokens.spacing.lg),
            if (isImporting) const Center(child: CircularProgressIndicator()),
            if (state case BookSourceImportDone(
              :final BookSourceImportReport report,
            ))
              Text(
                report.skipped == 0
                    ? l10n.bookSourceImportSucceeded(report.imported)
                    : l10n.bookSourceImportPartiallySkipped(
                        report.imported,
                        report.skipped,
                      ),
                textAlign: TextAlign.center,
                style: tokens.typography.base.bodyLarge,
              ),
            if (state case BookSourceImportFailed(:final ParseFailureKind kind))
              FailureMessage(kind: kind, onRetry: _submit),
          ],
        ),
      ),
    );
  }
}
