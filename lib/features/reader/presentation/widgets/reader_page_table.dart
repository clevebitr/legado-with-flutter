/// The reader's page table: the pages both reading modes render, measured before they are built.
library;

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';

/// Where a page sits in the book: its chapter, and its index inside that chapter.
///
/// The identity is deliberately **not** the chapter's URL: a scraped table of contents often points
/// two chapters at one address, and keying by URL would collapse them into a single body
/// (`docs/dev/adr/0087-reader-page-table-and-chapter-heading.md` §决策 1).
typedef ReaderPageId = ({int chapterIndex, int pageIndex});

/// One page of the reader: a slice of one chapter, with the height it will take.
///
/// A page is measured **before** it is built (C-PERF-1): the flows render what the table says and
/// never measure text themselves, which is what lets a structural change be compensated in the same
/// frame instead of one frame late (ADR-0087 §决策 2).
@immutable
class ReaderPageEntry {
  /// Creates one page.
  const ReaderPageEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.text,
    required this.start,
    required this.end,
    required this.titleExtent,
    required this.bodyExtent,
    required this.isFailed,
  });

  /// The page's stable identity.
  final ReaderPageId id;

  /// The chapter's address, used to match the read-aloud highlight.
  final String url;

  /// The chapter heading, printed only on the chapter's first page; empty elsewhere.
  final String title;

  /// The laid-out chapter body the slice belongs to, or `null` on a loading page.
  final String? text;

  /// Where the slice starts in [text].
  final int start;

  /// Where the slice ends in [text] (exclusive).
  final int end;

  /// The height the heading takes at the top of this page (heading + its gap), `0` without one.
  final double titleExtent;

  /// The height of the body (or of the loading block that stands in for it).
  final double bodyExtent;

  /// Whether the chapter's body could not be read (the loading block offers a retry).
  final bool isFailed;

  /// Whether this page stands in for a chapter whose body has not arrived.
  bool get isPlaceholder => text == null;

  /// Whether this page carries the chapter heading.
  bool get hasTitle => titleExtent > 0;

  /// The height this page occupies in the flow.
  double get extent => titleExtent + bodyExtent;

  /// The height one character of the body occupies, on average.
  double get _perChar => end > start ? bodyExtent / (end - start) : 0;

  /// The character offset [distance] pixels into this page.
  int charOffsetAt(double distance) {
    if (isPlaceholder || end <= start) {
      return start;
    }
    final double fraction = ((distance - titleExtent) / bodyExtent).clamp(
      0.0,
      1.0,
    );

    return (start + fraction * (end - start)).round().clamp(start, end);
  }

  /// How far into this page [charOffset] sits.
  double distanceOf(int charOffset) {
    if (isPlaceholder || end <= start) {
      return 0;
    }
    final int clamped = charOffset.clamp(start, end);

    return titleExtent + (clamped - start) * _perChar;
  }
}

/// The pages both reading modes render, with every page's top already added up.
@immutable
class ReaderPageTable {
  /// Creates a table from [pages]; the tops and the total are derived, never passed in.
  ReaderPageTable({
    required this.pages,
    required this.hasNextChapter,
    required this.box,
  }) : tops = _topsOf(pages),
       totalExtent = pages.fold(0.0, (double sum, e) => sum + e.extent),
       signature = _signatureOf(pages, hasNextChapter);

  /// An empty table, used before the chapter list or the viewport size is known.
  const ReaderPageTable.empty()
    : pages = const <ReaderPageEntry>[],
      tops = const <double>[],
      totalExtent = 0,
      signature = 0,
      hasNextChapter = false,
      box = Size.zero;

  /// The pages, in reading order.
  final List<ReaderPageEntry> pages;

  /// The content-space top of each page, parallel to [pages].
  final List<double> tops;

  /// How tall every page together is.
  final double totalExtent;

  /// Whether the book continues after the last rendered page.
  final bool hasNextChapter;

  /// The content box the pages were measured in (the viewport minus the page margins).
  ///
  /// The scroll flow needs it to work out how much blank has to follow the last page for that page
  /// to be scrollable to the top (ADR-0087 §决策 2).
  final Size box;

  /// A cheap identity of the layout: it changes when a page appears, disappears or is re-measured.
  ///
  /// The flows compare it to decide whether the scroll position has to be put back on the reader's
  /// text — comparing the pages field by field would be the same thing, only slower.
  final int signature;

