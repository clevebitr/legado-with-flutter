import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';

/// The title of one kind's list page (and of its rows in 「我的」).
String rulesTitle(AppLocalizations l10n, RuleKind kind) => switch (kind) {
  RuleKind.replace => l10n.rulesReplaceTitle,
  RuleKind.toc => l10n.rulesTocTitle,
  RuleKind.dict => l10n.rulesDictTitle,
  RuleKind.highlight => l10n.rulesHighlightTitle,
};

/// One line of payload text for a list row.
///
/// It shows what the rule actually does rather than its name twice: a purge rule reads
/// `pattern → replacement`, the others read their main expression.
String ruleSummary(AppLocalizations l10n, RulePayload payload) =>
    switch (payload) {
      ReplacePayload(:final String pattern, :final String replacement) =>
        '$pattern → $replacement',
      TocPayload(:final String rule) => rule,
      DictPayload(:final String urlRule) => urlRule,
      HighlightPayload(:final String pattern) => pattern,
      // 坏 payload 由列表自己标「规则损坏」，这里只是兜底，不该被当成正常行显示。
      MalformedPayload() => l10n.rulesBroken,
    };
