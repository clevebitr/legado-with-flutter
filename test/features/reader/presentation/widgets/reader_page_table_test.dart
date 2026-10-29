import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/reader_page_table_fixture.dart';

/// Three chapters: enough to tell "the last one in the window" from "the last one in the book".
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章 开端', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章 继续', url: 'https://source.test/2.html'),
  ReadingChapter(title: '第3章 收束', url: 'https://source.test/3.html'),
];

void main() {
  group('buildReaderPageTable', () {
    test('buildReaderPageTable_givenALongChapter_splitsItIntoPages', () {
      final ReaderPageTable table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: testReaderBody('第一章')},
      );

      final List<ReaderPageEntry> first = table.pages
          .where((ReaderPageEntry page) => page.id.chapterIndex == 0)
          .toList();
      expect(first.length, greaterThan(1));
      // 页的切片首尾相接：前一页的 end 就是后一页的 start，中间不丢字也不重叠。
      for (var index = 1; index < first.length; index++) {
        expect(first[index].start, first[index - 1].end);
      }
      expect(first.first.start, 0);
      expect(first.last.end, testReaderBody('第一章').length);
    });

    test(
      'buildReaderPageTable_givenAChapterHeading_keepsItOnTheFirstPageOnly',
      () {
        final ReaderPageTable table = buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{0: testReaderBody('第一章')},
        );

        final List<ReaderPageEntry> first = table.pages
            .where((ReaderPageEntry page) => page.id.chapterIndex == 0)
            .toList();
        // 章头属于这一章的第一页，并且这一页的正文要让出它的高度（ADR-0087 §决策 3）。
        expect(first.first.title, '第1章 开端');
        expect(first.first.titleExtent, greaterThan(0));
        expect(
          first.skip(1).every((ReaderPageEntry page) => page.title.isEmpty),
          isTrue,
        );
        expect(
          first.skip(1).every((ReaderPageEntry page) => page.titleExtent == 0),
          isTrue,
        );
      },
    );

    test('buildReaderPageTable_givenAMissingBody_pagesItAsOneLoadingPage', () {
      final ReaderPageTable table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: '第一章正文'},
        failed: <int>{1},
      );

      final List<ReaderPageEntry> second = table.pages
          .where((ReaderPageEntry page) => page.id.chapterIndex == 1)
          .toList();
      // 正文没到手也是**一页**（不是零页）：章界始终差一次翻页/一次滑动。
      expect(second, hasLength(1));
      expect(second.single.isPlaceholder, isTrue);
      expect(second.single.title, '第2章 继续');
      expect(second.single.bodyExtent, testReaderLoadingExtent);
      expect(second.single.isFailed, isTrue);
    });

    test('buildReaderPageTable_givenTwoChaptersSharingAUrl_keepsBothPages', () {
      final ReaderPageTable table = buildTestPageTable(
        chapters: const <ReadingChapter>[
          ReadingChapter(title: '第1章', url: 'https://source.test/same.html'),
          ReadingChapter(title: '第2章', url: 'https://source.test/same.html'),
        ],
        // 同一份地址的正文按章节下标各给一份，页表也因此各有各的页。
        bodies: <int, String>{0: '同一份正文', 1: '同一份正文'},
      );

      expect(
        table.pages.map((ReaderPageEntry page) => page.id.chapterIndex),
        <int>[0, 1],
      );
      expect(table.pages.map((ReaderPageEntry page) => page.title), <String>[
        '第1章',
        '第2章',
      ]);
    });

    test('buildReaderPageTable_givenEmptyChapters_answersAnEmptyTable', () {
      final ReaderPageTable table = buildTestPageTable(
        chapters: const <ReadingChapter>[],
        bodies: const <int, String>{},
      );

      expect(table.isEmpty, isTrue);
      expect(table.totalExtent, 0);
      expect(table.positionAt(0), isNull);
      expect(table.offsetOf(0, 0), isNull);
    });

    test('buildReaderPageTable_givenTheLastChapter_marksTheBookAsEnded', () {
      final ReaderPageTable last = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{2: '第三章正文'},
        anchorIndex: 2,
      );
      final ReaderPageTable notLast = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: '第一章正文'},
      );

      // 窗口的最后一页是全书最后一页才算读完（锚点章之后还有章，就还能继续往下接）。
      expect(last.hasNextChapter, isFalse);
      expect(notLast.hasNextChapter, isTrue);
    });
  });

  group('ReaderPageTable positions', () {
    test('positionAt_givenAnOffsetInAPage_answersTheChapterAndOffset', () {
      final ReaderPageTable table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: testReaderBody('第一章')},
      );

      final ({int chapterIndex, int charOffset})? start = table.positionAt(0);
      expect(start, isNotNull);
      expect(start?.chapterIndex, 0);
      // 视口顶在内容坐标 0：章头之下才是正文，所以字符偏移从 0 起。
      expect(start?.charOffset, 0);

      final ReaderPageEntry first = table.pages.first;
      final ({int chapterIndex, int charOffset})? inside = table.positionAt(
        table.tops.first + first.titleExtent + first.bodyExtent / 2,
      );
      expect(inside?.chapterIndex, 0);
      expect(inside?.charOffset, greaterThan(0));
    });

    test('offsetOf_givenAChapterAndOffset_answersTheSamePlaceBack', () {
      final ReaderPageTable table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{
          0: testReaderBody('第一章'),
          1: testReaderBody('第二章'),
        },
      );

      for (final int charOffset in <int>[0, 120, 400]) {
        final double? offset = table.offsetOf(0, charOffset);
        expect(offset, isNotNull, reason: 'chapter 0 offset $charOffset');
        final ({int chapterIndex, int charOffset})? back = table.positionAt(
          offset ?? 0,
        );
        expect(back?.chapterIndex, 0);
        // 偏移是估算（字符与像素之间按比例换算），允许一行的误差。
        expect((back?.charOffset ?? 0) - charOffset, closeTo(0, 60));
      }
    });

    test('indexOfChapter_givenAnOffsetPastTheChapter_answersItsLastPage', () {
      final ReaderPageTable table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{
          0: testReaderBody('第一章'),
          1: testReaderBody('第二章'),
        },
      );

      // 存档里的偏移可能比现在还长的这一章更靠后：落在本章最后一页，而不是掉进下一章。
      final int index = table.indexOfChapter(0, 1 << 30);
      final ReaderPageEntry page = table.pages[index];
      expect(page.id.chapterIndex, 0);
      expect(page.id.pageIndex, greaterThan(0));
      expect(index + 1 < table.pages.length, isTrue);
      expect(table.pages[index + 1].id.chapterIndex, 1);
    });

    test('indexOfChapter_givenAChapterOutsideTheWindow_answersMinusOne', () {
      final ReaderPageTable table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: '第一章正文'},
        firstChapter: 0,
        lastChapter: 0,
      );

      expect(table.indexOfChapter(1, 0), -1);
      expect(table.offsetOf(1, 0), isNull);
    });

    test('indexAt_givenAnOffsetPastTheEnd_answersTheLastPage', () {
      final ReaderPageTable table = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: '第一章正文'},
      );

      expect(table.indexAt(table.totalExtent * 2), table.length - 1);
      expect(table.indexAt(-100), 0);
    });
  });

  group('ReaderPageMeasureCache', () {
    test('measure_givenTheSameBox_answersTheSameMeasurement', () {
      final ReaderPageMeasureCache cache = ReaderPageMeasureCache();
      final ReaderPageTable first = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: testReaderBody('第一章')},
        cache: cache,
      );
      final ReaderPageTable second = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: testReaderBody('第一章')},
        cache: cache,
      );

      // 同一份正文、同一个盒子：页表逐页一样（测量没有重新算，也没有漂移）。
      expect(second.signature, first.signature);
      expect(second.tops, first.tops);
    });

    test('measure_givenADifferentTextScale_measuresAgain', () {
      final ReaderPageMeasureCache cache = ReaderPageMeasureCache();
      final ReaderPageTable plain = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: testReaderBody('第一章')},
        cache: cache,
      );
      final ReaderPageTable scaled = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: testReaderBody('第一章')},
        textScaler: const TextScaler.linear(2),
        cache: cache,
      );

      expect(scaled.totalExtent, greaterThan(plain.totalExtent));
    });

    test('retain_givenFewerChapters_forgetsTheRest', () {
      final ReaderPageMeasureCache cache = ReaderPageMeasureCache();
      buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{
          0: testReaderBody('第一章'),
          1: testReaderBody('第二章'),
        },
        cache: cache,
      );

      cache.retain(<int>[0]);
      final ReaderPageTable rebuilt = buildTestPageTable(
        chapters: _chapters,
        bodies: <int, String>{0: testReaderBody('第一章')},
        cache: cache,
      );

      // 只留下第 0 章后，第 1 章的测量被丢掉：再问一次就是「没有正文」的一页。
      expect(rebuilt.pages.last.id.chapterIndex, 1);
      expect(rebuilt.pages.last.isPlaceholder, isTrue);

      cache.clear();
      expect(
        buildTestPageTable(
          chapters: _chapters,
          bodies: <int, String>{},
          cache: cache,
        ).totalExtent,
        greaterThan(0),
      );
    });
  });
}
