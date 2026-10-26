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
/// which keyword, how long a source may take) and the **rows** (one per listed source, showing its
/// tick box and — once a run reached it — its stage outcomes). While a batch runs the controls are
/// disabled instead of hidden, so the user can see what is being run.
///
/// Two rules decide **which sources run** (ADR-0057):
///
/// * the group / type chips are the **default selection**: with no tick of its own the page runs
///   exactly the rows the filters leave visible, so 「只看某分组」和「只校验该分组」是同一件事；
/// * a tick overrides that default until the filters change (a filter change is a new question,
///   so the ticks go back to “whatever is listed”), and the run is always the ticks **∩** the
///   visible rows — the same rule the list page's batch actions follow (ADR-0050 §决策 2).
///
/// The selection is page state, not notifier state: it is a view decision ("what did I tick"), it
/// never outlives the page, and nothing else reads it (C-STATE-5). It is deliberately **not**
/// derived from the last run's entries: tying the ticks to a finished run is what made the page
/// impossible to use for a second batch.
class BookSourceCheckPage extends ConsumerStatefulWidget {
  /// Creates the page.
  ///
  /// [initialSourceIds] and [initialGroup] are how another screen hands over a target: the source
  /// list's batch bar passes the ticked rows and its toolbar passes the active group filter
  /// (`BookSourceRoute.checkSources`). Both are **starting points**, not locks — the chips and
  /// tick boxes stay editable.
  const BookSourceCheckPage({
    this.initialSourceIds = const <int>{},
    this.initialGroup,
    super.key,
  });

  /// The rows to tick when the page opens; empty means “whatever the filters show”.
  final Set<int> initialSourceIds;

  /// The group chip to preselect, or `null` for every group.
  final String? initialGroup;

  @override
  ConsumerState<BookSourceCheckPage> createState() =>
      _BookSourceCheckPageState();
}

/// State of the check page: the tick boxes, the filters and the keyword field.
class _BookSourceCheckPageState extends ConsumerState<BookSourceCheckPage> {
  /// Which rows the user ticked, or `null` while the selection simply follows the filters.
  Set<int>? _selection;

  /// The keyword the user typed; `null` keeps the notifier's default.
  late final TextEditingController _keyword = TextEditingController();

  /// The group the list is narrowed to, or `null` for every group (5.10 的「书源测试分类」).
  late String? _group;

