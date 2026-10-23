import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// The chapter list of the reader (`docs/dev/roadmap.md` §3.9-R2, ADR-0051 §决策 2).
///
/// Three behaviours, all of them view-only:
///
/// * **the current chapter starts centred**: the list is built with an estimated initial offset
///   instead of scrolling after the fact, so the sheet never flickers from the top. Estimating is
///   good enough because it is corrected by the user's next scroll;
/// * **reversed order is a view**: the underlying list is untouched, so tapping a row still opens
///   the chapter it names and the progress index never flips;
/// * **search filters by chapter name**, case-insensitively; an empty query shows everything, and
///   the order switch keeps working while a query is active.
///
/// It is stateful only for the query and the order; the chapter data and the open index come from
/// the caller, so the sheet can never disagree with the session about where the reader is.
class ReaderTocSheet extends StatefulWidget {
  /// Creates the sheet.
  const ReaderTocSheet({
    required this.chapters,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  /// Every chapter, in the source's order.
  final List<ReadingChapter> chapters;

  /// The index of the chapter the reader is on.
  final int currentIndex;

  /// Called with the index of the chapter the user picked.
  final ValueChanged<int> onSelected;

  @override
  State<ReaderTocSheet> createState() => _ReaderTocSheetState();
}

class _ReaderTocSheetState extends State<ReaderTocSheet> {
  final TextEditingController _query = TextEditingController();

  /// Whether the list is shown top-down from the last chapter.
  bool _reversed = false;

  /// The height one row is assumed to have, used to start the list near the current chapter.
  ///
  /// A `ListTile` with a one-line title is 56; the estimate only has to land close enough that the
  /// user sees the highlighted row, not perform a pixel-accurate jump.
  static const double _rowExtent = 56;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    // 索引与章节的对应关系在过滤 / 倒序之后仍要成立，所以每次都带着原索引走一遍。
    final List<({int index, ReadingChapter chapter})> rows =
        <({int index, ReadingChapter chapter})>[
          for (var index = 0; index < widget.chapters.length; index++)
            if (_matches(widget.chapters[index], _query.text.trim()))
              (index: index, chapter: widget.chapters[index]),
        ];
    final List<({int index, ReadingChapter chapter})> shown = _reversed
        ? rows.reversed.toList(growable: false)
        : rows;
    final int focus = shown.indexWhere(
      (({int index, ReadingChapter chapter}) row) =>
          row.index == widget.currentIndex,
    );

    return SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.md,
              tokens.spacing.sm,
              0,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.bookSourceTocTitle,
                    style: tokens.typography.base.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _reversed = !_reversed),
                  icon: Icon(
                    _reversed ? Icons.sort : Icons.sort_outlined,
                    semanticLabel: l10n.readerTocSort,
                  ),
                  label: Text(l10n.readerTocSort),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.lg,
              vertical: tokens.spacing.xs,
            ),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.readerTocSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      l10n.bookSourceListNoMatch,
                      style: tokens.typography.base.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    // 当前章居中：初始偏移按「它前面有几行 × 行高」估算（§决策 2）。
                    controller: ScrollController(
                      initialScrollOffset: focus <= 0
                          ? 0
                          : (focus * _rowExtent).toDouble(),
                    ),
                    itemCount: shown.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ({int index, ReadingChapter chapter}) row =
                          shown[index];

                      return ListTile(
                        selected: row.index == widget.currentIndex,
                        title: Text(row.chapter.title),
                        onTap: () => widget.onSelected(row.index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Whether [chapter] belongs to the current query.
  bool _matches(ReadingChapter chapter, String query) =>
      query.isEmpty ||
      chapter.title.toLowerCase().contains(query.toLowerCase());
}
