import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/features/rules/domain/entities/replace_rule_import.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/usecases/import_replace_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_rule_repository.dart';

/// The document the sample file in `~/Downloads` looks like, shrunk to three entries.
const String _document = '''
[
  {"name":"数字标题","pattern":"^第","replacement":"","scopeTitle":true,"scopeContent":false,"order":1},
  {"name":"去广告","pattern":"广告","replacement":"","isEnabled":false},
  {"name":"坏的"}
]''';

/// A use case over [repository] and a fake client, with the write log captured.
({ImportReplaceRules useCase, FakeLogPrinter printer}) _fixture(
  FakeRuleRepository repository, {
  FakeHttpClient? http,
  int sizeLimit = replaceRuleImportSizeLimitBytes,
}) {
  final FakeLogPrinter printer = FakeLogPrinter();

  return (
    useCase: ImportReplaceRules(
      repository: repository,
      http: http ?? FakeHttpClient(),
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      sizeLimit: sizeLimit,
    ),
    printer: printer,
  );
}

ReplaceRuleImportPreview _previewOf(ParseResult<ReplaceRuleImportPreview> r) =>
    switch (r) {
      ParseSuccess<ReplaceRuleImportPreview>(
        :final ReplaceRuleImportPreview data,
      ) =>
        data,
      ParseFailure<ReplaceRuleImportPreview>(:final ParseFailureKind kind) =>
        fail('the preview should succeed ($kind)'),
    };

