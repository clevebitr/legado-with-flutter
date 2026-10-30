import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// The radio-value prefix of a single-group scope in the scope sheet.
const String _groupKeyPrefix = 'group:';

/// The label of [scope] for a chip (ADR-0046 §决策 1, ADR-0058).
///
/// Shared by the search page and the change-source page so the two never spell the same scope
/// differently.
String sourceScopeLabel(AppLocalizations l10n, BookSearchScope scope) =>
    switch (scope) {
      SearchScopeAll() => l10n.searchScopeAll,
      SearchScopeGroups(:final Set<String> groups) =>
        groups.isEmpty ? l10n.searchScopeAll : groups.join('、'),
      SearchScopeSources(:final List<ScopeSource> sources) =>
        sources.isEmpty
            ? l10n.searchScopeAll
            : sources.map((ScopeSource source) => source.name).join('、'),
    };

/// Opens the scope sheet: everything, one group, or specific sources.
///
/// One sheet instead of a nested picker: "all" and the groups are the radio part, the named
/// sources are the check-box part, and ticking any source switches the scope to `sources`
/// (ADR-0046 §决策 1).
///
/// [onSelected] is awaited on **every** change instead of on close: a scope is a persisted
/// preference, and a user may dismiss the sheet by dragging it — a named-source selection would be
/// lost if it only travelled on the radio path (ADR-0058). The sheet redraws from its own state, so
/// a ticked box can be unticked again (the ADR-0058 bug).
Future<void> showSourceScopeSheet({
  required BuildContext context,
  required BookSearchScope initial,
  required List<StoredBookSource> rows,
  required Future<void> Function(BookSearchScope scope) onSelected,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (BuildContext sheetContext) => SafeArea(
    child: _SourceScopeSheet(
      initial: initial,
      rows: rows,
      onSelected: onSelected,
    ),
  ),
);

/// The sheet body: a radio group plus one checkbox per source.
class _SourceScopeSheet extends StatefulWidget {
  const _SourceScopeSheet({
    required this.initial,
    required this.rows,
    required this.onSelected,
  });

  final BookSearchScope initial;
  final List<StoredBookSource> rows;
  final Future<void> Function(BookSearchScope scope) onSelected;

  @override
  State<_SourceScopeSheet> createState() => _SourceScopeSheetState();
}

class _SourceScopeSheetState extends State<_SourceScopeSheet> {
  late BookSearchScope _scope = widget.initial;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final List<String> groups = <String>{
      for (final StoredBookSource row in widget.rows)
        ...splitGroups(row.groupName ?? row.source.group),
    }.toList()..sort();
    final Set<String> named = <String>{
      for (final ScopeSource source in _scope.sourcesOrEmpty) source.url,
    };

    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.xs,
          ),
          child: Text(
            l10n.searchScopeLabel,
            style: tokens.typography.base.titleMedium,
          ),
        ),
        RadioGroup<String>(
          groupValue: _scopeKeyOf(_scope),
          onChanged: (String? key) => unawaited(
            _apply(
              key == null || key.isEmpty
                  ? BookSearchScope.defaults
                  : BookSearchScope.groups(<String>{
                      key.substring(_groupKeyPrefix.length),
                    }),
              close: true,
            ),
          ),
          child: Column(
            children: <Widget>[
              RadioListTile<String>(
                value: '',
                title: Text(l10n.searchScopeAll),
              ),
              for (final String group in groups)
                RadioListTile<String>(
                  value: '$_groupKeyPrefix$group',
                  title: Text(group),
                ),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          title: Text(l10n.searchScopeNamed),
          subtitle: Text(
            named.isEmpty
                ? l10n.searchScopeAll
                : widget.rows
                      .where(
                        (StoredBookSource row) =>
                            named.contains(row.source.url),
                      )
                      .map((StoredBookSource row) => row.source.name)
                      .join('、'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final StoredBookSource row in widget.rows)
          CheckboxListTile(
            value: named.contains(row.source.url),
            title: Text(row.source.name),
            onChanged: (bool? checked) =>
                unawaited(_toggleNamed(row, checked ?? false, close: false)),
          ),
      ],
    );
  }

  /// The radio value of [_scope].
  String _scopeKeyOf(BookSearchScope scope) => switch (scope) {
    SearchScopeAll() => '',
    SearchScopeGroups(:final Set<String> groups) when groups.length == 1 =>
      '$_groupKeyPrefix${groups.first}',
    SearchScopeGroups() || SearchScopeSources() => '',
  };

  /// Adds or removes one named source, switching the scope to `sources` as soon as one is ticked.
  Future<void> _toggleNamed(
    StoredBookSource row,
    bool checked, {
    required bool close,
  }) async {
    final Set<String> next = <String>{
      for (final ScopeSource named in _scope.sourcesOrEmpty) named.url,
    };
    if (checked) {
      next.add(row.source.url);
    } else {
      next.remove(row.source.url);
    }

    return _apply(
      next.isEmpty
          ? BookSearchScope.defaults
          : BookSearchScope.sources(<ScopeSource>[
              for (final StoredBookSource candidate in widget.rows)
                if (next.contains(candidate.source.url))
                  ScopeSource(
                    name: candidate.source.name,
                    url: candidate.source.url,
                  ),
            ]),
      close: close,
    );
  }

  /// Applies [scope], redraws, and (for a radio pick) closes the sheet.
  Future<void> _apply(BookSearchScope scope, {required bool close}) async {
    await widget.onSelected(scope);
    if (!mounted) {
      return;
    }
    setState(() => _scope = scope);
    if (close) {
      Navigator.of(context).pop();
    }
  }
}
