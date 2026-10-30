import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/change_source_search.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/switch_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/change_source_controller.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/source_scope_sheet.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Opens the change-source flow in a modal sheet and answers the pick
/// (`docs/dev/roadmap.md` §3.12, ADR-0091 §决策 1b).
///
/// A sheet rather than a page, in both entries (reader and book detail): it is the shape upstream
/// uses (`ChangeSourceSheet` / `ChangeChapterSourceSheet`), it keeps the reader's own screen behind
/// the picker, and it is the same amount of room — the two steps live **inside** one sheet, so
/// picking a source swaps the list for its chapters instead of pushing anything.
Future<ChangeSourceSelection?> showChangeSourceSheet(
  BuildContext context, {
  required ChangeSourceTarget target,
}) => showModalBottomSheet<ChangeSourceSelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (BuildContext context) => FractionallySizedBox(
    heightFactor: 0.92,
    child: ChangeSourceSheet(target: target),
  ),
);

/// The change-source flow in two steps, as sheet content.
///
/// Step one is the **candidate list**: a keyword, a scope, three optional loads, a progress bar and
/// start / pause / stop. Nothing is searched before 「开始搜索」 is tapped (`DECISIONS.md` #74) —
/// the first frame is a button, not a spinner, because a run can take half a minute.
///
/// Step two appears only after a source is picked: that source's chapters, with the aligned one
/// pre-selected, and 「确认换源」 as the only way out. The sheet answers a [ChangeSourceSelection];
/// applying it (shelf identity, selected source) belongs to the caller, which is what keeps the
/// reader free of `book_source` imports (C-ARCH-2).
///
/// Accessibility (C-UI-7): the keyword field is labelled, the scope is an `ActionChip` with visible
/// text, the three loads are `FilterChip`s, and the progress line is spoken through the same
/// `searchProgress` label the search page uses.
class ChangeSourceSheet extends ConsumerStatefulWidget {
  /// Creates the sheet content for [target].
  const ChangeSourceSheet({required this.target, super.key});

  /// The book being switched, plus where its reader currently is.
  final ChangeSourceTarget target;

  @override
  ConsumerState<ChangeSourceSheet> createState() => _ChangeSourceSheetState();
}

class _ChangeSourceSheetState extends ConsumerState<ChangeSourceSheet> {
  late final TextEditingController _keyword = TextEditingController(
    text: widget.target.name.trim(),
  );

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ChangeSourceState state = ref.watch(
      changeSourceControllerProvider(widget.target),
    );
    final ChangeSourceController controller = ref.read(
      changeSourceControllerProvider(widget.target).notifier,
    );
    final ChangeSourceCandidate? selected = state.selected;

    final M3ETheme tokens = context.m3e;

