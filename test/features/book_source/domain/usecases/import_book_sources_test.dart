import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/features/book_source/domain/book_source_fingerprint.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_import_preview.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
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
  Future<List<StoredBookSource>> getAll({
    BookSourceSortOrder order = BookSourceSortOrder.defaultOrder,
    bool ascending = true,
  }) async => <StoredBookSource>[];

  @override
  Future<Map<int, SourceCheckRecord>> latestChecks() async =>
      <int, SourceCheckRecord>{};

  @override
  Future<void> reorder(List<int> orderedIds) async {}

  @override
  Future<StoredBookSource?> findById(int id) async => null;

  /// Identities (`url|fingerprint`) the fake reports as already stored.
  final Set<String> existingIdentities = <String>{};

  @override
  Future<bool> exists({
    required String url,
    required String fingerprint,
  }) async => existingIdentities.contains('$url|$fingerprint');

  @override
  Future<void> setEnabled({required int id, required bool isEnabled}) async {}

  @override
  Future<bool> applyCheckReport({
    required int id,
    required SourceCheckReport report,
  }) async => false;

  @override
  Future<void> delete(int id) async {}

  // 导入路径不碰这三个写口（ADR-0050）：实现成空操作，避免测试为了「能编译」而假装它们被调用。
  @override
  Future<String?> payloadOf(int id) async => null;

  @override
  Future<void> setEnabledFor(List<int> ids, {required bool isEnabled}) async {}

  @override
  Future<void> deleteMany(List<int> ids) async {}

  @override
  Future<void> setGroupFor(List<int> ids, String? group) async {}

  @override
  Future<void> setExploreEnabledFor(
    List<int> ids, {
    required bool isExploreEnabled,
  }) async {}

  @override
  Future<void> moveToEdge(List<int> ids, {required bool toTop}) async {}

  @override
  Future<void> renameGroup(String from, String to) async {}

  @override
  Future<void> deleteGroup(String group) async {}

  @override
  Future<void> removeFromGroup(List<int> ids, String group) async {}

  @override
  Future<BookSourceEditOutcome> update({
    required int id,
    required Map<String, Object?> entry,
  }) async => BookSourceEditOutcome.sourceMissing;
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

