import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/search_results_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_log_printer.dart';
import '../../../../support/offline_corpus.dart';

void main() {
  group('SearchResultsNotifier', () {
    test(
      'search_givenACollaboratorThatThrowsException_degradesInsteadOfHanging',
      () async {
        // 用例按 C-ERR-1 只返回 ParseResult；这条测试证明契约被破坏时状态能退出 loading。
        final FakeHttpClient http = FakeHttpClient()
          ..throwOn(corpusSearchUrl, Exception('broken collaborator'));
        final FakeLogPrinter printer = FakeLogPrinter();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            httpClientProvider.overrideWithValue(http),
            appLoggerProvider.overrideWithValue(
              AppLogger(level: LogLevel.debug, printer: printer),
            ),
          ],
        );
        addTearDown(container.dispose);

        final SearchResultsNotifier notifier = container.read(
          searchResultsProvider.notifier,
        );
        final Future<void> search = notifier.search(
          loadCorpusBookSource(),
          corpusKeyword,
        );

        expect(
          container.read(searchResultsProvider),
          isA<SearchResultsSearching>(),
        );

        await search;

        final SearchResultsState state = container.read(searchResultsProvider);
        expect(state, isA<SearchResultsFailed>());
        expect(
          (state as SearchResultsFailed).kind,
          ParseFailureKind.parseFailed,
        );
      },
    );

    test(
      'search_givenACollaboratorThatThrows_logsTheSourceWithoutKeyword',
      () async {
        // C-ERR-8：失败日志带书源 ID，但搜索关键词不进日志（ADR-0006 §5）。
        final FakeHttpClient http = FakeHttpClient()
          ..throwOn(corpusSearchUrl, Exception('broken collaborator'));
        final FakeLogPrinter printer = FakeLogPrinter();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            httpClientProvider.overrideWithValue(http),
            appLoggerProvider.overrideWithValue(
              AppLogger(level: LogLevel.debug, printer: printer),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(searchResultsProvider.notifier)
            .search(loadCorpusBookSource(), corpusKeyword);

        expect(printer.events, hasLength(1));
        expect(printer.events.single.level, Level.error);
        expect(printer.events.single.message, contains('example-novel.test'));
        expect(printer.events.single.message, isNot(contains(corpusKeyword)));
      },
    );
  });
}
