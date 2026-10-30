import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';

/// The body style the reader flows are measured and painted with in tests.
const TextStyle testReaderBodyStyle = TextStyle(fontSize: 16, height: 1.5);

/// The chapter-heading style the reader flows are measured and painted with in tests.
const TextStyle testReaderTitleStyle = TextStyle(fontSize: 20, height: 1.2);

/// The space between a chapter heading and its body in tests.
const double testReaderTitleGap = 24;

/// The height that stands in for a chapter body that has not arrived, in tests.
const double testReaderLoadingExtent = 72;

/// The content box the test viewport leaves after the reader's 16dp page margin.
const Size testReaderContentBox = Size(368, 568);

/// Builds a page table exactly the way the reader page does, for the flows' tests.
///
/// The window defaults to the anchor's neighbours (`anchor - 1 .. anchor + 1`) so a case only has to
/// name the anchor unless it is exercising the window itself.
ReaderPageTable buildTestPageTable({
  required List<ReadingChapter> chapters,
  required Map<int, String> bodies,
  int anchorIndex = 0,
  int? firstChapter,
  int? lastChapter,
  Set<int> failed = const <int>{},
  Size size = testReaderContentBox,
  TextScaler textScaler = TextScaler.noScaling,
  ReaderPageMeasureCache? cache,
}) {
  final int anchor = chapters.isEmpty
      ? 0
      : anchorIndex.clamp(0, chapters.length - 1);
  final int windowFirst = chapters.isEmpty
      ? 0
      : (anchor - 1).clamp(0, chapters.length - 1);
  final int windowLast = chapters.isEmpty
      ? 0
      : (anchor + 1).clamp(0, chapters.length - 1);

  return buildReaderPageTable(
    chapters: chapters,
    firstChapter: firstChapter ?? windowFirst,
    lastChapter: lastChapter ?? windowLast,
    bodies: bodies,
    failed: failed,
    size: size,
    bodyStyle: testReaderBodyStyle,
    titleStyle: testReaderTitleStyle,
    titleGap: testReaderTitleGap,
    loadingExtent: testReaderLoadingExtent,
    textScaler: textScaler,
    cache: cache ?? ReaderPageMeasureCache(),
  );
}

/// A body of [lines] lines, long enough to need several pages at the size the cases use.
String testReaderBody(String label, {int lines = 40}) => <String>[
  for (var index = 0; index < lines; index++) '$label 第${index + 1}行：正文内容。',
].join('\n');
