import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_source_kind.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_page.dart';
import 'package:flutter_reader/features/reader/domain/repositories/manga_page_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_source_kind_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../../support/fake_log_printer.dart';

void main() {
  group('UnboundMangaPageProvider', () {
    test('fetch_givenNoBinding_answersAnUnsupportedRuleFailure', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundMangaPageProvider port = UnboundMangaPageProvider(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<List<ReadingPage>> result = await port.fetch(
        sourceUrl: 'https://source.test',
        chapterUrl: 'https://source.test/1.html',
      );

      expect(
        result,
        isA<ParseFailure<List<ReadingPage>>>().having(
          (ParseFailure<List<ReadingPage>> failure) => failure.kind,
          'kind',
          ParseFailureKind.unsupportedRule,
        ),
      );
      expect(
        result,
        isA<ParseFailure<List<ReadingPage>>>().having(
          (ParseFailure<List<ReadingPage>> failure) => failure.rulePath,
          'rulePath',
          'reader.mangaPages',
        ),
      );
      // 未绑定的端口必须留下可观测的 warning，而不是静默返回空页（ADR-0041 §决策 2）。
      expect(
        printer.events.any(
          (LogEvent event) =>
              '${event.message}'.contains('No MangaPageProvider is bound'),
        ),
        isTrue,
      );
    });
  });

  group('UnboundReaderSourceKindProvider', () {
    test('of_givenNoBinding_answersTextWithAWarning', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundReaderSourceKindProvider port =
          UnboundReaderSourceKindProvider(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
          );

      final ParseResult<ReaderSourceKind> result = await port.of(
        'https://source.test',
      );

      expect(
        result,
        isA<ParseSuccess<ReaderSourceKind>>().having(
          (ParseSuccess<ReaderSourceKind> success) => success.data,
          'data',
          ReaderSourceKind.text,
        ),
      );
      expect(
        printer.events.any(
          (LogEvent event) => '${event.message}'.contains(
            'No ReaderSourceKindProvider is bound',
          ),
        ),
        isTrue,
      );
    });
  });
}
