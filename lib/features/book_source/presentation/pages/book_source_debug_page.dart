import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_debug.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/explore_categories.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_keyword.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/source_debug_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The single-source debug console (`docs/dev/roadmap.md` §5.10).
///
/// One source, one target, one query — and the event stream that shows what the chain did. The
/// page is deliberately a console rather than a form: the target switches the meaning of the query
/// (a keyword, or a page URL), the examples fill it in one tap, and the lines are the three kinds
/// of `SourceDebugEvent` (message / source / error) with their elapsed time.
class BookSourceDebugPage extends ConsumerStatefulWidget {
  /// Creates the page; [sourceId] pins a source, `null` uses the selected one.
  const BookSourceDebugPage({this.sourceId, super.key});

  /// The stored source to debug, or `null` for the one the source list has selected.
  final int? sourceId;

  @override
  ConsumerState<BookSourceDebugPage> createState() =>
      _BookSourceDebugPageState();
}

/// State of the console: the query field.
class _BookSourceDebugPageState extends ConsumerState<BookSourceDebugPage> {
  /// The query field; created in [initState] so `ref` is only touched while the widget is alive.
  late final TextEditingController _query;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: ref.read(sourceDebugProvider).query);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final SourceDebugState state = ref.watch(sourceDebugProvider);
    final AsyncValue<List<StoredBookSource>> sources = ref.watch(
      bookSourceListProvider,
    );
    final StoredBookSource? selected = ref
        .watch(selectedBookSourceProvider)
        .value;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceDebugTitle),
        backgroundColor: tokens.colors.surface,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.bookSourceDebugClear,
            onPressed: ref.read(sourceDebugProvider.notifier).clear,
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
          switch (_resolve(value, selected)) {
            final StoredBookSource stored => _body(l10n, stored, state),
            null => StateMessage(message: l10n.bookSourceDebugMissingSource),
          },
      },
    );
  }

  /// The scrollable half: source line, controls, then the event stream.
  Widget _body(
    AppLocalizations l10n,
    StoredBookSource stored,
    SourceDebugState state,
  ) {
    final M3ETheme tokens = context.m3e;
    final bool isRunning = state.status == SourceDebugStatus.running;
    final List<String> examples = _examples(stored.source, state);

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: <Widget>[
        Text(stored.source.name, style: tokens.typography.base.titleMedium),
        Text(stored.source.url, style: tokens.typography.base.bodySmall),
        SizedBox(height: tokens.spacing.md),
        SegmentedButton<SourceDebugTarget>(
          segments: <ButtonSegment<SourceDebugTarget>>[
            for (final SourceDebugTarget target in SourceDebugTarget.values)
              ButtonSegment<SourceDebugTarget>(
                value: target,
                label: Text(_targetLabel(l10n, target)),
              ),
          ],
          selected: <SourceDebugTarget>{state.target},
          onSelectionChanged: isRunning
              ? null
              : (Set<SourceDebugTarget> selection) => ref
                    .read(sourceDebugProvider.notifier)
                    .selectTarget(selection.single),
        ),
        SizedBox(height: tokens.spacing.lg),
        TextField(
          controller: _query,
          enabled: !isRunning,
          decoration: InputDecoration(
            labelText: l10n.bookSourceDebugQuery,
            hintText: state.target == SourceDebugTarget.search
                ? l10n.bookSourceDebugQueryKeywordHint
                : l10n.bookSourceDebugQueryUrlHint,
            border: const OutlineInputBorder(),
          ),
          onChanged: ref.read(sourceDebugProvider.notifier).setQuery,
        ),
        if (examples.isNotEmpty) ...<Widget>[
          SizedBox(height: tokens.spacing.md),
          Text(
            l10n.bookSourceDebugExamples,
            style: tokens.typography.base.labelLarge,
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: <Widget>[
              for (final String example in examples)
                ActionChip(
                  label: Text(example, overflow: TextOverflow.ellipsis),
                  onPressed: isRunning ? null : () => _useExample(example),
                ),
            ],
          ),
        ],
        SizedBox(height: tokens.spacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: isRunning
                    ? () => ref.read(sourceDebugProvider.notifier).stop()
                    : () => _run(stored.source, state),
                icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                label: Text(
                  isRunning
                      ? l10n.bookSourceDebugStop
                      : l10n.bookSourceDebugStart,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.sm),
            Text(
              _statusLabel(l10n, state.status),
              style: tokens.typography.base.labelLarge,
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.lg),
        if (state.events.isEmpty)
          StateMessage(message: l10n.bookSourceDebugEmpty)
        else
          for (final SourceDebugEvent event in state.events)
            _eventLine(l10n, event),
      ],
    );
  }

  /// One line of the console: kind chip, payload, elapsed time.
  Widget _eventLine(AppLocalizations l10n, SourceDebugEvent event) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Chip(
            label: Text(_eventLabel(l10n, event.kind)),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Text(
              // 载荷是数据（计数 / URL / rulePath），不是界面文案：直接用，不查 ARB（ADR-0043）。
              event.text,
              style: tokens.typography.base.bodySmall,
            ),
          ),
          SizedBox(width: tokens.spacing.sm),
          Text(
            '${event.elapsedMillis} ms',
            style: tokens.typography.base.labelSmall,
          ),
        ],
      ),
    );
  }

  /// Starts a run with the typed query.
  void _run(BookSource source, SourceDebugState state) {
    final String query = _query.text.trim();
    if (query.isEmpty) {
      return;
    }
    unawaited(
      ref
          .read(sourceDebugProvider.notifier)
          .start(source: source, target: state.target, query: query),
    );
  }

  /// Fills the query with an example and remembers it.
  void _useExample(String value) {
    _query.text = value;
    ref.read(sourceDebugProvider.notifier).setQuery(value);
  }

  /// The source to debug: the pinned one, else the list's selection, else the first stored one.
  StoredBookSource? _resolve(
    List<StoredBookSource> sources,
    StoredBookSource? selected,
  ) {
    final int? pinned = widget.sourceId;
    if (pinned != null) {
      for (final StoredBookSource source in sources) {
        if (source.id == pinned) {
          return source;
        }
      }

      return null;
    }

    if (selected != null) {
      return selected;
    }

    return sources.isEmpty ? null : sources.first;
  }

  /// The one-tap examples of the selected target.
  ///
  /// For the search target that is the keyword the check itself would use (the source's
  /// `checkKeyWord` when it is a real keyword, else the default); for the discover target it is the
  /// source's own category URLs; for the URL targets it is the URLs the current run already
  /// reported, which is what makes "run the search, then read the first hit" a two-tap job.
  List<String> _examples(BookSource source, SourceDebugState state) {
    switch (state.target) {
      case SourceDebugTarget.search:
        return <String>[
          resolveCheckKeyword(
            checkKeyWord: source.searchRule.checkKeyWord,
            fallback: defaultCheckKeyword,
          ),
        ];
      case SourceDebugTarget.explore:
        final ExploreCategoryParse parsed = parseExploreSource(
          source.exploreUrl ?? '',
        );

        return <String>[
          for (final ExploreCategory category in parsed.categories)
            category.url,
        ];
      case SourceDebugTarget.info:
      case SourceDebugTarget.toc:
      case SourceDebugTarget.content:
        final List<String> urls = <String>[];
        for (final SourceDebugEvent event in state.events) {
          final String? url = event.url;
          if (event.kind == SourceDebugEventKind.source &&
              url != null &&
              !urls.contains(url)) {
            urls.add(url);
          }
        }

        return urls;
    }
  }

  /// The ARB label of [target].
  String _targetLabel(AppLocalizations l10n, SourceDebugTarget target) =>
      switch (target) {
        SourceDebugTarget.search => l10n.bookSourceDebugTargetSearch,
        SourceDebugTarget.explore => l10n.bookSourceDebugTargetExplore,
        SourceDebugTarget.info => l10n.bookSourceDebugTargetInfo,
        SourceDebugTarget.toc => l10n.bookSourceDebugTargetToc,
        SourceDebugTarget.content => l10n.bookSourceDebugTargetContent,
      };

  /// The ARB label of [kind].
  String _eventLabel(AppLocalizations l10n, SourceDebugEventKind kind) =>
      switch (kind) {
        SourceDebugEventKind.message => l10n.bookSourceDebugEventMessage,
        SourceDebugEventKind.source => l10n.bookSourceDebugEventSource,
        SourceDebugEventKind.error => l10n.bookSourceDebugEventError,
      };

  /// The ARB label of the run status.
  String _statusLabel(AppLocalizations l10n, SourceDebugStatus status) =>
      switch (status) {
        SourceDebugStatus.idle => l10n.bookSourceDebugStatusIdle,
        SourceDebugStatus.running => l10n.bookSourceDebugStatusRunning,
        SourceDebugStatus.succeeded => l10n.bookSourceDebugStatusSucceeded,
        SourceDebugStatus.failed => l10n.bookSourceDebugStatusFailed,
        SourceDebugStatus.cancelled => l10n.bookSourceDebugStatusCancelled,
      };
}
