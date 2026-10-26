import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/presentation/notifiers/rules_list_notifier.dart';
import 'package:flutter_reader/features/rules/presentation/rules_strings.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The form for one rule of [kind]: edit the rule [ruleId], or create a new one
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// One page serves all four kinds. It is a [ConsumerWidget] only to resolve the stored row and to
/// hand the write to the list notifier; everything with state lives in [_RuleForm], whose
/// controllers are seeded once from that row.
class RuleEditPage extends ConsumerWidget {
  /// Creates the page; a `null` [ruleId] creates a new rule of [kind].
  const RuleEditPage({required this.kind, this.ruleId, super.key});

  /// Which kind is being edited; it never changes while the page is open.
  final RuleKind kind;

  /// The rule being edited, or `null` to create one.
  final int? ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final int? ruleId = this.ruleId;
    final AsyncValue<List<Rule>> rules = ref.watch(rulesListProvider(kind));

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(
          ruleId == null
              ? '${l10n.rulesAdd} · ${rulesTitle(l10n, kind)}'
              : l10n.rulesEditTitle,
        ),
        backgroundColor: tokens.colors.surface,
      ),
      // 新建不需要旧行：列表还在读的时候就能开始填。
      body: ruleId == null
          ? _RuleForm(kind: kind, existing: null)
          : switch (rules) {
              AsyncData<List<Rule>>(:final List<Rule> value) => switch (_find(
                value,
                ruleId,
              )) {
                final Rule rule => _RuleForm(kind: kind, existing: rule),
                // 行在别的路径上被删掉了：说明清楚，而不是给一张会「另存成新规则」的空表。
                null => StateMessage(message: l10n.rulesGone),
              },
              AsyncError<List<Rule>>() => StateMessage(
                message: l10n.rulesLoadFailed,
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
    );
  }

  /// The row with [ruleId] inside [rules], when the list has loaded.
  static Rule? _find(List<Rule> rules, int ruleId) {
    for (final Rule rule in rules) {
      if (rule.id == ruleId) {
        return rule;
      }
    }

    return null;
  }
}

/// The kind-specific fields and the save action.
class _RuleForm extends ConsumerStatefulWidget {
  const _RuleForm({required this.kind, required this.existing});

  final RuleKind kind;
  final Rule? existing;

  @override
  ConsumerState<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<_RuleForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _pattern;
  late final TextEditingController _replacement;
  late final TextEditingController _rule;
  late final TextEditingController _serialNumber;
  late final TextEditingController _urlRule;
  late final TextEditingController _showRule;
  late final TextEditingController _colorHex;
  late final TextEditingController _group;

  /// Whether the rule is in effect; kept separately from the form fields because it is a `Switch`.
  late bool _isEnabled;
  late bool _isRegex;