  /// Whether there is nothing to read yet.
  bool get isEmpty => pages.isEmpty;

  /// How many pages the table holds.
  int get length => pages.length;

  /// The cumulative tops of [pages].
  static List<double> _topsOf(List<ReaderPageEntry> pages) {
    final List<double> tops = <double>[];
    var top = 0.0;
    for (final ReaderPageEntry page in pages) {
      tops.add(top);
      top += page.extent;
    }

    return tops;
  }

  /// The identity of one layout.
  static int _signatureOf(List<ReaderPageEntry> pages, bool hasNextChapter) =>
      Object.hash(
        hasNextChapter,
        pages.length,
        Object.hashAll(
          pages.map(
            (ReaderPageEntry page) => Object.hash(
              page.id.chapterIndex,
              page.id.pageIndex,
              page.extent,
              page.title.length,
              identityHashCode(page.text),
              page.isFailed,
            ),
          ),
        ),
      );

  /// The page at [index], or `null` outside the table.
  ReaderPageEntry? pageAt(int index) =>
      index < 0 || index >= pages.length ? null : pages[index];

  /// Where [id] sits in the table, or `-1`.
  int indexOfId(ReaderPageId id) => pages.indexWhere(
    (ReaderPageEntry page) =>
        page.id.chapterIndex == id.chapterIndex &&
        page.id.pageIndex == id.pageIndex,
  );

  /// The index of the page whose box holds [offset], clamped into the table.
  int indexAt(double offset) {
    if (pages.isEmpty) {
      return -1;
    }
    for (var index = pages.length - 1; index >= 0; index--) {
      if (offset >= tops[index]) {
        return index;
      }
    }

    return 0;
  }

  /// Where the top of the viewport is: the chapter and the character offset inside it.
  ///
  /// This is the reader's anchor (ADR-0087 §决策 2). A character offset — not a page number and not
  /// a pixel — because the page table is rebuilt whenever a body arrives or the typography changes,
  /// and the same sentence has to stay under the reader's eyes through all of it.
  ({int chapterIndex, int charOffset})? positionAt(double offset) {
    final int index = indexAt(offset);
    if (index < 0) {
      return null;
    }
    final ReaderPageEntry page = pages[index];

    return (
      chapterIndex: page.id.chapterIndex,
      charOffset: page.charOffsetAt(offset - tops[index]),
    );
  }

  /// The content offset that puts character [charOffset] of chapter [chapterIndex] at the top.
  ///
  /// `null` when that chapter is not in the table at all, so a position from before a source switch
  /// cannot silently land on some other chapter.
  double? offsetOf(int chapterIndex, int charOffset) {
    final int index = indexOfChapter(chapterIndex, charOffset);
    if (index < 0) {
      return null;
    }

    return tops[index] + pages[index].distanceOf(charOffset);
  }

  /// The index of the page of chapter [chapterIndex] that holds [charOffset].
  ///
  /// The chapter's pages are contiguous, so this is a lookup inside one run of the table; an offset
  /// past the chapter's end answers its last page instead of falling through to the next chapter.
  int indexOfChapter(int chapterIndex, int charOffset) {
    var found = -1;
    for (var index = 0; index < pages.length; index++) {
      final ReaderPageEntry page = pages[index];
      if (page.id.chapterIndex != chapterIndex) {
        continue;
      }
      if (found < 0) {
        found = index;
      }
      if (page.isPlaceholder || page.start <= charOffset) {
        found = index;
      } else {
        break;
      }
    }

    return found;
  }
}

/// Measures page tables once per chapter and keeps the result for the next build.
///
/// The reader rebuilds on every progress write, so re-measuring three chapters per frame would be
/// the most expensive thing on the page (C-PERF-1). The key carries the width, the page height, both
/// styles, the heading gap and the body length: anything that changes a page's height invalidates
/// exactly the chapters it touches.
class ReaderPageMeasureCache {
  final Map<int, ({int signature, ReaderChapterMeasure measure})> _chapters =
      <int, ({int signature, ReaderChapterMeasure measure})>{};

