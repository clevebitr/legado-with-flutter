import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_import_preview.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_import_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Imports book sources by pasting JSON, downloading a URL or picking a file
/// (`docs/dev/roadmap.md` 5.1, 5.8, §3.10 V5; ADR-0040 §决策 9, ADR-0052 §决策 5).
///
/// The screen has two faces:
///
/// * the **form** — paste / URL / file, which only *reads* the document;
/// * the **preview** — one row per entry with a tick, a new/refresh label and, for a rejected
///   entry, the reason. Nothing is stored until the user commits the ticked entries, which is
///   what makes "import 12 of these 300" possible.
///
/// Accessibility (C-UI-7): both fields are labelled by their hints, the submit button by its
/// icon's tooltip, every preview row is a checkbox tile (its state is the tick), and the outcome is
/// text, never colour alone.
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
    if (text.isEmpty && url.isEmpty) {
      return;
    }
    final BookSourceImportInput input = text.isNotEmpty
        ? BookSourceImportText(text)
        : BookSourceImportUrl(url);

    unawaited(ref.read(bookSourceImportProvider.notifier).submit(input));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final BookSourceImportState state = ref.watch(bookSourceImportProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceImportTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: switch (state) {
        BookSourceImportPreviewing(:final BookSourceImportPreview preview) =>
          _ImportPreviewView(preview: preview),
        // 提交是存储调用，通常只闪一下；给一个明确的进行态而不是让按钮静默卡住。
        BookSourceImportCommitting() => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => _form(l10n, tokens, state),
      },
    );
  }

  /// The paste / URL / file form, plus the outcome of the last run.
  Widget _form(
    AppLocalizations l10n,
    M3ETheme tokens,
    BookSourceImportState state,
  ) {
    final bool isBusy = state is BookSourceImporting;

    return SingleChildScrollView(
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
            onPressed: isBusy ? null : _submit,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.actionImport,
          ),
          SizedBox(height: tokens.spacing.lg),
          // 直接选文件是 5.8 提前落地的部分（ADR-0040 §决策 9 的修订注记）：文本与 URL 之外
          // 的第三条入口，走 core/platform 的选择器端口，页面上看不到任何平台代码（C-PLT-1）。
          FilledButton.tonalIcon(
            onPressed: isBusy
                ? null
                : () => unawaited(
                    ref.read(bookSourceImportProvider.notifier).pickFile(),
                  ),
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(l10n.bookSourceImportFileAction),
          ),
          SizedBox(height: tokens.spacing.lg),
          if (isBusy) const Center(child: CircularProgressIndicator()),
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
    );
  }
}

/// The preview list: one tickable row per entry, then commit / back
/// (`docs/dev/roadmap.md` §3.10 V5, ADR-0052 §决策 5).
///
/// The selection lives here rather than in the notifier: it is "what the user is looking at right
/// now", it dies with the preview, and the notifier only needs the final set (`commit`).
class _ImportPreviewView extends ConsumerStatefulWidget {
  const _ImportPreviewView({required this.preview});

  final BookSourceImportPreview preview;

  @override
  ConsumerState<_ImportPreviewView> createState() => _ImportPreviewViewState();
}

class _ImportPreviewViewState extends ConsumerState<_ImportPreviewView> {
  /// The usable entries are ticked by default: the common case is "import what the file has".
  late final Set<int> _selected = <int>{
    for (final BookSourceImportEntry entry in widget.preview.entries)
      if (entry.isUsable) entry.index,
  };

  bool get _allSelected => _selected.length == widget.preview.usableCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final BookSourceImportPreview preview = widget.preview;

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
            l10n.bookSourceImportPreviewSummary(
              preview.newCount,
              preview.refreshCount,
              preview.rejectedCount,
            ),
            style: tokens.typography.base.bodyMedium,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: preview.usableCount == 0
                  ? null
                  : () => setState(() {
                      if (_allSelected) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(<int>{
                            for (final BookSourceImportEntry entry
                                in preview.entries)
                              if (entry.isUsable) entry.index,
                          });
                      }
                    }),
              child: Text(
                _allSelected
                    ? l10n.bookSourceImportDeselectAll
                    : l10n.bookSourceImportSelectAll,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: preview.entries.length,
            itemBuilder: (BuildContext context, int index) =>
                _entry(context, l10n, preview.entries[index]),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.md),
            child: Row(
              children: <Widget>[
                TextButton(
                  onPressed: () =>
                      ref.read(bookSourceImportProvider.notifier).restart(),
                  child: Text(l10n.bookSourceImportBack),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => unawaited(
                          ref
                              .read(bookSourceImportProvider.notifier)
                              .commit(_selected),
                        ),
                  icon: const Icon(Icons.file_download_done_outlined),
                  label: Text(l10n.bookSourceImportCommit(_selected.length)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// One preview row: tickable when usable, an explained dead end when rejected.
  Widget _entry(
    BuildContext context,
    AppLocalizations l10n,
    BookSourceImportEntry entry,
  ) {
    final String title =
        entry.name ?? l10n.bookSourceImportEntryUnknown(entry.index + 1);
    final String? url = entry.url;
    final BookSourceImportRejection? rejection = entry.rejection;
    if (rejection != null) {
      return ListTile(
        enabled: false,
        leading: const Icon(Icons.error_outline),
        title: Text(title),
        subtitle: Text(
          <String>[_rejectionLabel(l10n, rejection), ?url].join('\n'),
        ),
        isThreeLine: url != null,
      );
    }

    return CheckboxListTile(
      value: _selected.contains(entry.index),
      onChanged: (bool? isSelected) => setState(() {
        if (isSelected ?? false) {
          _selected.add(entry.index);
        } else {
          _selected.remove(entry.index);
        }
      }),
      title: Text(title),
      subtitle: Text(
        <String>[
          ?url,
          if (entry.isRefresh)
            l10n.bookSourceImportEntryRefresh
          else
            l10n.bookSourceImportEntryNew,
        ].join('\n'),
      ),
      isThreeLine: true,
    );
  }
}

/// The ARB label of one rejection (C-ERR-7: the domain hands out a reason, the UI names it).
String _rejectionLabel(
  AppLocalizations l10n,
  BookSourceImportRejection rejection,
) => switch (rejection) {
  BookSourceImportRejection.missingUrl =>
    l10n.bookSourceImportRejectionMissingUrl,
  BookSourceImportRejection.missingName =>
    l10n.bookSourceImportRejectionMissingName,
  BookSourceImportRejection.unreadable =>
    l10n.bookSourceImportRejectionUnreadable,
  BookSourceImportRejection.notAnObject =>
    l10n.bookSourceImportRejectionNotAnObject,
};
