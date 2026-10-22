import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/reader/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_track_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_log_printer.dart';

void main() {
  group('UnboundAudioTrackProvider', () {
    test('fetch_whenNothingBound_failsWithTheUnsupportedRule', () async {
      // 忘了绑定端口时必须是可重试的失败态，而不是异常（ADR-0041 §决策 2）。
      final FakeLogPrinter printer = FakeLogPrinter();
      final ParseResult<List<ReaderAudioTrack>> result =
          await UnboundAudioTrackProvider(
            logger: AppLogger(level: LogLevel.debug, printer: printer),
          ).fetch(
            sourceUrl: 'https://source.test',
            chapterUrl: 'https://source.test/1.html',
          );

      expect(
        result,
        isA<ParseFailure<List<ReaderAudioTrack>>>()
            .having(
              (ParseFailure<List<ReaderAudioTrack>> failure) => failure.kind,
              'kind',
              ParseFailureKind.unsupportedRule,
            )
            .having(
              (ParseFailure<List<ReaderAudioTrack>> failure) =>
                  failure.rulePath,
              'rulePath',
              'reader.audioTracks',
            ),
      );
      expect(printer.events, isNotEmpty);
    });
  });
}