  /// Matches one chapter's pages to the measuring box they will be rendered in.
  ///
  /// See [buildReaderPageTable] for what each argument means; [index] is the chapter's place in the
  /// table of contents and [text] its laid-out body (`null` while it is not in hand).
  ReaderChapterMeasure measure({
    required int index,
    required String title,
    required String? text,
    required Size size,
    required TextStyle bodyStyle,
    required TextStyle titleStyle,
    required double titleGap,
    required double loadingExtent,
    required TextScaler textScaler,
  }) {
    final int signature = Object.hash(
      size.width,
      size.height,
      bodyStyle,
      titleStyle,
      titleGap,
      title.length,
      text?.length,
      textScaler.scale(1),
    );
    final ({int signature, ReaderChapterMeasure measure})? cached =
        _chapters[index];
    if (cached != null && cached.signature == signature) {
      return cached.measure;
    }
    final double width = size.width;
    final double titleExtent = title.isEmpty || width <= 0
        ? 0
        : readerTextHeight(
                text: title,
                style: titleStyle,
                width: width,
                textScaler: textScaler,
              ) +
              titleGap;
    final String? body = text;
    final List<int> starts = body == null || width <= 0
        ? const <int>[0]
        : readerPageStarts(
            text: body,
            style: bodyStyle,
            size: size,
            textScaler: textScaler,
            firstPageInset: titleExtent,
          );
    final List<double> extents = <double>[
      for (var page = 0; page < starts.length; page++)
        if (body == null)
          loadingExtent
        else
          readerTextHeight(
            text: body.substring(
              starts[page],
              page + 1 < starts.length ? starts[page + 1] : body.length,
            ),
            style: bodyStyle,
            width: width,
            textScaler: textScaler,
          ),
    ];
    final ReaderChapterMeasure measure = (
      titleExtent: titleExtent,
      starts: starts,
      extents: extents,
    );
    _chapters[index] = (signature: signature, measure: measure);

    return measure;
  }

  /// Drops everything but [keep], so a long read does not keep every chapter measured.
  void retain(Iterable<int> keep) {
    final Set<int> wanted = keep.toSet();
    _chapters.removeWhere((int index, _) => !wanted.contains(index));
  }

  /// Forgets every measurement.
  void clear() => _chapters.clear();
}

/// One chapter's measurement: the heading's height, where its pages start, and how tall each is.
typedef ReaderChapterMeasure = ({
  double titleExtent,
  List<int> starts,
  List<double> extents,
});

/// Builds the page table for the chapters `firstChapter..lastChapter`.
///
/// [size] is the **content box** a page is measured in (the viewport minus the page margins);
/// [bodies] is keyed by chapter index and holds the laid-out body (see `readerBodyText`), and a
/// chapter missing from it becomes one loading page — never nothing, so a chapter boundary stays a
/// page away instead of a fetch away (ADR-0085 §决策 5, ADR-0087 §决策 1).
ReaderPageTable buildReaderPageTable({
  required List<ReadingChapter> chapters,
  required int firstChapter,
  required int lastChapter,
  required Map<int, String> bodies,
  required Set<int> failed,
  required Size size,
  required TextStyle bodyStyle,
  required TextStyle titleStyle,
  required double titleGap,
  required double loadingExtent,
  required TextScaler textScaler,
  required ReaderPageMeasureCache cache,
}) {
  if (chapters.isEmpty) {
    return const ReaderPageTable.empty();
  }
  final int first = firstChapter.clamp(0, chapters.length - 1);
  final int last = lastChapter.clamp(first, chapters.length - 1);
  final List<ReaderPageEntry> pages = <ReaderPageEntry>[];
  for (var index = first; index <= last; index++) {
    final ReadingChapter chapter = chapters[index];
    final String? text = bodies[index];
    final ReaderChapterMeasure measure = cache.measure(
      index: index,
      title: chapter.title,
      text: text,
      size: size,
      bodyStyle: bodyStyle,
      titleStyle: titleStyle,
      titleGap: titleGap,
      loadingExtent: loadingExtent,
      textScaler: textScaler,
    );
    for (var page = 0; page < measure.starts.length; page++) {
      pages.add(
        ReaderPageEntry(
          id: (chapterIndex: index, pageIndex: page),
          url: chapter.url,
          // 章头只属于这一章的第一页（ADR-0087 §决策 3）。
          title: page == 0 ? chapter.title : '',
          text: text,
          start: measure.starts[page],
          end: page + 1 < measure.starts.length
              ? measure.starts[page + 1]
              : (text?.length ?? 0),
          titleExtent: page == 0 ? measure.titleExtent : 0,
          bodyExtent: measure.extents[page],
          isFailed: failed.contains(index),
        ),
      );
    }
  }

  return ReaderPageTable(
    pages: pages,
    hasNextChapter: last < chapters.length - 1,
    box: size,
  );
}
