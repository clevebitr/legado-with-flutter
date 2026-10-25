import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/features/rules/domain/entities/replace_rule_import.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/usecases/import_replace_rules.dart';
import 'package:flutter_reader/features/rules/presentation/notifiers/rules_import_notifier.dart';
import 'package:flutter_reader/features/rules/presentation/rules_strings.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Imports 替换净化 rules from pasted JSON, a URL or a file
/// (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
///
/// Three inputs and one outcome: a preview the user ticks through, then a commit. Same shape as the
/// book-source import (ADR-0052 §决策 5), because「先看清楚再写库」is the same promise.
class RulesImportPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const RulesImportPage({super.key});

  @override
  ConsumerState<RulesImportPage> createState() => _RulesImportPageState();
}

class _RulesImportPageState extends ConsumerState<RulesImportPage> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _url = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    _url.dispose();
    super.dispose();
  }

  /// Submits whichever field the user filled in; the pasted text wins (it is the one they can see).
  void _submit() {
    final String text = _text.text.trim();
    final String url = _url.text.trim();
    if (text.isEmpty && url.isEmpty) {
      return;
    }
    final ReplaceRuleImportInput input = text.isNotEmpty
        ? ReplaceRuleImportText(text)
        : ReplaceRuleImportUrl(url);

    unawaited(ref.read(rulesImportProvider.notifier).submit(input));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final RulesImportState state = ref.watch(rulesImportProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.rulesImportTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: switch (state) {
        RulesImportPreviewing(:final ReplaceRuleImportPreview preview) =>
          _PreviewView(preview: preview),
        // 提交是数据库调用，通常只闪一下；给一个明确的进行态而不是让按钮静默卡住。
        RulesImportCommitting() => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => _form(l10n, tokens, state),
      },
    );
  }

  /// The paste / URL / file form, plus the outcome of the last run.
  Widget _form(AppLocalizations l10n, M3ETheme tokens, RulesImportState state) {
    final bool isBusy = state is RulesImportImporting;

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
              labelText: l10n.rulesImportTextLabel,
              hintText: l10n.rulesImportTextHint,
            ),
          ),
          SizedBox(height: tokens.spacing.lg),
          TextField(
            controller: _url,
            decoration: InputDecoration(
              labelText: l10n.rulesImportUrlLabel,
              hintText: l10n.rulesImportUrlHint,
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
          // 本地文件是第三条入口，走 `core/platform/` 的选择器端口，页面里看不到平台代码（C-PLT-1）。
          FilledButton.tonalIcon(
            onPressed: isBusy
                ? null
                : () => unawaited(
                    ref.read(rulesImportProvider.notifier).pickFile(),
                  ),
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(l10n.rulesImportFileAction),
          ),
          SizedBox(height: tokens.spacing.lg),
          if (isBusy) const Center(child: CircularProgressIndicator()),
          if (state case RulesImportDone(:final ReplaceRuleImportReport report))
            Text(
              report.skipped == 0
                  ? l10n.rulesImportSucceeded(report.created, report.updated)
                  : l10n.rulesImportSucceededWithSkipped(
                      report.created,
                      report.updated,
                      report.skipped,
                    ),
              textAlign: TextAlign.center,
              style: tokens.typography.base.bodyLarge,
            ),
          if (state case RulesImportFailed(:final ParseFailureKind kind))
            FailureMessage(kind: kind, onRetry: _submit),
        ],
      ),
    );
  }
}

/// The preview: one tickable row per entry, then commit / back.
///
/// The selection lives here rather than in the notifier: it is「用户此刻勾了什么」, it dies with the
/// preview, and the notifier only needs the final set.
class _PreviewView extends ConsumerStatefulWidget {
  const _PreviewView({required this.preview});

  final ReplaceRuleImportPreview preview;

  @override
  ConsumerState<_PreviewView> createState() => _PreviewViewState();
}

class _PreviewViewState extends ConsumerState<_PreviewView> {
  /// The usable entries are ticked by default: the common case is「导入文件里的一切」。
  late final Set<int> _selected = <int>{
    for (final ReplaceRuleImportEntry entry in widget.preview.entries)
      if (entry.isUsable) entry.index,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final ReplaceRuleImportPreview preview = widget.preview;
    final bool allSelected = _selected.length == preview.usableCount;

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
          child: Row(
            children: <Widget>[
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: allSelected,
                  onChanged: (bool? value) => setState(() {
                    _selected
                      ..clear()
                      ..addAll(
                        value ?? false
                            ? <int>{
                                for (final ReplaceRuleImportEntry entry
                                    in preview.entries)
                                  if (entry.isUsable) entry.index,
                              }
                            : const <int>{},
                      );
                  }),
                  title: Text(l10n.rulesImportSelectAll),
                ),
              ),
              Text(
                l10n.rulesImportSelected(_selected.length, preview.usableCount),
                style: tokens.typography.base.labelMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: preview.entries.length,
            itemBuilder: (BuildContext context, int index) {
              final ReplaceRuleImportEntry entry = preview.entries[index];

              return CheckboxListTile(
                value: _selected.contains(entry.index),
                onChanged: entry.isUsable
                    ? (bool? value) => setState(() {
                        if (value ?? false) {
                          _selected.add(entry.index);
                        } else {
                          _selected.remove(entry.index);
                        }
                      })
                    : null,
                title: Text(
                  entry.name.isEmpty ? l10n.rulesImportUntitled : entry.name,
                ),
                subtitle: Text(
                  <String>[
                    if (entry.payload case final ReplacePayload payload)
                      ruleSummary(l10n, payload),
                    ..._badges(entry, l10n),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () => unawaited(
                    ref.read(rulesImportProvider.notifier).commit(_selected),
                  ),
            child: Text(l10n.rulesImportCommit(_selected.length)),
          ),
        ),
      ],
    );
  }

  /// The second half of a row's subtitle: update badge, scope, or why it cannot be imported.
  List<String> _badges(ReplaceRuleImportEntry entry, AppLocalizations l10n) {
    final ReplaceRuleImportProblem? problem = entry.problem;
    if (problem != null) {
      return <String>[
        switch (problem) {
          ReplaceRuleImportProblem.notAnObject => l10n.rulesImportProblemFormat,
          ReplaceRuleImportProblem.missingPattern =>
            l10n.rulesImportProblemMissingPattern,
        },
      ];
    }

    return <String>[
      if (entry.isUpdate) l10n.rulesImportUpdate,
      if (entry.payload case final ReplacePayload payload)
        rulesScopeLabel(l10n, payload),
    ];
  }
}
