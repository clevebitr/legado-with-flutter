import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_log_printer.dart';

/// In-memory [BookSourceRepository] double: records what the use case asked to store and answers
/// with the counts a test pins (`docs/dev/testing.md` §4).
final class _FakeRepository implements BookSourceRepository {
  /// Every `saveAll` call, in order.
  final List<List<Map<String, Object?>>> saved = <List<Map<String, Object?>>>[];

  /// Counts the fake answers with.
  int inserted = 0;

  /// Counts the fake answers with.
  int refreshed = 0;

  @override
  Future<BookSourceSaveReport> saveAll(
    List<Map<String, Object?>> entries,
  ) async {
    saved.add(entries);

    return BookSourceSaveReport(inserted: inserted, refreshed: refreshed);
  }

  @override
  Future<List<StoredBookSource>> getAll() async => <StoredBookSource>[];

  @override
  Future<StoredBookSource?> findById(int id) async => null;

  @override
  Future<void> setEnabled({required int id, required bool isEnabled}) async {}

  @override
  Future<void> delete(int id) async {}
}

/// One valid book source object.
Map<String, Object?> _entry({
  String name = '示例书源',
  String url = 'https://a.test',
}) => <String, Object?>{
  'bookSourceName': name,
  'bookSourceUrl': url,
  'ruleSearch': <String, Object?>{'bookList': 'class.item'},
  'ruleToc': <String, Object?>{'chapterList': 'class.c'},
  'ruleContent': <String, Object?>{'content': 'class.body'},
};

/// Returns the failure of [result], failing the test when it succeeded.
ParseFailure<Never> _failure<T>(ParseResult<T> result) => switch (result) {
  ParseFailure<T>(:final ParseFailureKind kind, :final String rulePath) =>
    ParseFailure<Never>(kind: kind, rulePath: rulePath),
  ParseSuccess<T>() => fail('Expected a failure.'),
};