    return Padding(
      // 键盘弹出时把内容顶上来：关键词输入框在 sheet 里，被遮住就没法用。
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _header(l10n, tokens, controller, selected),
          Expanded(
            child: selected == null
                ? _listStep(l10n, state, controller)
                : _chapterStep(l10n, state, controller, selected),
          ),
          if (selected != null) _confirmBar(l10n, state, selected),
        ],
      ),
    );
  }

  /// The sheet's title row: the flow's name, or the picked source with a back arrow.
  Widget _header(
    AppLocalizations l10n,
    M3ETheme tokens,
    ChangeSourceController controller,
    ChangeSourceCandidate? selected,
  ) => Padding(
    padding: EdgeInsets.fromLTRB(
      tokens.spacing.lg,
      tokens.spacing.md,
      tokens.spacing.sm,
      tokens.spacing.xs,
    ),
    child: Row(
      children: <Widget>[
        if (selected != null)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.actionBack,
            onPressed: controller.backToCandidates,
          )
        else
          SizedBox(width: tokens.spacing.xs),
        Expanded(
          child: Text(
            selected == null ? l10n.readerChangeSource : selected.sourceName,
            style: tokens.typography.base.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 换源最常见的打开方式就是「这本书在别处叫什么」：把书名留在标题旁边。
        if (selected == null)
          Padding(
            padding: EdgeInsets.only(right: tokens.spacing.md),
            child: Text(
              widget.target.name,
              style: tokens.typography.base.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
  );

  /// Step one: keyword, scope, loads, progress, start/pause/stop, candidates.
  Widget _listStep(
    AppLocalizations l10n,
    ChangeSourceState state,
    ChangeSourceController controller,
  ) {
    final M3ETheme tokens = context.m3e;
    final List<StoredBookSource> rows =
        ref.watch(bookSourceListProvider).value ?? const <StoredBookSource>[];
    final BookSearchScope scope =
        ref.watch(changeSourceScopeSelectionProvider).value ??
        BookSearchScope.defaults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _keyword,
                decoration: InputDecoration(
                  labelText: l10n.changeSourceKeyword,
                  prefixIcon: const Icon(Icons.search),
                ),
                textInputAction: TextInputAction.search,
                onChanged: controller.setKeyword,
                onSubmitted: (_) => unawaited(controller.start(scope: scope)),
              ),
              SizedBox(height: tokens.spacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ActionChip(
                      avatar: const Icon(Icons.filter_alt_outlined),
                      label: Text(
                        sourceScopeLabel(l10n, scope),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _openScopeSheet(scope, rows),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.sm),
                  _startButton(l10n, state, controller, scope),
                ],
              ),
              SizedBox(height: tokens.spacing.sm),
              Wrap(
                spacing: tokens.spacing.xs,
                children: <Widget>[
                  FilterChip(
                    label: Text(l10n.changeSourceCheckAuthor),
                    selected: state.checkAuthor,
                    onSelected: (bool value) =>
                        controller.setCheckAuthor(enabled: value),
                  ),
                  FilterChip(
                    label: Text(l10n.changeSourceLoadInfo),
                    selected: state.loadInfo,
                    onSelected: (bool value) =>
                        controller.setLoadInfo(enabled: value),
                  ),
                  FilterChip(
                    label: Text(l10n.changeSourceLoadToc),
                    selected: state.loadToc,
                    onSelected: (bool value) =>
                        controller.setLoadToc(enabled: value),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.status != ChangeSourceStatus.idle) _progress(l10n, state),
        Expanded(child: _candidates(l10n, state, controller)),
      ],
    );
  }

  /// 「开始搜索」 while idle; pause / resume / stop while a run is in flight.
  Widget _startButton(
    AppLocalizations l10n,
    ChangeSourceState state,
    ChangeSourceController controller,
    BookSearchScope scope,
  ) {
    final M3ETheme tokens = context.m3e;
    if (state.status != ChangeSourceStatus.searching) {
      return FilledButton.icon(
        onPressed: () => unawaited(controller.start(scope: scope)),
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.changeSourceStart),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextButton(
          onPressed: state.isPaused ? controller.resume : controller.pause,
          child: Text(state.isPaused ? l10n.searchResume : l10n.searchPause),
        ),
        SizedBox(width: tokens.spacing.xs),
        TextButton(onPressed: controller.stop, child: Text(l10n.searchStop)),
      ],
    );
  }

  /// The progress bar plus the counters of the run.
  Widget _progress(AppLocalizations l10n, ChangeSourceState state) {
    final M3ETheme tokens = context.m3e;
    final bool running = state.status == ChangeSourceStatus.searching;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (running)
            LinearProgressIndicator(
              value: state.totalSources == 0
                  ? null
                  : state.processedSources / state.totalSources,
              semanticsLabel: l10n.searchProgress(
                state.processedSources,
                state.totalSources,
              ),
            ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            <String>[
              l10n.searchProgress(state.processedSources, state.totalSources),
              l10n.changeSourceFound(state.candidates.length),
              if (state.failedSources > 0)
                l10n.searchPartialFailed(state.failedSources),
            ].join(' · '),
            style: tokens.typography.base.bodySmall,
          ),
          SizedBox(height: tokens.spacing.xs),
        ],
      ),
    );
  }

  /// The candidate list, or the reason it is empty.
  Widget _candidates(
    AppLocalizations l10n,
    ChangeSourceState state,
    ChangeSourceController controller,
  ) {
    final M3ETheme tokens = context.m3e;

    if (state.status == ChangeSourceStatus.idle) {
      return StateMessage(
        message: l10n.changeSourceSearchPrompt,
        icon: Icons.swap_horiz,
      );
    }
    if (state.status == ChangeSourceStatus.failed) {
      if (state.totalSources == 0) {
        return StateMessage(
          message: l10n.changeSourceNoSources,
          icon: Icons.filter_alt_off_outlined,
        );
      }

      return FailureMessage(
        kind: state.failureKind ?? ParseFailureKind.parseFailed,
        onRetry: () => unawaited(
          controller.start(
            scope:
                ref.read(changeSourceScopeSelectionProvider).value ??
                BookSearchScope.defaults,
          ),
        ),
      );
    }
    if (state.status == ChangeSourceStatus.searching &&
        state.candidates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.candidates.isEmpty) {
      return StateMessage(message: l10n.readerSourceEmpty);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        0,
        tokens.spacing.lg,
        tokens.spacing.lg,
      ),
      itemCount: state.candidates.length,
      itemBuilder: (BuildContext context, int index) {
        final ChangeSourceCandidate candidate = state.candidates[index];

        return ListTile(
          leading: CoverImage(
            url: candidate.book.coverUrl,
            width: tokens.spacing.xxl,
            height: tokens.spacing.xxl * 1.35,
          ),
          title: Text(candidate.sourceName),
          subtitle: Text(
            <String>[
              if (candidate.book.author case final String author
                  when author.isNotEmpty)
                l10n.bookSourceAuthorLine(author),
              if (candidate.chapterCount case final int count)
                l10n.readerSourceChapters(count),
              if (candidate.book.lastChapter case final String chapter
                  when chapter.isNotEmpty)
                chapter,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(controller.openCandidate(candidate)),
        );
      },
    );
  }

  /// Step two: the picked source's chapters, with the aligned one pre-selected.
  Widget _chapterStep(
    AppLocalizations l10n,
    ChangeSourceState state,
    ChangeSourceController controller,
    ChangeSourceCandidate candidate,
  ) {
    final M3ETheme tokens = context.m3e;

    if (state.isLoadingChapters) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.changeSourceChapterTitle,
                style: tokens.typography.base.titleMedium,
              ),
              if (widget.target.chapterName.isNotEmpty) ...<Widget>[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  l10n.changeSourceCurrentChapter(widget.target.chapterName),
                  style: tokens.typography.base.bodySmall,
                ),
              ],
              if (state.chapterIndex >= 0 &&
                  state.chapterIndex < state.chapters.length) ...<Widget>[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  l10n.changeSourceAlignHint(
                    state.chapters[state.chapterIndex].name,
                  ),
                  style: tokens.typography.base.bodySmall,
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _chapters(l10n, state, controller, candidate)),
      ],
    );
  }

  /// The chapter list, or the failure that kept it away.
  Widget _chapters(
    AppLocalizations l10n,
    ChangeSourceState state,
    ChangeSourceController controller,
    ChangeSourceCandidate candidate,
  ) {
    if (state.chaptersFailure case final ParseFailureKind kind) {
      return FailureMessage(
        kind: kind,
        onRetry: () => unawaited(controller.openCandidate(candidate)),
      );
    }
    if (state.chapters.isEmpty) {
      return StateMessage(message: l10n.changeSourceNoChapters);
    }

    return ListView.builder(
      itemCount: state.chapters.length,
      itemBuilder: (BuildContext context, int index) {
        final Chapter chapter = state.chapters[index];
        final bool isSelected = index == state.chapterIndex;

        return ListTile(
          selected: isSelected,
          title: Text(chapter.name),
          trailing: isSelected
              ? Icon(
                  Icons.check_circle,
                  semanticLabel: l10n.changeSourceConfirm,
                )
              : null,
          onTap: () => controller.selectChapter(index),
        );
      },
    );
  }

  /// 「确认换源」: the only way out of step two.
  Widget _confirmBar(
    AppLocalizations l10n,
    ChangeSourceState state,
    ChangeSourceCandidate candidate,
  ) {
    final M3ETheme tokens = context.m3e;
    final bool canConfirm =
        state.chapters.isNotEmpty &&
        state.chapterIndex >= 0 &&
        state.chapterIndex < state.chapters.length;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: FilledButton.icon(
          onPressed: canConfirm
              ? () => Navigator.of(context).pop<ChangeSourceSelection>(
                  ChangeSourceSelection(
                    candidate: candidate,
                    chapters: state.chapters,
                    chapterIndex: state.chapterIndex,
                  ),
                )
              : null,
          icon: const Icon(Icons.swap_horiz),
          label: Text(l10n.changeSourceConfirm),
        ),
      ),
    );
  }

  /// Opens the shared scope sheet; the picked scope is persisted for the next switch.
  void _openScopeSheet(BookSearchScope scope, List<StoredBookSource> rows) {
    unawaited(
      showSourceScopeSheet(
        context: context,
        initial: scope,
        rows: rows,
        onSelected: ref
            .read(changeSourceScopeSelectionProvider.notifier)
            .select,
      ),
    );
  }
}