  @override
  void initState() {
    super.initState();
    final Rule? existing = widget.existing;
    final RulePayload? payload = existing?.payload;
    _name = TextEditingController(text: existing?.name ?? '');
    _isEnabled = existing?.isEnabled ?? true;
    // 新建时按「正则」起手：上游的 replace / highlight 规则默认就是正则。
    _isRegex = switch (payload) {
      ReplacePayload(:final bool isRegex) => isRegex,
      _ => true,
    };
    _pattern = TextEditingController(
      text: switch (payload) {
        ReplacePayload(:final String pattern) => pattern,
        HighlightPayload(:final String pattern) => pattern,
        _ => '',
      },
    );
    _replacement = TextEditingController(
      text: switch (payload) {
        ReplacePayload(:final String replacement) => replacement,
        _ => '',
      },
    );
    _rule = TextEditingController(
      text: switch (payload) {
        TocPayload(:final String rule) => rule,
        _ => '',
      },
    );
    _serialNumber = TextEditingController(
      text: switch (payload) {
        TocPayload(:final int? serialNumber) => serialNumber?.toString() ?? '',
        _ => '',
      },
    );
    _urlRule = TextEditingController(
      text: switch (payload) {
        DictPayload(:final String urlRule) => urlRule,
        _ => '',
      },
    );
    _showRule = TextEditingController(
      text: switch (payload) {
        DictPayload(:final String showRule) => showRule,
        _ => '',
      },
    );
    _colorHex = TextEditingController(
      text: switch (payload) {
        HighlightPayload(:final String? colorHex) => colorHex ?? '',
        _ => '',
      },
    );
    _group = TextEditingController(
      text: switch (payload) {
        HighlightPayload(:final String? group) => group ?? '',
        _ => '',
      },
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _pattern.dispose();
    _replacement.dispose();
    _rule.dispose();
    _serialNumber.dispose();
    _urlRule.dispose();
    _showRule.dispose();
    _colorHex.dispose();
    _group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final Rule? existing = widget.existing;
    final RulePayload? payload = existing?.payload;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(tokens.spacing.lg),
        children: <Widget>[
          if (payload is MalformedPayload) ...<Widget>[
            Text(
              l10n.rulesBrokenNotice,
              style: tokens.typography.base.bodySmall,
            ),
            SizedBox(height: tokens.spacing.sm),
            // 原文照抄给用户看：读不懂不等于看不见（ADR-0070 §决策 1）。
            SelectableText(
              payload.raw,
              style: tokens.typography.base.bodySmall,
            ),
            SizedBox(height: tokens.spacing.md),
          ],
          _text(
            controller: _name,
            label: l10n.rulesNameLabel,
            validator: (String? value) => _required(value, l10n),
          ),
          ..._fields(l10n),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isEnabled,
            onChanged: (bool value) => setState(() => _isEnabled = value),
            title: Text(l10n.rulesEnabledLabel),
          ),
          SizedBox(height: tokens.spacing.lg),
          FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
        ],
      ),
    );
  }

  /// The fields the current kind owns; the other kinds' controllers stay untouched.
  List<Widget> _fields(AppLocalizations l10n) => switch (widget.kind) {
    RuleKind.replace => <Widget>[
      _text(
        controller: _pattern,
        label: l10n.rulesPatternLabel,
        validator: (String? value) => _regex(value, l10n, isRegex: _isRegex),
        maxLines: 3,
      ),
      _text(
        controller: _replacement,
        label: l10n.rulesReplacementLabel,
        maxLines: 3,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _isRegex,
        onChanged: (bool value) => setState(() => _isRegex = value),
        title: Text(l10n.rulesIsRegexLabel),
      ),
    ],
    RuleKind.toc => <Widget>[
      _text(
        controller: _rule,
        label: l10n.rulesRuleLabel,
        validator: (String? value) => _regex(value, l10n, isRegex: true),
        maxLines: 3,
      ),
      _text(
        controller: _serialNumber,
        label: l10n.rulesSerialNumberLabel,
        keyboardType: TextInputType.number,
      ),
    ],
    RuleKind.dict => <Widget>[
      _text(
        controller: _urlRule,
        label: l10n.rulesUrlRuleLabel,
        validator: (String? value) => _required(value, l10n),
        maxLines: 2,
      ),
      _text(
        controller: _showRule,
        label: l10n.rulesShowRuleLabel,
        validator: (String? value) => _required(value, l10n),
        maxLines: 3,
      ),
    ],
    RuleKind.highlight => <Widget>[
      _text(
        controller: _pattern,
        label: l10n.rulesPatternLabel,
        validator: (String? value) => _regex(value, l10n, isRegex: true),
      ),
      _text(
        controller: _colorHex,
        label: l10n.rulesColorLabel,
        validator: (String? value) => _color(value, l10n),
      ),
      _text(controller: _group, label: l10n.rulesGroupLabel),
    ],
  };

  /// One labelled text field with the page's spacing.
  Widget _text({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }

  /// Builds the typed payload of the current kind, keeping what the form does not edit.
  ///
  /// The preserved fields are the ones ADR-0070 §决策 1 requires to survive a round trip: `timeoutMs`
  /// for a purge rule, and every unknown key (`extra`) for all four kinds.
  RulePayload _payload() {
    final RulePayload? existing = widget.existing?.payload;
    final String serial = _serialNumber.text.trim();

    return switch (widget.kind) {
      RuleKind.replace => RulePayload.replace(
        pattern: _pattern.text.trim(),
        replacement: _replacement.text,
        isRegex: _isRegex,
        timeoutMs: switch (existing) {
          ReplacePayload(:final int? timeoutMs) => timeoutMs,
          _ => null,
        },
        extra: switch (existing) {
          ReplacePayload(:final Map<String, Object?> extra) => extra,
          _ => const <String, Object?>{},
        },
      ),
      RuleKind.toc => RulePayload.toc(
        rule: _rule.text.trim(),
        serialNumber: int.tryParse(serial),
        extra: switch (existing) {
          TocPayload(:final Map<String, Object?> extra) => extra,
          _ => const <String, Object?>{},
        },
      ),
      RuleKind.dict => RulePayload.dict(
        urlRule: _urlRule.text.trim(),
        showRule: _showRule.text.trim(),
        ruleGroupType: switch (existing) {
          DictPayload(:final String? ruleGroupType) => ruleGroupType,
          _ => null,
        },
        extra: switch (existing) {
          DictPayload(:final Map<String, Object?> extra) => extra,
          _ => const <String, Object?>{},
        },
      ),
      RuleKind.highlight => RulePayload.highlight(
        pattern: _pattern.text.trim(),
        colorHex: _blankToNull(_colorHex.text),
        group: _blankToNull(_group.text),
        extra: switch (existing) {
          HighlightPayload(:final Map<String, Object?> extra) => extra,
          _ => const <String, Object?>{},
        },
      ),
    };
  }

  /// Validates, saves through the list notifier and closes the page.
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(rulesListProvider(widget.kind).notifier)
        .save(
          draft: RuleDraft(
            kind: widget.kind,
            name: _name.text.trim(),
            payload: _payload(),
            isEnabled: _isEnabled,
            isBuiltIn: widget.existing?.isBuiltIn ?? false,
          ),
          id: widget.existing?.id,
        );

    // 写是异步的：跨过 await 之后 context 可能已经不在树上（C-ERR-4）。
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  String? _required(String? value, AppLocalizations l10n) =>
      (value ?? '').trim().isEmpty ? l10n.rulesRequired : null;

  /// A required expression that has to compile when it is a regular expression.
  String? _regex(
    String? value,
    AppLocalizations l10n, {
    required bool isRegex,
  }) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return l10n.rulesRequired;
    }
    if (!isRegex) {
      return null;
    }

    try {
      RegExp(text);
    } on FormatException {
      // 存下去也能跑（阅读时会跳过并记 warning），但让用户在保存前就知道更好。
      return l10n.rulesInvalidRegex;
    }

    return null;
  }

  /// An optional `#RRGGBB` / `#AARRGGBB` colour.
  String? _color(String? value, AppLocalizations l10n) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    final RegExp valid = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

    return valid.hasMatch(text) ? null : l10n.rulesInvalidColor;
  }

  String? _blankToNull(String text) {
    final String trimmed = text.trim();

    return trimmed.isEmpty ? null : trimmed;
  }
}