void main() {
  group('ImportReplaceRules', () {
    test('preview_givenAnArray_answersEveryEntryWithItsSpeed', () async {
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(FakeRuleRepository());

      final ReplaceRuleImportPreview preview = _previewOf(
        await fixture.useCase.preview(const ReplaceRuleImportText(_document)),
      );

      expect(preview.entries, hasLength(3));
      expect(preview.usableCount, 2);
      expect(preview.rejectedCount, 1);
      // 只改标题的规则带着 scope 进来：预览里「输在哪」一眼可见（ADR-0071 §决策 4）。
      expect(
        (preview.entries.first.payload! as ReplacePayload).scopeTitle,
        isTrue,
      );
      expect(
        (preview.entries.first.payload! as ReplacePayload).scopeContent,
        isFalse,
      );
      expect(
        preview.entries.last.problem,
        ReplaceRuleImportProblem.missingPattern,
      );
      // 读不懂的条目记一条 warning，但不把文件内容写进日志。
      expect(
        fixture.printer.events.single.message.toString(),
        contains('index=2'),
      );
    });

    test('preview_givenAnExistingRule_flagsItAsAnUpdate', () async {
      final FakeRuleRepository repository = FakeRuleRepository()
        ..seed(
          kind: RuleKind.replace,
          name: '去广告',
          payload: const RulePayload.replace(pattern: '广告', replacement: ''),
        );
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(repository);

      final ReplaceRuleImportPreview preview = _previewOf(
        await fixture.useCase.preview(const ReplaceRuleImportText(_document)),
      );

      expect(preview.entries[1].isUpdate, isTrue);
      expect(preview.entries[0].isUpdate, isFalse);
    });

    test('preview_givenTextOverTheCap_failsBeforeParsing', () async {
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(FakeRuleRepository(), sizeLimit: 10);

      final ParseResult<ReplaceRuleImportPreview> preview = await fixture
          .useCase
          .preview(const ReplaceRuleImportText(_document));

      expect(
        preview,
        isA<ParseFailure<ReplaceRuleImportPreview>>().having(
          (ParseFailure<ReplaceRuleImportPreview> failure) => failure.rulePath,
          'rulePath',
          'rules.import.sizeLimit',
        ),
      );
    });

    test('preview_givenAUrl_downloadsItWithTheCap', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve('https://rules.test/replace.json', _document);
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(FakeRuleRepository(), http: http);

      final ReplaceRuleImportPreview preview = _previewOf(
        await fixture.useCase.preview(
          const ReplaceRuleImportUrl('https://rules.test/replace.json'),
        ),
      );

      expect(preview.usableCount, 2);
      expect(http.requestedMaxBytes.single, replaceRuleImportSizeLimitBytes);
      expect(http.requestedRulePaths.single, 'rules.import.url');
    });

    test('preview_givenAnUnreachableUrl_answersTheNetworkFailure', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(
          'https://rules.test/replace.json',
          ParseFailureKind.networkFailed,
        );
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(FakeRuleRepository(), http: http);

      final ParseResult<ReplaceRuleImportPreview> preview = await fixture
          .useCase
          .preview(
            const ReplaceRuleImportUrl('https://rules.test/replace.json'),
          );

      expect(preview, isA<ParseFailure<ReplaceRuleImportPreview>>());
    });

    test('preview_givenADownloadOverTheCap_failsBeforeParsing', () async {
      // 请求层把超限表达成 `BodyTooLargeException` 的 cause，这里必须换成导入契约的 rulePath。
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(
          'https://rules.test/huge.json',
          ParseFailureKind.networkFailed,
          cause: const BodyTooLargeException(10),
        );
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(FakeRuleRepository(), http: http);

      final ParseResult<ReplaceRuleImportPreview> preview = await fixture
          .useCase
          .preview(const ReplaceRuleImportUrl('https://rules.test/huge.json'));

      expect(
        preview,
        isA<ParseFailure<ReplaceRuleImportPreview>>().having(
          (ParseFailure<ReplaceRuleImportPreview> failure) => failure.rulePath,
          'rulePath',
          'rules.import.sizeLimit',
        ),
      );
    });

    test('inputs_givenAPastedTextAndAUrl_exposeWhatTheyCarry', () {
      // 故意不用 const：常量构造会被折叠，lcov 里那两行就没有执行点，域层 100% 门禁会失败。
      // ignore: prefer_const_constructors
      expect(ReplaceRuleImportText('json').text, 'json');
      expect(
        // ignore: prefer_const_constructors
        ReplaceRuleImportUrl('https://r.test/a.json').url,
        'https://r.test/a.json',
      );
    });

    test('report_imported_countsCreatesAndUpdates', () {
      // 页面的回执用 imported 说话：更新也是导入（ADR-0071 §决策 2）。
      expect(
        const ReplaceRuleImportReport(
          created: 2,
          updated: 3,
          skipped: 1,
        ).imported,
        5,
      );
    });

    test('preview_givenNoJson_failsTheDocument', () async {
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(FakeRuleRepository());

      expect(
        await fixture.useCase.preview(const ReplaceRuleImportText('nope')),
        isA<ParseFailure<ReplaceRuleImportPreview>>(),
      );
    });

    test('commit_givenNewEntries_createsThemInTheFileOrder', () async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      final ReplaceRuleImportPreview preview = _previewOf(
        await fixture.useCase.preview(const ReplaceRuleImportText(_document)),
      );

      final ParseResult<ReplaceRuleImportReport> report = await fixture.useCase
          .commit(preview, <int>{0, 1});

      expect(
        report,
        isA<ParseSuccess<ReplaceRuleImportReport>>().having(
          (ParseSuccess<ReplaceRuleImportReport> success) =>
              success.data.created,
          'created',
          2,
        ),
      );
      expect(repository.rows.map((Rule rule) => rule.name), <String>[
        '数字标题',
        '去广告',
      ]);
      expect(repository.rows.first.sortOrder, 1);
      // 不删除文件里没有的规则：这里本来就没有别的规则。
      expect(repository.rows, hasLength(2));
    });

    test('commit_givenAnExistingEntry_updatesInPlace', () async {
      final FakeRuleRepository repository = FakeRuleRepository()
        ..seed(
          kind: RuleKind.replace,
          name: '去广告',
          payload: const RulePayload.replace(pattern: '广告', replacement: '旧'),
          isEnabled: true,
        );
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      final ReplaceRuleImportPreview preview = _previewOf(
        await fixture.useCase.preview(const ReplaceRuleImportText(_document)),
      );

      final ParseResult<ReplaceRuleImportReport> report = await fixture.useCase
          .commit(preview, <int>{1});

      expect(
        report,
        isA<ParseSuccess<ReplaceRuleImportReport>>().having(
          (ParseSuccess<ReplaceRuleImportReport> success) =>
              success.data.updated,
          'updated',
          1,
        ),
      );
      // 文件里 isEnabled 是 false：导入以文件为准（ADR-0071 §决策 2）。
      expect(repository.rows.single.isEnabled, isFalse);
      expect(repository.rows, hasLength(1));
    });

    test('commit_givenUntickedEntries_leavesThemOut', () async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      final ReplaceRuleImportPreview preview = _previewOf(
        await fixture.useCase.preview(const ReplaceRuleImportText(_document)),
      );

      await fixture.useCase.commit(preview, <int>{});

      expect(repository.rows, isEmpty);
    });

    test('commit_givenARowDeletedSinceThePreview_createsInstead', () async {
      // 预览之后、提交之前那条规则被删了：更新一条不存在的行会变成静默无操作，
      // 所以 commit 重新读一遍库，找不到就新增。
      final FakeRuleRepository repository = FakeRuleRepository();
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      final ReplaceRuleImportPreview preview = _previewOf(
        await fixture.useCase.preview(const ReplaceRuleImportText(_document)),
      );
      expect(preview.entries[1].isUpdate, isFalse);

      final ParseResult<ReplaceRuleImportReport> report = await fixture.useCase
          .commit(preview, <int>{1});

      expect(
        report,
        isA<ParseSuccess<ReplaceRuleImportReport>>().having(
          (ParseSuccess<ReplaceRuleImportReport> success) =>
              success.data.created,
          'created',
          1,
        ),
      );
    });

    test('commit_givenARejectedEntry_skipsIt', () async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final ({ImportReplaceRules useCase, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      final ReplaceRuleImportPreview preview = _previewOf(
        await fixture.useCase.preview(const ReplaceRuleImportText(_document)),
      );

      final ParseResult<ReplaceRuleImportReport> report = await fixture.useCase
          .commit(preview, <int>{0, 1, 2});

      expect(
        report,
        isA<ParseSuccess<ReplaceRuleImportReport>>().having(
          (ParseSuccess<ReplaceRuleImportReport> success) =>
              success.data.skipped,
          'skipped',
          1,
        ),
      );
      expect(repository.rows, hasLength(2));
    });
  });
}
