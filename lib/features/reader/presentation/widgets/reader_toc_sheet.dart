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
///   the order switch keeps working while a query is active;
/// * **volume headings collapse** (ADR-0095): a volume entry from the source is a group header, not a
///   chapter row — tapping it folds the chapters below it instead of jumping, and a search ignores
///   the folding so a hit is never hidden.
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

  /// The volume headings the user folded, by their index in [ReaderTocSheet.chapters] (ADR-0095).
  final Set<int> _collapsedVolumes = <int>{};

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
    final List<_TocItem> shown = _itemsOf(rows);
    final int focus = shown.indexWhere(
      (_TocItem item) => item.index == widget.currentIndex,
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
                      final _TocItem item = shown[index];

                      // 卷标题是**组头**（ADR-0095）：点击只折叠，不跳转、不发请求。
                      if (item.isHeader) {
                        return ListTile(
                          leading: Icon(
                            item.isCollapsed
                                ? Icons.chevron_right
                                : Icons.expand_more,
                            semanticLabel: l10n.bookSourceTocTitle,
                          ),
                          title: Text(
                            item.chapter.title,
                            style: tokens.typography.base.titleSmall,
                          ),
                          onTap: () => setState(() {
                            if (!_collapsedVolumes.remove(item.index)) {
                              _collapsedVolumes.add(item.index);
                            }
                          }),
                        );
                      }

                      return ListTile(
                        selected: item.index == widget.currentIndex,
                        title: Text(item.chapter.title),
                        onTap: () => widget.onSelected(item.index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// The list to draw: volume headers plus the chapter rows they currently show.
  ///
  /// Order: the source's order, then reversed as a whole when the reader asked for it (ADR-0051
  /// §决策 2). A folded header hides its own chapters **until the next header**; a non-empty query
  /// ignores folding, because a hit the user cannot see is worse than a flat list (ADR-0095 §决策 2).
  List<_TocItem> _itemsOf(List<({int index, ReadingChapter chapter})> rows) {
    final bool searching = _query.text.trim().isNotEmpty;
    final List<_TocItem> items = <_TocItem>[];
    var folded = false;

    for (final ({int index, ReadingChapter chapter}) row in rows) {
      if (row.chapter.isVolume) {
        folded = !searching && _collapsedVolumes.contains(row.index);
        items.add(
          _TocItem(
            index: row.index,
            chapter: row.chapter,
            isHeader: true,
            isCollapsed: folded,
          ),
        );

        continue;
      }
      if (folded) {
        continue;
      }
      items.add(_TocItem(index: row.index, chapter: row.chapter));
    }

    return _reversed ? items.reversed.toList(growable: false) : items;
  }

  /// Whether [chapter] belongs to the current query.
  bool _matches(ReadingChapter chapter, String query) =>
      query.isEmpty ||
      chapter.title.toLowerCase().contains(query.toLowerCase());
}

/// One line of the table of contents: a volume header or a chapter (ADR-0095).
final class _TocItem {
  const _TocItem({
    required this.index,
    required this.chapter,
    this.isHeader = false,
    this.isCollapsed = false,
  });

  /// The chapter's index in the book, whatever the list currently shows.
  final int index;

  final ReadingChapter chapter;

  /// Whether this line is a volume heading rather than a readable chapter.
  final bool isHeader;

  /// Whether this header currently hides its chapters.
  final bool isCollapsed;
}
