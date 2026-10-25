import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/router/app_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_log_printer.dart';

void main() {
  group('UnboundAppNavigation', () {
    test('openBookshelf_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      // 没有 context 也要能调用「无操作」这一半：它不碰 Navigator，只写一行日志。
      navigation.openBookshelf(_FakeContext());

      expect(printer.events, hasLength(1));
      expect(printer.events.single.message, contains('bookshelf'));
    });

    test('openSettings_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openSettings(_FakeContext());

      expect(printer.events.single.message, contains('settings'));
    });

    test('openBookSources_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openBookSources(_FakeContext());

      expect(printer.events.single.message, contains('book-source'));
    });

    test('openAbout_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openAbout(_FakeContext());

      expect(printer.events.single.message, contains('about'));
    });

    test('openBookmarks_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openBookmarks(_FakeContext());

      expect(printer.events.single.message, contains('bookmark'));
    });

    test('openReadingRecords_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openReadingRecords(_FakeContext());

      expect(printer.events.single.message, contains('reading-record'));
    });

    test('openReplaceRules_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openReplaceRules(_FakeContext());

      expect(printer.events.single.message, contains('replace-rule'));
    });

    test('openTocRules_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openTocRules(_FakeContext());

      expect(printer.events.single.message, contains('toc-rule'));
    });

    test('openDictRules_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openDictRules(_FakeContext());

      expect(printer.events.single.message, contains('dict-rule'));
    });

    test('openHighlightRules_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openHighlightRules(_FakeContext());

      expect(printer.events.single.message, contains('highlight-rule'));
    });

    test('openBookReadingRecords_whenCalled_logsAndDoesNothing', () {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openBookReadingRecords(
        _FakeContext(),
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        bookName: '剑来',
      );

      expect(printer.events.single.message, contains('book reading-record'));
    });

    test('openReader_whenCalled_logsAndDoesNothing', () {
      // ADR-0042 §决策 2：打开阅读器也是这个端口，未绑定时同样只是一条 warning。
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundAppNavigation navigation = UnboundAppNavigation(
        warn: AppLogger(level: LogLevel.debug, printer: printer).warning,
      );

      navigation.openReader(
        _FakeContext(),
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        bookName: '剑来',
        tocUrl: 'https://source.test/book/1/toc',
      );

      expect(printer.events.single.message, contains('reader'));
    });
  });

  group('appNavigation', () {
    test('build_whenNothingIsBound_answersTheUnboundPort', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appLoggerProvider.overrideWithValue(
            AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(appNavigationProvider),
        isA<UnboundAppNavigation>(),
      );
    });
  });
}

/// A build context that no navigation may touch.
///
/// The unbound port must not read from it; passing a real one would drag in a
/// `MaterialApp` for no reason.
final class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('the unbound port must not use its context');
}