  /// The source types the list is narrowed to.
  ///
  /// 空手进来时默认文本：校验的阶段只对文本源有意义（ADR-0046 §决策 2）。
  /// 但从别处带着「测这些」进来时不能用这个默认值 —— 那会把用户点名的图片 / 音频源直接筛掉，
  /// 于是「测选中的源」变成「一条也不选」。
  late Set<BookSourceType> _types;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialSourceIds.isEmpty
        ? null
        : <int>{...widget.initialSourceIds};
    _group = widget.initialGroup;
    _types = widget.initialSourceIds.isEmpty && widget.initialGroup == null
        ? <BookSourceType>{BookSourceType.text}
        : <BookSourceType>{...BookSourceType.values};
  }

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
              ? StateMessage(
                  message: l10n.bookSourceCheckEmpty,
                  icon: Icons.fact_check_outlined,
                )
              : _body(l10n, value, state),
      },
      bottomNavigationBar: (sources.value?.isEmpty ?? true)
          ? null
          : _action(l10n, state),
    );
  }

  /// The scrollable half: controls, then one row per source.
  ///
  /// 行是懒加载的（C-PERF-2）：书源可以上千条，一次性建出全部 `CheckboxListTile` 会让进入
  /// 页面的第一帧就卡住。前四项是固定头部，`index - _headerCount` 映射到书源。
  Widget _body(
    AppLocalizations l10n,
    List<StoredBookSource> sources,
    SourceCheckState state,
  ) {
    final List<StoredBookSource> visible = _visible(sources);
    final Set<int> selected = _effectiveSelection(visible);

    return ListView.builder(
      itemCount: visible.length + _headerCount,
      itemBuilder: (BuildContext context, int index) => switch (index) {
        0 => _controls(l10n, state),
        1 => const Divider(),
        2 => _selectionFilters(l10n, sources),
        3 => _selectionHeader(l10n, selected, state),
        _ => _row(l10n, visible[index - _headerCount], state, selected),
      },
    );
  }

  /// The four header rows: the controls, the divider, the filter chips and the selection line.
  static const int _headerCount = 4;

  /// The group / type chips that decide which sources take part (5.10 的「书源测试分类」).
  ///
  /// They are the **default selection**, not a listing filter (ADR-0057): with no tick of its own
  /// the page runs exactly what the chips leave visible. Changing either axis therefore drops back
  /// to that default — carrying a previous group's ticks into a new filter would intersect to the
  /// empty set, and 「至少选择一条书源」 would become the default experience after every filter change.
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
            onSelected: (_) => setState(() {
              _group = null;
              _selection = null;
            }),
          ),
          for (final String group in groups) ...<Widget>[
            SizedBox(width: tokens.spacing.sm),
            FilterChip(
              label: Text(group),
              selected: _group == group,
              onSelected: (bool isSelected) => setState(() {
                _group = isSelected ? group : null;
                _selection = null;
              }),
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
                  _selection = null;
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
  ///
  /// The count is “done / will run”: before a run it shows the ticked rows, because that is the
  /// number the start button is about to use (a group filter can cut the library down, and the
  /// old “everything” count hid that).
  Widget _selectionHeader(
    AppLocalizations l10n,
    Set<int> selected,
    SourceCheckState state,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(width: context.m3e.spacing.lg),
        Expanded(
          child: Text(
            '${state.completed}/${state.entries.isEmpty ? selected.length : state.entries.length}',
            style: context.m3e.typography.base.labelLarge,
          ),
        ),
        TextButton(
          // 「全选」回到默认而不是写死一份 id：切分组 / 切类型后它仍然是当前可见的全选。
          onPressed: state.isRunning
              ? null
              : () => setState(() => _selection = null),
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

  /// One source row: a tick box, its URL, and — once a run reached it — its verdict.
  ///
  /// The tick stays available after a run (ADR-0057): replacing the picker with a verdict tile
  /// froze the page on the last batch, so a user who wanted to check three more sources had to
  /// leave and re-enter the page.
  Widget _row(
    AppLocalizations l10n,
    StoredBookSource source,
    SourceCheckState state,
    Set<int> selected,
  ) {
    final SourceCheckEntry? entry = _entryFor(state, source.id);
    final String subtitle = entry == null
        ? source.source.url
        : <String>[
            _entrySubtitle(l10n, entry),
            if (entry.elapsedMillis case final int millis)
              l10n.bookSourceCheckElapsed(millis),
          ].join(' · ');

    return CheckboxListTile(
      value: selected.contains(source.id),
      onChanged: state.isRunning
          ? null
          : (bool? isChecked) => _toggleSelection(source.id, isChecked),
      title: Text(source.source.name),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      // 校验过的行可能有状态 + 原因 + 耗时（最多两行）；没校验的行保持两行总高度。
      isThreeLine: entry != null,
      // 勾选框说「这次跑不跑」，右侧要么是调试入口，要么是本轮结论的状态灯（C-UI-7）。
      secondary: entry == null
          ? IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: l10n.bookSourceCheckOpenDebug,
              onPressed: () => pushBookSourceRoute(
                context,
                BookSourceRoute.debugSource(sourceId: source.id),
              ),
            )
          : Icon(
              _statusIcon(entry.status),
              semanticLabel: _statusLabel(l10n, entry.status),
              color: _statusColor(entry.status),
            ),
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
  ///
  /// 运行的集合 = 当前筛选留下的行 ∩ 用户的勾选（ADR-0057）：筛选本身就是「哪些源参与」的
  /// 第一层答案，旧的「未勾选就把全库丢进去」会把 500 条源全跑一遍。
  void _start(SourceCheckState state) {
    final List<StoredBookSource> sources =
        ref.read(bookSourceListProvider).value ?? <StoredBookSource>[];
    final Set<int> selected = _effectiveSelection(_visible(sources));
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

  /// The ids the start button will run: the visible rows, narrowed by the ticks.
  ///
  /// A tick on a row the filters later hide is **not** dropped from [_selection] (the user's
  /// intent survives a look at another group); it simply does not take part while the filter
  /// hides it.
  Set<int> _effectiveSelection(List<StoredBookSource> visible) {
    final Set<int> visibleIds = <int>{
      for (final StoredBookSource source in visible) source.id,
    };
    final Set<int>? explicit = _selection;

    return explicit == null ? visibleIds : visibleIds.intersection(explicit);
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
    final Set<int> selected = <int>{..._effectiveSelection(_visible(sources))};
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
