import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_settings.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/source_check_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The batch book-source check (`docs/dev/roadmap.md` §5.10).
///
/// The page is split in two halves that never mix: the **controls** (which sources, which stages,
/// which keyword, how long a source may take) and the **rows** (one per selected source, showing
/// its stage outcomes). While a batch runs the controls are disabled instead of hidden, so the
/// user can see what is being run.
///
/// The selection is page state, not notifier state: it is a view decision ("what did I tick"), it
/// never outlives the page, and nothing else reads it (C-STATE-5).
class BookSourceCheckPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const BookSourceCheckPage({super.key});

  @override
  ConsumerState<BookSourceCheckPage> createState() =>
      _BookSourceCheckPageState();
}

/// State of the check page: the tick boxes and the keyword field.
class _BookSourceCheckPageState extends ConsumerState<BookSourceCheckPage> {
  /// Which sources are ticked, or `null` before the user touched anything (= all of them).
  Set<int>? _selection;

  /// The keyword the user typed; `null` keeps the notifier's default.
  late final TextEditingController _keyword = TextEditingController();

  /// The group the list is narrowed to, or `null` for every group (5.10 的「书源测试分类」).
  String? _group;

  /// The source types the list is narrowed to; the default is text, like an aggregate search
  /// (ADR-0046 §决策 2), because the stages only make sense for a text source.
  Set<BookSourceType> _types = <BookSourceType>{BookSourceType.text};

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<StoredBookSource>> sources = ref.watch(
      bookSourceListProvider,
    );
    final SourceCheckState state = ref.watch(sourceCheckProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceCheckTitle),
        backgroundColor: tokens.colors.surface,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: l10n.bookSourceCheckOpenDebug,
            onPressed: () => pushBookSourceRoute(
              context,
              const BookSourceRoute.debugSource(),
            ),
          ),
        ],
      ),
      body: switch (sources) {
        AsyncLoading<List<StoredBookSource>>() => const Center(
          child: CircularProgressIndicator(),
        ),
        AsyncError<List<StoredBookSource>>() => FailureMessage(
          kind: ParseFailureKind.networkFailed,
          onRetry: () => ref.invalidate(bookSourceListProvider),
        ),
        AsyncData<List<StoredBookSource>>(
          :final List<StoredBookSource> value,
        ) =>
          value.isEmpty
              ? StateMessage(message: l10n.bookSourceCheckEmpty)
              : _body(l10n, value, state),
      },
      bottomNavigationBar: sources.value == null || sources.value!.isEmpty
          ? null
          : _action(l10n, state),
    );
  }

  /// The scrollable half: controls, then one row per source.
  Widget _body(
    AppLocalizations l10n,
    List<StoredBookSource> sources,
    SourceCheckState state,
  ) {
    final List<StoredBookSource> visible = _visible(sources);
    final Set<int> selected = _effectiveSelection(visible, state);

    return ListView(
      children: <Widget>[
        _controls(l10n, state),
        const Divider(),
        _selectionFilters(l10n, sources),
        _selectionHeader(l10n, visible, state),
        for (final StoredBookSource source in visible)
          _row(l10n, source, state, selected),
      ],
    );
  }

  /// The group / type chips that decide which sources are listed (5.10 的「书源测试分类」).
  ///
  /// It is a **listing** filter, not a selection rule: the tick boxes still decide what runs, and
  /// narrowing the list keeps a previous selection untouched. The two axes mirror an aggregate
  /// search's inputs so the two screens agree on what "these sources" means (ADR-0046 §决策 1/2).
  Widget _selectionFilters(
    AppLocalizations l10n,
    List<StoredBookSource> sources,
  ) {
    final M3ETheme tokens = context.m3e;
    final List<String> groups = <String>{
      for (final StoredBookSource source in sources)
        ...splitGroups(source.groupName ?? source.source.group),
    }.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.sm,
      ),
      child: Row(
        children: <Widget>[
          FilterChip(
            label: Text(l10n.bookSourceListGroupAll),
            selected: _group == null,
            onSelected: (_) => setState(() => _group = null),
          ),
          for (final String group in groups) ...<Widget>[
            SizedBox(width: tokens.spacing.sm),
            FilterChip(
              label: Text(group),
              selected: _group == group,
              onSelected: (bool isSelected) =>
                  setState(() => _group = isSelected ? group : null),
            ),
          ],
          SizedBox(width: tokens.spacing.lg),
          for (final BookSourceType type in BookSourceType.values) ...<Widget>[
            SizedBox(width: tokens.spacing.sm),
            FilterChip(
              label: Text(_typeLabel(l10n, type)),
              selected: _types.contains(type),
              onSelected: (bool isSelected) => setState(() {
                final Set<BookSourceType> next = <BookSourceType>{..._types};
                if (isSelected) {
                  next.add(type);
                } else {
                  next.remove(type);
                }
                // 一个类型都不选等于没有可校验的源：保持至少一个。
                if (next.isNotEmpty) {
                  _types = next;
                }
              }),
            ),
          ],
        ],
      ),
    );
  }

  /// The sources the list shows after the group / type filters.
  List<StoredBookSource> _visible(List<StoredBookSource> sources) =>
      <StoredBookSource>[
        for (final StoredBookSource source in sources)
          if ((_group == null ||
                  splitGroups(source.groupName ?? source.source.group)
                      .contains(_group)) &&
              _types.contains(source.source.sourceType))
            source,
      ];

  /// The ARB label of [type].
  String _typeLabel(AppLocalizations l10n, BookSourceType type) =>
      switch (type) {
        BookSourceType.text => l10n.searchTypeText,
        BookSourceType.audio => l10n.searchTypeAudio,
        BookSourceType.image => l10n.searchTypeImage,
        BookSourceType.file => l10n.searchTypeFile,
        BookSourceType.video => l10n.searchTypeVideo,
      };

  /// The stage switches, the keyword and the timeout.
  Widget _controls(AppLocalizations l10n, SourceCheckState state) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.bookSourceCheckIntro,
            style: tokens.typography.base.bodyMedium,
          ),
          SizedBox(height: tokens.spacing.md),
          Text(
            l10n.bookSourceCheckStages,
            style: tokens.typography.base.titleSmall,
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: <Widget>[
              for (final SourceCheckStage stage in SourceCheckStage.values)
                FilterChip(
                  label: Text(_stageLabel(l10n, stage)),
                  selected: state.settings.runs(stage),
                  onSelected: state.isRunning
                      ? null
                      : (bool isSelected) => _toggleStage(stage, isSelected),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.lg),
          TextField(
            controller: _keyword,
            enabled: !state.isRunning,
            decoration: InputDecoration(
              labelText: l10n.bookSourceCheckKeyword,
              hintText: l10n.bookSourceCheckKeywordHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: _applyKeyword,
          ),
          SizedBox(height: tokens.spacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.bookSourceCheckTimeout,
                  style: tokens.typography.base.bodyMedium,
                ),
              ),
              DropdownButton<Duration>(
                value: state.settings.timeout,
                onChanged: state.isRunning
                    ? null
                    : (Duration? timeout) {
                        if (timeout != null) {
                          _updateSettings(
                            state.settings.copyWith(timeout: timeout),
                          );
                        }
                      },
                items: <DropdownMenuItem<Duration>>[
                  for (final Duration option in _timeoutOptions)
                    DropdownMenuItem<Duration>(
                      value: option,
                      child: Text('${option.inSeconds}s'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The select-all / select-none line above the source rows.
  Widget _selectionHeader(
    AppLocalizations l10n,
    List<StoredBookSource> sources,
    SourceCheckState state,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(width: context.m3e.spacing.lg),
        Expanded(
          child: Text(
            '${state.completed}/${state.entries.isEmpty ? sources.length : state.entries.length}',
            style: context.m3e.typography.base.labelLarge,
          ),
        ),
        TextButton(
          onPressed: state.isRunning
              ? null
              : () => setState(() {
                  _selection = <int>{
                    for (final StoredBookSource source in sources) source.id,
                  };
                }),
          child: Text(l10n.bookSourceCheckSelectAll),
        ),
        TextButton(
          onPressed: state.isRunning
              ? null
              : () => setState(() => _selection = <int>{}),
          child: Text(l10n.bookSourceCheckSelectNone),
        ),
      ],
    );
  }

  /// One source row: a tick box before a run, its verdict while and after one.
  Widget _row(
    AppLocalizations l10n,
    StoredBookSource source,
    SourceCheckState state,
    Set<int> selected,
  ) {
    final SourceCheckEntry? entry = _entryFor(state, source.id);
    final String subtitle = entry == null
        ? source.source.url
        : _entrySubtitle(l10n, entry);

    if (entry == null) {
      return CheckboxListTile(
        value: selected.contains(source.id),
        onChanged: state.isRunning
            ? null
            : (bool? isChecked) => _toggleSelection(source.id, isChecked),
        title: Text(source.source.name),
        subtitle: Text(subtitle),
        secondary: IconButton(
          icon: const Icon(Icons.bug_report_outlined),
          tooltip: l10n.bookSourceCheckOpenDebug,
          onPressed: () => pushBookSourceRoute(
            context,
            BookSourceRoute.debugSource(sourceId: source.id),
          ),
        ),
      );
    }

    return ListTile(
      leading: Icon(
        _statusIcon(entry.status),
        semanticLabel: _statusLabel(l10n, entry.status),
        color: _statusColor(entry.status),
      ),
      title: Text(source.source.name),
      subtitle: Text(subtitle),
      isThreeLine: entry.stages.isNotEmpty,
      trailing: entry.elapsedMillis == null
          ? null
          : Text(l10n.bookSourceCheckElapsed(entry.elapsedMillis!)),
    );
  }

  /// The start / stop button, with the progress line while a batch runs.
  Widget _action(AppLocalizations l10n, SourceCheckState state) {
    final M3ETheme tokens = context.m3e;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (state.isRunning)
              LinearProgressIndicator(
                value: state.entries.isEmpty
                    ? null
                    : state.completed / state.entries.length,
                semanticsLabel: l10n.bookSourceCheckStatusRunning,
              ),
            SizedBox(height: tokens.spacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isRunning
                    ? () => ref.read(sourceCheckProvider.notifier).cancel()
                    : () => _start(state),
                icon: Icon(
                  state.isRunning ? Icons.stop : Icons.fact_check_outlined,
                ),
                label: Text(
                  state.isRunning
                      ? l10n.bookSourceCheckStop
                      : l10n.bookSourceCheckStart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Starts a batch with the current selection and settings.
  void _start(SourceCheckState state) {
    final List<StoredBookSource> sources =
        ref.read(bookSourceListProvider).value ?? <StoredBookSource>[];
    final Set<int> selected = _effectiveSelection(sources, state);
    final List<StoredBookSource> chosen = sources
        .where((StoredBookSource source) => selected.contains(source.id))
        .toList(growable: false);
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).bookSourceCheckSelectionEmpty,
          ),
        ),
      );

      return;
    }

    unawaited(ref.read(sourceCheckProvider.notifier).start(chosen));
  }

  /// The tick boxes of the current run, or every source when the user has not chosen yet.
  Set<int> _effectiveSelection(
    List<StoredBookSource> sources,
    SourceCheckState state,
  ) {
    if (state.entries.isNotEmpty) {
      return <int>{
        for (final SourceCheckEntry entry in state.entries) entry.sourceId,
      };
    }

    return _selection ??
        <int>{for (final StoredBookSource source in sources) source.id};
  }

  /// The row of [sourceId] in the current run, or `null` before one.
  SourceCheckEntry? _entryFor(SourceCheckState state, int sourceId) {
    for (final SourceCheckEntry entry in state.entries) {
      if (entry.sourceId == sourceId) {
        return entry;
      }
    }

    return null;
  }

  /// Ticks or unticks [sourceId].
  void _toggleSelection(int sourceId, bool? isChecked) {
    final List<StoredBookSource> sources =
        ref.read(bookSourceListProvider).value ?? <StoredBookSource>[];
    final Set<int> selected = _effectiveSelection(
      sources,
      ref.read(sourceCheckProvider),
    );
    setState(() {
      if (isChecked ?? false) {
        selected.add(sourceId);
      } else {
        selected.remove(sourceId);
      }
      _selection = selected;
    });
  }

  /// Flips one stage switch.
  void _toggleStage(SourceCheckStage stage, bool isSelected) {
    final SourceCheckSettings settings = ref.read(sourceCheckProvider).settings;
    final Set<SourceCheckStage> stages = <SourceCheckStage>{...settings.stages};
    if (isSelected) {
      stages.add(stage);
    } else {
      stages.remove(stage);
    }
    _updateSettings(settings.copyWith(stages: stages));
  }

  /// Sends the typed keyword to the notifier.
  void _applyKeyword(String value) => _updateSettings(
    ref.read(sourceCheckProvider).settings.copyWith(keyword: value),
  );

  /// Replaces the run settings.
  void _updateSettings(SourceCheckSettings settings) =>
      ref.read(sourceCheckProvider.notifier).updateSettings(settings);

  /// The subtitle line of a row that has a verdict.
  String _entrySubtitle(AppLocalizations l10n, SourceCheckEntry entry) {
    final String status = _statusLabel(l10n, entry.status);
    final SourceCheckFailure? failure = entry.failure;
    final String reason = switch (failure) {
      SourceCheckFailure.checkFailed => l10n.bookSourceCheckFailureCheckFailed,
      SourceCheckFailure.sourceMissing =>
        l10n.bookSourceCheckFailureSourceMissing,
      SourceCheckFailure.saveFailed => l10n.bookSourceCheckFailureSaveFailed,
      null => '',
    };
    final SourceCheckStageOutcome? broken = _firstBroken(entry);
    final String where = switch (broken?.rulePath) {
      final String rulePath => l10n.bookSourceCheckFailedAt(rulePath),
      null => '',
    };

    return <String>[
      status,
      if (reason.isNotEmpty) reason,
      if (where.isNotEmpty) where,
    ].join(' · ');
  }

  /// The first failed stage of [entry], if any.
  SourceCheckStageOutcome? _firstBroken(SourceCheckEntry entry) {
    for (final SourceCheckStageOutcome outcome in entry.stages) {
      if (outcome.status == SourceCheckStatus.failed) {
        return outcome;
      }
    }

    return null;
  }

  /// The ARB label of [stage].
  String _stageLabel(AppLocalizations l10n, SourceCheckStage stage) =>
      switch (stage) {
        SourceCheckStage.search => l10n.bookSourceCheckStageSearch,
        SourceCheckStage.explore => l10n.bookSourceCheckStageExplore,
        SourceCheckStage.info => l10n.bookSourceCheckStageInfo,
        SourceCheckStage.toc => l10n.bookSourceCheckStageToc,
        SourceCheckStage.content => l10n.bookSourceCheckStageContent,
      };

  /// The ARB label of [status].
  String _statusLabel(AppLocalizations l10n, SourceCheckStatus status) =>
      switch (status) {
        SourceCheckStatus.pending => l10n.bookSourceCheckStatusPending,
        SourceCheckStatus.running => l10n.bookSourceCheckStatusRunning,
        SourceCheckStatus.succeeded => l10n.bookSourceCheckStatusSucceeded,
        SourceCheckStatus.failed => l10n.bookSourceCheckStatusFailed,
        SourceCheckStatus.cancelled => l10n.bookSourceCheckStatusCancelled,
      };

  /// The icon of [status]; the text label travels in `semanticLabel` (C-UI-7).
  IconData _statusIcon(SourceCheckStatus status) => switch (status) {
    SourceCheckStatus.pending => Icons.schedule,
    SourceCheckStatus.running => Icons.hourglass_top,
    SourceCheckStatus.succeeded => Icons.check_circle_outline,
    SourceCheckStatus.failed => Icons.error_outline,
    SourceCheckStatus.cancelled => Icons.cancel_outlined,
  };

  /// The colour of [status], taken from the theme (C-UI-1).
  Color? _statusColor(SourceCheckStatus status) => switch (status) {
    SourceCheckStatus.succeeded => context.m3e.colors.primary,
    SourceCheckStatus.failed => context.m3e.colors.error,
    SourceCheckStatus.pending ||
    SourceCheckStatus.running ||
    SourceCheckStatus.cancelled => null,
  };
}

/// The per-source timeouts the page offers; the middle one is the default (ADR-0043 §决策 2).
const List<Duration> _timeoutOptions = <Duration>[
  Duration(seconds: 30),
  Duration(seconds: 60),
  Duration(seconds: 120),
  Duration(seconds: 180),
  Duration(seconds: 300),
];
