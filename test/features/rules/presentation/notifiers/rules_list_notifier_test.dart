import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/rules/di.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/presentation/notifiers/rules_list_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' show Level;

import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_rule_repository.dart';

/// A container whose rules repository is [repository], with the write log captured.
({ProviderContainer container, FakeLogPrinter printer}) _fixture(
  FakeRuleRepository repository,
) {
  final FakeLogPrinter printer = FakeLogPrinter();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      ruleRepositoryProvider.overrideWith((Ref ref) async => repository),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: printer),
      ),
    ],
  );
  addTearDown(container.dispose);

  return (container: container, printer: printer);
}

void main() {
  group('RulesList', () {
    test('build_givenStoredRules_answersThemInManualOrder', () async {
      final FakeRuleRepository repository = FakeRuleRepository()
        ..seed(
          kind: RuleKind.replace,
          name: '第一',
          payload: const RulePayload.replace(pattern: 'a', replacement: ''),
        )
        ..seed(
          kind: RuleKind.replace,
          name: '第二',
          payload: const RulePayload.replace(pattern: 'b', replacement: ''),
        );
      final ({ProviderContainer container, FakeLogPrinter printer}) fixture =
          _fixture(repository);

      final List<Rule> rules = await fixture.container.read(
        rulesListProvider(RuleKind.replace).future,
      );

      expect(rules.map((Rule rule) => rule.name), <String>['第一', '第二']);
    });

    test('setEnabled_whenCalled_writesAndReloadsTheList', () async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final Rule rule = repository.seed(
        kind: RuleKind.replace,
        name: '净化',
        payload: const RulePayload.replace(pattern: 'a', replacement: ''),
      );
      final ({ProviderContainer container, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      await fixture.container.read(rulesListProvider(RuleKind.replace).future);

      await fixture.container
          .read(rulesListProvider(RuleKind.replace).notifier)
          .setEnabled(id: rule.id, isEnabled: false);

      expect(
        fixture.container
            .read(rulesListProvider(RuleKind.replace))
            .value
            ?.single
            .isEnabled,
        isFalse,
      );
    });

    test('remove_whenCalled_removesTheRowAndReloads', () async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final Rule rule = repository.seed(
        kind: RuleKind.dict,
        name: '百度汉语',
        payload: const RulePayload.dict(urlRule: 'u', showRule: 's'),
      );
      final ({ProviderContainer container, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      await fixture.container.read(rulesListProvider(RuleKind.dict).future);

      await fixture.container
          .read(rulesListProvider(RuleKind.dict).notifier)
          .remove(rule.id);

      expect(
        fixture.container.read(rulesListProvider(RuleKind.dict)).value,
        isEmpty,
      );
    });

    test('reorder_whenCalled_storesTheGivenOrder', () async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final Rule first = repository.seed(
        kind: RuleKind.replace,
        name: '第一',
        payload: const RulePayload.replace(pattern: 'a', replacement: ''),
      );
      final Rule second = repository.seed(
        kind: RuleKind.replace,
        name: '第二',
        payload: const RulePayload.replace(pattern: 'b', replacement: ''),
      );
      final ({ProviderContainer container, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      await fixture.container.read(rulesListProvider(RuleKind.replace).future);

      await fixture.container
          .read(rulesListProvider(RuleKind.replace).notifier)
          .reorder(<int>[second.id, first.id]);

      expect(repository.reorderCalls.single, <int>[second.id, first.id]);
      expect(
        fixture.container
            .read(rulesListProvider(RuleKind.replace))
            .value
            ?.map((Rule rule) => rule.name),
        <String>['第二', '第一'],
      );
    });

    test('save_givenNoId_createsARule', () async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final ({ProviderContainer container, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      await fixture.container.read(rulesListProvider(RuleKind.toc).future);

      await fixture.container
          .read(rulesListProvider(RuleKind.toc).notifier)
          .save(
            draft: const RuleDraft(
              kind: RuleKind.toc,
              name: '新目录规则',
              payload: RulePayload.toc(rule: '^第.+章'),
            ),
          );

      final List<Rule> rules = fixture.container
          .read(rulesListProvider(RuleKind.toc))
          .value!;
      expect(rules.single.name, '新目录规则');
      expect(rules.single.isBuiltIn, isFalse);
    });

    test('save_givenAnId_editsInPlaceAndKeepsTheBuiltInFlag', () async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final Rule stored = repository.seed(
        kind: RuleKind.toc,
        name: '内置',
        payload: const RulePayload.toc(rule: '^第'),
        isBuiltIn: true,
      );
      final ({ProviderContainer container, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      await fixture.container.read(rulesListProvider(RuleKind.toc).future);

      await fixture.container
          .read(rulesListProvider(RuleKind.toc).notifier)
          .save(
            id: stored.id,
            draft: const RuleDraft(
              kind: RuleKind.toc,
              name: '改过的',
              payload: RulePayload.toc(rule: '^章'),
            ),
          );

      final Rule saved = fixture.container
          .read(rulesListProvider(RuleKind.toc))
          .value!
          .single;
      expect(saved.name, '改过的');
      expect(saved.isBuiltIn, isTrue);
      expect(saved.isEnabled, isTrue);
    });

    test('save_givenAnIdThatIsGone_doesNothing', () async {
      // 行在别的路径上被删了：不新建一条，也不把列表变成错误态。
      final FakeRuleRepository repository = FakeRuleRepository();
      final ({ProviderContainer container, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      await fixture.container.read(rulesListProvider(RuleKind.dict).future);

      await fixture.container
          .read(rulesListProvider(RuleKind.dict).notifier)
          .save(
            id: 4242,
            draft: const RuleDraft(
              kind: RuleKind.dict,
              name: '幽灵',
              payload: RulePayload.dict(urlRule: 'u', showRule: 's'),
            ),
          );

      expect(
        fixture.container.read(rulesListProvider(RuleKind.dict)).value,
        isEmpty,
      );
    });

    test('remove_givenAFailingWrite_keepsTheListAndLogs', () async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final Rule rule = repository.seed(
        kind: RuleKind.replace,
        name: '净化',
        payload: const RulePayload.replace(pattern: 'a', replacement: ''),
      );
      final ({ProviderContainer container, FakeLogPrinter printer}) fixture =
          _fixture(repository);
      await fixture.container.read(rulesListProvider(RuleKind.replace).future);
      repository.failWith = Exception('database is gone');

      await fixture.container
          .read(rulesListProvider(RuleKind.replace).notifier)
          .remove(rule.id);

      // 写失败意味着行还在表里：列表照旧才是诚实的视图（C-ERR-2 的 presentation 兜底）。
      expect(
        fixture.container.read(rulesListProvider(RuleKind.replace)).value,
        hasLength(1),
      );
      expect(fixture.printer.events.last.level, Level.warning);
    });
  });
}