/// Returns the data of [result], failing the test when it failed.
T _success<T>(ParseResult<T> result) => switch (result) {
  ParseSuccess<T>(:final T data) => data,
  ParseFailure<T>(:final ParseFailureKind kind) => fail(
    'Expected success, got ${kind.name}.',
  ),
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

    test('execute_givenARuleBasedHeader_keepsTheRuleForTheFetch', () async {
      // 真实语料写 `header: "<js>…</js>"` / `"@js: …"`：那是**求值后**给出 header 表的规则，
      // 不是读不懂的 JSON。M12-A2 之后它被保留（`headerRule`），由取页前求值；既不丢字段，
      // 也不该再报「降级」。
      repository.inserted = 1;
      const String rule = '@js: JSON.stringify({"User-Agent": "x"})';
      final Map<String, Object?> withRuleHeader = _entry()..['header'] = rule;

      final ParseResult<BookSourceImportReport> result = await useCase()
          .execute(BookSourceImportText(jsonEncode(<Object?>[withRuleHeader])));

      expect(result.dataOrNull?.inserted, 1);
      expect(result.dataOrNull?.skipped, 0);
      // payload 逐字保留（导出保真），规则本身落在 headerRule 上。
      final Map<String, Object?> stored = repository.saved.single.single;
      expect(stored['header'], rule);
      expect(stored['bookSourceUrl'], 'https://a.test');
      expect(BookSource.fromLegadoJson(stored).headerRule, rule);
      expect(BookSource.fromLegadoJson(stored).headers, isNull);
      expect(
        printer.events
            .map((event) => event.message.toString())
            .any((String message) => message.contains('degraded field')),
        isFalse,
      );
    });

    test('execute_givenAHeaderThatIsNotAnObject_dropsTheField', () async {
      // 读不懂的 `header`（裸 UA、被截断的对象）仍然降级：字段丢掉 + warning，
      // 书源本身留下（ADR-0040 §决策 6）。
      repository.inserted = 1;
      final Map<String, Object?> bareAgent = _entry()
        ..['header'] = 'Mozilla/5.0 (not json at all)';

      final ParseResult<BookSourceImportReport> result = await useCase()
          .execute(BookSourceImportText(jsonEncode(<Object?>[bareAgent])));

      expect(result.dataOrNull?.inserted, 1);
      final Map<String, Object?> stored = repository.saved.single.single;
      expect(stored.containsKey('header'), isFalse);
      expect(
        printer.events
            .map((event) => event.message.toString())
            .any(
              (String message) =>
                  message.contains('degraded field') &&
                  message.contains('field=header'),
            ),
        isTrue,
      );
    });

    test('execute_givenAnUnknownBookSourceType_skipsTheEntry', () async {
      // 类型**不**降级：静默变成 text 会让音频/图片源以文本源的样子出现（ADR-0022 §决策 5）。
      final Map<String, Object?> unknownType = _entry()
        ..['bookSourceType'] = 99;

      final ParseResult<BookSourceImportReport> result = await useCase()
          .execute(BookSourceImportText(jsonEncode(<Object?>[unknownType])));

      expect(result.dataOrNull?.skipped, 1);
      expect(repository.saved.single, isEmpty);
      expect(
        printer.events
            .map((event) => event.message.toString())
            .any(
              (String message) =>
                  message.contains('field=bookSourceType') &&
                  message.contains('Skipping imported'),
            ),
        isTrue,
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
      'preview_givenMixedEntries_writesNothingAndExplainsEveryRejection',
      () async {
        final BookSourceImportPreview preview = _success(
          await useCase().preview(
            BookSourceImportText(
              jsonEncode(<Object?>[
                _entry(),
                // 不是对象
                42,
                // 缺 URL
                <String, Object?>{'bookSourceName': '缺 URL'},
                // 缺规则对象：模型拒绝（ADR-0022 checked 模式）
                <String, Object?>{
                  'bookSourceUrl': 'https://missing.test',
                  'bookSourceName': '缺规则',
                },
              ]),
            ),
          ),
        );

        expect(preview.entries, hasLength(4));
        expect(preview.usableCount, 1);
        expect(preview.rejectedCount, 3);
        expect(preview.newCount, 1);
        expect(preview.refreshCount, 0);
        expect(
          preview.entries[1].rejection,
          BookSourceImportRejection.notAnObject,
        );
        expect(
          preview.entries[2].rejection,
          BookSourceImportRejection.missingUrl,
        );
        expect(
          preview.entries[3].rejection,
          BookSourceImportRejection.unreadable,
        );
        // 预览一个字节都不写（ADR-0052 §决策 5）。
        expect(repository.saved, isEmpty);
      },
    );

    test('preview_givenAnExistingIdentity_marksItAsARefresh', () async {
      final Map<String, Object?> entry = _entry();
      repository.existingIdentities.add(
        '${entry['bookSourceUrl']}|${bookSourceFingerprint(entry)}',
      );

      final BookSourceImportPreview preview = _success(
        await useCase().preview(BookSourceImportText(jsonEncode(entry))),
      );

      expect(preview.entries.single.isRefresh, isTrue);
      expect(preview.refreshCount, 1);
      expect(preview.newCount, 0);
    });

    test('commit_givenASubset_storesOnlyTheTickedEntries', () async {
      final BookSourceImportPreview preview = _success(
        await useCase().preview(
          BookSourceImportText(
            jsonEncode(<Object?>[
              _entry(name: '甲', url: 'https://a.test'),
              _entry(name: '乙', url: 'https://b.test'),
            ]),
          ),
        ),
      );

      final BookSourceImportReport report = _success(
        await useCase().commit(preview, selected: <int>{1}),
      );

      expect(repository.saved, hasLength(1));
      expect(repository.saved.single.single['bookSourceUrl'], 'https://b.test');
      expect(report.inserted, repository.inserted);
      expect(report.skipped, 0);
    });

    test('commit_givenARejectedEntry_countsItAsSkipped', () async {
      final BookSourceImportPreview preview = _success(
        await useCase().preview(
          BookSourceImportText(
            jsonEncode(<Object?>[
              _entry(),
              <String, Object?>{'bookSourceName': '缺 URL'},
            ]),
          ),
        ),
      );

      final BookSourceImportReport report = _success(
        await useCase().commit(preview),
      );

      // 未勾选 ≠ 被拒绝：只有真的坏条目才进 skipped（ADR-0052 §决策 5）。
      expect(report.skipped, 1);
      expect(repository.saved.single, hasLength(1));
    });

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
