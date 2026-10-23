import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_log_printer.dart';

void main() {
  group('UnboundChapterListProvider', () {
    test('fetch_whenNothingIsBound_answersUnsupportedAndWarns', () async {
      // ADR-0041 §决策 2：未绑定的端口必须是**可观测的失败**，不是启动崩溃。
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundChapterListProvider provider = UnboundChapterListProvider(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<List<ReadingChapter>> result = await provider.fetch(
        sourceUrl: 'https://source.test',
        tocUrl: 'https://source.test/toc',
      );

      final ParseFailure<List<ReadingChapter>> failure =
          result as ParseFailure<List<ReadingChapter>>;
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      // rulePath 被钉住：失败必须能定位（C-SRC-8）。
      expect(failure.rulePath, 'reader.chapterList');
      expect(
        printer.events.single.message.toString(),
        contains('No ChapterListProvider is bound'),
      );
    });
  });

  group('UnboundChapterContentProvider', () {
    test('fetch_whenNothingIsBound_answersUnsupportedAndWarns', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundChapterContentProvider provider =
          UnboundChapterContentProvider(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
          );

      final ParseResult<String> result = await provider.fetch(
        sourceUrl: 'https://source.test',
        chapterUrl: 'https://source.test/1.html',
      );

      final ParseFailure<String> failure = result as ParseFailure<String>;
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'reader.chapterContent');
      expect(
        printer.events.single.message.toString(),
        contains('No ChapterContentProvider is bound'),
      );
    });
  });

  group('UnboundReadingProgressStore', () {
    test('read_whenNothingIsBound_answersNull', () async {
      // 忘了绑定不能让用户读不了书：读进度回落成「从第一章开始」。
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundReadingProgressStore store = UnboundReadingProgressStore(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      expect(
        await store.read(
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/1',
        ),
        isNull,
      );
      expect(
        printer.events.single.message.toString(),
        contains('restarts at the first chapter'),
      );
    });

    test('write_whenNothingIsBound_isANoOpThatWarns', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundReadingProgressStore store = UnboundReadingProgressStore(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      await store.write(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        position: const ReadingPosition(
          chapterUrl: 'https://source.test/1.html',
        ),
      );

      expect(
        printer.events.single.message.toString(),
        contains('was not saved'),
      );
    });
  });
}
