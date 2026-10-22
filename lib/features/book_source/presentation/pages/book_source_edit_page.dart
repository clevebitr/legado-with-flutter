import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Edits one stored book source (`docs/dev/roadmap.md` §3.9-S4, ADR-0050 §决策 3).
///
/// Three things shape the page:
///
/// * **it edits the payload, not the model**: the fields start from the stored JSON, so unmodelled
///   keys survive a save (the same reason export writes payload bytes, ADR-0050 §决策 4);
/// * **the rule objects are JSON text areas**: a field-by-field editor for five nested rule objects
///   would be a second copy of the schema, while one text area per object is exactly what the
///   engine consumes and can be validated by `BookSource.fromLegadoJson` before saving;
/// * **a save that would duplicate another row is refused**, not merged (ADR-0050 §决策 3).
class BookSourceEditPage extends ConsumerStatefulWidget {
  /// Creates the page for the stored source [sourceId].
  const BookSourceEditPage({required this.sourceId, super.key});

  /// The row to edit.
  final int sourceId;

  @override
  ConsumerState<BookSourceEditPage> createState() => _BookSourceEditPageState();
}

class _BookSourceEditPageState extends ConsumerState<BookSourceEditPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _group = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _header = TextEditingController();
  final TextEditingController _searchRule = TextEditingController();
  final TextEditingController _bookInfoRule = TextEditingController();
  final TextEditingController _tocRule = TextEditingController();
  final TextEditingController _contentRule = TextEditingController();

  /// The payload this page started from; edits are merged into a copy of it.
  Map<String, Object?> _payload = <String, Object?>{};
  BookSourceType _type = BookSourceType.text;
  String _storedUrl = '';
  bool _loading = true;
  bool _saving = false;

  /// The fields that failed validation, by label key, so they can be marked.
  final Set<String> _invalid = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _url,
      _group,
      _weight,
      _header,
      _searchRule,
      _bookInfoRule,
      _tocRule,
      _contentRule,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceEditTitle),
        backgroundColor: tokens.colors.surface,
        actions: <Widget>[
          TextButton(
            onPressed: _saving || _loading ? null : () => unawaited(_save()),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(tokens.spacing.lg),
              children: <Widget>[
                _field(l10n.bookSourceFieldName, _name),
                _field(l10n.bookSourceFieldUrl, _url),
                if (_url.text.trim() != _storedUrl)
                  Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                    child: Text(
                      l10n.bookSourceEditUrlHint,
                      style: tokens.typography.base.bodySmall,
                    ),
                  ),
                _field(l10n.bookSourceFieldGroup, _group),
                _typeField(l10n),
                _field(
                  l10n.bookSourceFieldWeight,
                  _weight,
                  keyboard: TextInputType.number,
                ),
                _field(l10n.bookSourceFieldHeader, _header, lines: 3),
                _field(l10n.bookSourceFieldSearchRule, _searchRule, lines: 6),
                _field(
                  l10n.bookSourceFieldBookInfoRule,
                  _bookInfoRule,
                  lines: 6,
                ),
                _field(l10n.bookSourceFieldTocRule, _tocRule, lines: 6),
                _field(l10n.bookSourceFieldContentRule, _contentRule, lines: 4),
              ],
            ),
    );
  }

  /// One labelled text field; a failing field is marked with its error text.
  Widget _field(
    String label,
    TextEditingController controller, {
    int lines = 1,
    TextInputType? keyboard,
  }) {
    final M3ETheme tokens = context.m3e;
    final bool invalid = _invalid.contains(label);

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        minLines: lines,
        maxLines: lines == 1 ? 1 : null,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          errorText: invalid
              ? AppLocalizations.of(context).bookSourceEditInvalidFields
              : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  /// The type dropdown; only the four Legado types that have a meaning here plus video.
  Widget _typeField(AppLocalizations l10n) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.md),
      child: DropdownButtonFormField<BookSourceType>(
        initialValue: _type,
        decoration: InputDecoration(
          labelText: l10n.bookSourceFieldType,
          border: const OutlineInputBorder(),
        ),
        items: <DropdownMenuItem<BookSourceType>>[
          for (final BookSourceType type in BookSourceType.values)
            DropdownMenuItem<BookSourceType>(
              value: type,
              child: Text(type.name),
            ),
        ],
        onChanged: (BookSourceType? value) =>
            setState(() => _type = value ?? BookSourceType.text),
      ),
    );
  }

  /// Loads the stored payload and fills the fields.
  Future<void> _load() async {
    final AppLogger logger = ref.read(appLoggerProvider);
    final String? payload = await ref
        .read(bookSourceRepositoryProvider)
        .payloadOf(widget.sourceId);
    if (!mounted) {
      return;
    }
    if (payload == null) {
      setState(() => _loading = false);

      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      logger.warning('Book source payload is not JSON: id=${widget.sourceId}');
      setState(() => _loading = false);

      return;
    }
    if (decoded is! Map<String, Object?>) {
      setState(() => _loading = false);

      return;
    }

    _payload = decoded;
    _name.text = '${decoded['bookSourceName'] ?? ''}';
    _url.text = '${decoded['bookSourceUrl'] ?? ''}';
    _storedUrl = _url.text;
    _group.text = '${decoded['bookSourceGroup'] ?? ''}';
    _weight.text = '${decoded['weight'] ?? 0}';
    _header.text = _jsonTextOf(decoded['header']);
    _searchRule.text = _jsonTextOf(decoded['ruleSearch']);
    _bookInfoRule.text = _jsonTextOf(decoded['ruleBookInfo']);
    _tocRule.text = _jsonTextOf(decoded['ruleToc']);
    _contentRule.text = _jsonTextOf(decoded['ruleContent']);
    _type = switch (decoded['bookSourceType']) {
      final int value when value >= 0 && value < BookSourceType.values.length =>
        BookSourceType.values[value],
      _ => BookSourceType.text,
    };
    setState(() => _loading = false);
  }

  /// A JSON value as pretty text, or the raw string when it is already text (a rule may be one).
  String _jsonTextOf(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      // `header` is stored as a JSON *string*: show it decoded so the user edits JSON, not a
      // quoted blob, and re-encode on save.
      if (value.trim().startsWith('{')) {
        final Object? inner = _tryDecode(value);
        if (inner != null) {
          return const JsonEncoder.withIndent('  ').convert(inner);
        }
      }

      return value;
    }

    return const JsonEncoder.withIndent('  ').convert(value);
  }

  /// Decodes [text] as JSON, or `null`.
  Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// Merges the fields into the payload, validates it and saves (ADR-0050 §决策 3).
  Future<void> _save() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Map<String, Object?> entry = Map<String, Object?>.of(_payload);
    _invalid.clear();

    entry['bookSourceName'] = _name.text.trim();
    entry['bookSourceUrl'] = _url.text.trim();
    entry['bookSourceType'] = _type.index;
    final int weight = int.tryParse(_weight.text.trim()) ?? 0;
    entry['weight'] = weight;
    if (_group.text.trim().isEmpty) {
      entry.remove('bookSourceGroup');
    } else {
      entry['bookSourceGroup'] = _group.text.trim();
    }

    for (final ({String key, TextEditingController controller, String label})
        field
        in <({String key, TextEditingController controller, String label})>[
          (
            key: 'header',
            controller: _header,
            label: l10n.bookSourceFieldHeader,
          ),
          (
            key: 'ruleSearch',
            controller: _searchRule,
            label: l10n.bookSourceFieldSearchRule,
          ),
          (
            key: 'ruleBookInfo',
            controller: _bookInfoRule,
            label: l10n.bookSourceFieldBookInfoRule,
          ),
          (
            key: 'ruleToc',
            controller: _tocRule,
            label: l10n.bookSourceFieldTocRule,
          ),
          (
            key: 'ruleContent',
            controller: _contentRule,
            label: l10n.bookSourceFieldContentRule,
          ),
        ]) {
      final String text = field.controller.text.trim();
      if (text.isEmpty) {
        entry.remove(field.key);
        continue;
      }
      final Object? value = _tryDecode(text);
      if (value == null) {
        _invalid.add(field.label);
        continue;
      }
      // `header` is a JSON **string** in the payload; the rest are objects.
      entry[field.key] = field.key == 'header' ? text : value;
    }

    // 模型是唯一裁决者（ADR-0022）：一处不合格就不写库。
    try {
      BookSource.fromLegadoJson(entry);
    } on Object {
      setState(() {});
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.bookSourceEditInvalidFields)),
      );

      return;
    }
    if (_invalid.isNotEmpty) {
      setState(() {});
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.bookSourceEditInvalidFields)),
      );

      return;
    }

    setState(() => _saving = true);
    final BookSourceEditOutcome outcome = await ref
        .read(bookSourceRepositoryProvider)
        .update(id: widget.sourceId, entry: entry);
    ref.invalidate(bookSourceListProvider);
    ref.invalidate(bookSourceListDataProvider);
    ref.invalidate(selectedBookSourceProvider);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    switch (outcome) {
      case BookSourceEditOutcome.saved:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.bookSourceEditSaved)),
        );
        Navigator.of(context).pop();
      case BookSourceEditOutcome.identityConflict:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.bookSourceEditIdentityConflict)),
        );
      case BookSourceEditOutcome.sourceMissing:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.bookSourceRowCheck)),
        );
    }
  }
}
