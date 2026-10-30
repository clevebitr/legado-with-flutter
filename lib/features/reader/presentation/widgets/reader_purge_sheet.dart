import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/repositories/purge_rule_switches.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The 替换净化 switches, opened from the reader's toolbar (`docs/dev/roadmap.md` §3.12).
///
/// Why it exists: a rule that eats the body is part of reading, and the remedy used to be «leave the
/// reader, open the rules page, find the rule, come back». Here the reader flips it and the current
/// chapter is re-read with the new rule set (ADR-0094 §决策 2).
///
/// It is **not** a second rule manager: no create, no edit, no delete, no reorder — see ADR-0094
/// §决策 1.
class ReaderPurgeSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [book].
  const ReaderPurgeSheet({required this.book, super.key});

  /// The book being read; its cached bodies are the ones that get dropped on a change.
  final ReaderBook book;

  @override
  ConsumerState<ReaderPurgeSheet> createState() => _ReaderPurgeSheetState();
}

class _ReaderPurgeSheetState extends ConsumerState<ReaderPurgeSheet> {
  late Future<List<PurgeRuleSwitch>> _rules = _load();

  Future<List<PurgeRuleSwitch>> _load() =>
      ref.read(purgeRuleSwitchesProvider).list();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.readerPurgeTitle,
              style: tokens.typography.base.titleMedium,
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(l10n.readerPurgeHint, style: tokens.typography.base.bodySmall),
            SizedBox(height: tokens.spacing.md),
            FutureBuilder<List<PurgeRuleSwitch>>(
              future: _rules,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<PurgeRuleSwitch>> snapshot,
                  ) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Padding(
                        padding: EdgeInsets.all(tokens.spacing.lg),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _retry(l10n.readerPurgeLoadFailed, tokens, l10n);
                    }
                    final List<PurgeRuleSwitch> rules =
                        snapshot.data ?? const <PurgeRuleSwitch>[];
                    if (rules.isEmpty) {
                      return Text(
                        l10n.readerPurgeEmpty,
                        style: tokens.typography.base.bodyMedium,
                      );
                    }

                    return Column(
                      children: <Widget>[
                        for (final PurgeRuleSwitch rule in rules)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              rule.pattern,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: switch (rule.replacement) {
                              final String replacement
                                  when replacement.isNotEmpty =>
                                Text(
                                  '→ $replacement',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              _ => null,
                            },
                            value: rule.isEnabled,
                            onChanged: (bool enabled) =>
                                unawaited(_setEnabled(rule, enabled, l10n)),
                          ),
                      ],
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }

  /// A failure with a retry — a missing binding answers an empty list, not an error.
  Widget _retry(String message, M3ETheme tokens, AppLocalizations l10n) => Row(
    children: <Widget>[
      Expanded(child: Text(message, style: tokens.typography.base.bodyMedium)),
      TextButton(
        onPressed: () => setState(() => _rules = _load()),
        child: Text(l10n.actionRetry),
      ),
    ],
  );

  /// Writes one rule and makes the reader re-read the chapter with the new rule set.
  Future<void> _setEnabled(
    PurgeRuleSwitch rule,
    bool enabled,
    AppLocalizations l10n,
  ) async {
    final bool changed = await ref
        .read(purgeRuleSwitchesProvider)
        .setEnabled(
          id: rule.id,
          enabled: enabled,
          sourceUrl: widget.book.sourceUrl,
          bookUrl: widget.book.bookUrl,
        );
    if (!mounted) {
      return;
    }
    if (!changed) {
      // 未绑定端口 / 写库失败：把这一行说清楚，而不是让开关假装动了。
      ref
          .read(appLoggerProvider)
          .warning('Purge rule switch did not apply: id=${rule.id}');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.readerPurgeFailed)));
    }
    // 整本重读：缓存已清，当前章与相邻预取章都会按新规则再取一次（ADR-0094 §决策 2）。
    ref.invalidate(readerContentProvider);
    final Future<List<PurgeRuleSwitch>> reloaded = _load();
    setState(() {
      _rules = reloaded;
    });
  }
}