void main() {
  group('ImportBookSources', () {
    late _FakeRepository repository;
    late FakeHttpClient http;
    late FakeLogPrinter printer;

    ImportBookSources useCase({
      int sizeLimit = bookSourceImportSizeLimitBytes,
    }) => ImportBookSources(
      repository: repository,
      http: http,
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      sizeLimit: sizeLimit,
    );

    setUp(() {
      repository = _FakeRepository();
      http = FakeHttpClient();
      printer = FakeLogPrinter();
    });

    test(
      'execute_givenValidText_storesEveryEntryAndReportsTheCounts',
      () async {
        repository
          ..inserted = 1
          ..refreshed = 2;

        final ParseResult<BookSourceImportReport> result = await useCase()
            .execute(
              BookSourceImportText(
                jsonEncode(<Object?>[_entry(), _entry(url: 'https://b.test')]),
              ),
            );

        expect(result.dataOrNull?.inserted, 1);
        expect(result.dataOrNull?.refreshed, 2);
        expect(result.dataOrNull?.skipped, 0);
        // 汇总文案的 count 是「新增 + 刷新」——重复导入的刷新对用户也是一次成功（ADR-0040 §决策 8）。
        expect(result.dataOrNull?.imported, 3);
        expect(repository.saved.single, hasLength(2));
      },
    );

    test('execute_givenASingleObject_storesIt', () async {
      // 单条导出与批量导出的顶层形状不同，两者都是合法文件（ADR-0040 §决策 6）。
      final ParseResult<BookSourceImportReport> result = await useCase()
          .execute(BookSourceImportText(jsonEncode(_entry())));

      expect(result.dataOrNull, isNotNull);
      expect(repository.saved.single.single['bookSourceUrl'], 'https://a.test');
    });

    test(
      'execute_givenTextLongerThanTheLimit_failsBeforeParsingAnything',
      () async {
        final ParseResult<BookSourceImportReport> result = await useCase(
          sizeLimit: 8,
        ).execute(const BookSourceImportText('0123456789'));

        final ParseFailure<Never> failure = _failure(result);
        expect(failure.kind, ParseFailureKind.invalidBookSource);
        expect(failure.rulePath, 'import.sizeLimit');
        // 解析之前就拒绝：仓储一次都没被调用。
        expect(repository.saved, isEmpty);
      },
    );

    test(
      'execute_givenMultibyteTextOverTheByteLimit_failsBeforeParsing',
      () async {
        // 「中文中文」是 4 个字符、12 个字节：第一个判据不成立，按 UTF-8 字节的判据成立。
        final ParseResult<BookSourceImportReport> result = await useCase(
          sizeLimit: 4,
        ).execute(const BookSourceImportText('中文中文'));

        final ParseFailure<Never> failure = _failure(result);
        expect(failure.kind, ParseFailureKind.invalidBookSource);
        expect(failure.rulePath, 'import.sizeLimit');
        expect(repository.saved, isEmpty);
      },
    );

    test('execute_givenBrokenJson_failsWithTheNotJsonMarker', () async {
      final ParseFailure<Never> failure = _failure(
        await useCase().execute(const BookSourceImportText('{not json')),
      );

      expect(failure.kind, ParseFailureKind.invalidBookSource);
      expect(failure.rulePath, 'import.notJson');
    });

    test('execute_givenAnEmptyArray_failsWithTheNoEntriesMarker', () async {
      final ParseFailure<Never> failure = _failure(
        await useCase().execute(const BookSourceImportText('[]')),
      );

      expect(failure.kind, ParseFailureKind.invalidBookSource);
      expect(failure.rulePath, 'import.noEntries');
    });

    test('execute_givenUnusableEntries_skipsThemAndLogsWhere', () async {
      final ParseResult<BookSourceImportReport> result = await useCase()
          .execute(
            BookSourceImportText(
              jsonEncode(<Object?>[
                _entry(),
                'not an object',
                <String, Object?>{
                  'bookSourceName': '缺 URL',
                  'ruleToc': <String, Object?>{},
                },
                <String, Object?>{'bookSourceUrl': 'https://c.test'},
                <String, Object?>{
                  'bookSourceName': '缺规则',
                  'bookSourceUrl': 'https://d.test',
                },
              ]),
            ),
          );

      expect(result.dataOrNull?.skipped, 4);
      // 只有那一条合法条目进了仓储（跳过是显式失败 + 汇总，不是静默丢弃）。
      expect(repository.saved.single, hasLength(1));
      final List<String> messages = printer.events
          .map((event) => event.message.toString())
          .toList();
      expect(
        messages.any((String message) => message.contains('index=1')),
        isTrue,
      );
      expect(
        messages.any(
          (String message) => message.contains('field=bookSourceUrl'),
        ),
        isTrue,
      );
      expect(
        messages.any(
          (String message) => message.contains('field=bookSourceName'),
        ),
        isTrue,
      );
      expect(
        messages.any((String message) => message.contains('field=ruleSearch')),
        isTrue,
      );
      // 日志带定位信息，但绝不带条目正文（C-ERR-8 / C-SEC-4）。
      expect(
        messages.any((String message) => message.contains('class.item')),
        isFalse,
      );
      expect(
        messages.any((String message) => message.contains('class.body')),
        isFalse,
      );
    });

    test('execute_givenAnUrl_downloadsWithTheCallersCap', () async {
      http.serve(
        'https://sources.test/all.json',
        jsonEncode(<Object?>[_entry()]),
      );

      final ParseResult<BookSourceImportReport> result = await useCase(
        sizeLimit: 4096,
      ).execute(const BookSourceImportUrl('https://sources.test/all.json'));

      expect(result.dataOrNull, isNotNull);
      expect(http.requestedUrls, <String>['https://sources.test/all.json']);
      expect(http.requestedRulePaths, <String>['import.url']);
      // 上限必须真的交给请求层（在读的时候生效），而不是等读完再判（C-PERF-5）。
      expect(http.requestedMaxBytes, <int?>[4096]);
    });

    test(
      'execute_givenADownloadThatExceededTheCap_failsWithTheSizeLimitMarker',
      () async {
        http.failWith(
          'https://sources.test/huge.json',
          ParseFailureKind.invalidBookSource,
          cause: const BodyTooLargeException(4096),
        );

        final ParseFailure<Never> failure = _failure(
          await useCase().execute(
            const BookSourceImportUrl('https://sources.test/huge.json'),
          ),
        );

        expect(failure.kind, ParseFailureKind.invalidBookSource);
        expect(failure.rulePath, 'import.sizeLimit');
      },
    );

    test(
      'execute_givenADownloadThatFailed_reportsTheTransportFailure',
      () async {
        http.failWith(
          'https://sources.test/gone.json',
          ParseFailureKind.notFound,
        );

        final ParseFailure<Never> failure = _failure(
          await useCase().execute(
            const BookSourceImportUrl('https://sources.test/gone.json'),
          ),
        );

        expect(failure.kind, ParseFailureKind.notFound);
        expect(failure.rulePath, 'import.url');
      },
    );
  });
}
