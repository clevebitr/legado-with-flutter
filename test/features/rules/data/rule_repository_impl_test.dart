import 'package:drift/native.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/core/storage/rule_dao.dart' show RuleDao;
import 'package:flutter_reader/features/rules/data/rule_repository_impl.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/repositories/chapter_body_invalidator.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_seed_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' show Level;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_clock.dart';
import '../../../support/fake_log_printer.dart';

/// A [RuleSeedLoader] answering a fixed result.
final class _FixedSeeds implements RuleSeedLoader {
  const _FixedSeeds(this._result);

  final ParseResult<List<RuleDraft>> _result;

  @override
  Future<ParseResult<List<RuleDraft>>> load() async => _result;
}

/// A [ChapterBodyInvalidator] that counts its calls.
final class _CountingInvalidator implements ChapterBodyInvalidator {
  int calls = 0;

  @override
  Future<void> invalidateChapterBodies() async => calls++;
}

const List<RuleDraft> _seeds = <RuleDraft>[
  RuleDraft(
    kind: RuleKind.toc,
    name: '目录(去空白)',
    isBuiltIn: true,
    payload: RulePayload.toc(rule: '^第.+章'),
  ),
  RuleDraft(
    kind: RuleKind.dict,
    name: '百度汉语',
    isBuiltIn: true,
    payload: RulePayload.dict(
      urlRule: 'https://dict.baidu.com/s?wd={{key}}',
      showRule: 'tag.body@all',
    ),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReaderDatabase database;
  late RuleDao dao;
  late PreferenceStore preferences;
  late _CountingInvalidator invalidator;
  late FakeLogPrinter printer;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = PreferenceStore(await SharedPreferences.getInstance());
    database = ReaderDatabase(NativeDatabase.memory());
    dao = RuleDao(database);
    invalidator = _CountingInvalidator();
    printer = FakeLogPrinter();
  });

  tearDown(() => database.close());

  RuleRepositoryImpl repository({RuleSeedLoader? seeds}) => RuleRepositoryImpl(
    dao: dao,
    seeds: seeds ?? const _FixedSeeds(ParseSuccess<List<RuleDraft>>(_seeds)),
    preferences: preferences,
    invalidator: invalidator,
    clock: FakeClock(start: DateTime.utc(2026, 10, 24)),
    logger: AppLogger(level: LogLevel.debug, printer: printer),
  );

  group('RuleRepositoryImpl seeding', () {
    test('ofKind_givenAFreshInstall_seedsBothBundledKinds', () async {
      final RuleRepositoryImpl repository = RuleRepositoryImpl(
        dao: dao,
        seeds: const _FixedSeeds(ParseSuccess<List<RuleDraft>>(_seeds)),
        preferences: preferences,
        invalidator: invalidator,
        clock: FakeClock(start: DateTime.utc(2026, 10, 24)),
        logger: AppLogger(printer: printer),
      );

      final List<Rule> toc = await repository.ofKind(RuleKind.toc);

      expect(toc.single.name, '目录(去空白)');
      expect(toc.single.isBuiltIn, isTrue);
      expect((await repository.ofKind(RuleKind.dict)).single.name, '百度汉语');
      // 净化与高亮没有随包数据（ADR-0070 增补 §5）：列表就是空的。
      expect(await repository.ofKind(RuleKind.replace), isEmpty);
    });

    test('ofKind_givenTheSeededFlag_doesNotSeedAgain', () async {
      // 用户把内置规则全删了也不该复活：标记落在 preferences 里，与表空不空无关。
      await preferences.writeBool('rules.builtInSeeded', true);
      final RuleRepositoryImpl repository = RuleRepositoryImpl(
        dao: dao,
        seeds: const _FixedSeeds(ParseSuccess<List<RuleDraft>>(_seeds)),
        preferences: preferences,
        invalidator: invalidator,
        clock: FakeClock(start: DateTime.utc(2026, 10, 24)),
        logger: AppLogger(printer: printer),
      );

      expect(await repository.ofKind(RuleKind.toc), isEmpty);
    });

    test('ofKind_givenAKindThatAlreadyHasRows_doesNotOverwriteIt', () async {
      await dao.insert(
        kind: RuleKind.toc.value,
        name: '我自己的目录规则',
        payload: <String, Object?>{'rule': '^章'},
      );
      await preferences.writeBool('rules.builtInSeeded', false);

      final List<Rule> toc = await repository().ofKind(RuleKind.toc);

      expect(toc, hasLength(1));
      expect(toc.single.name, '我自己的目录规则');
      // 另一类仍然是空的，所以照样播种；标记最后才写。
      expect((await repository().ofKind(RuleKind.dict)).single.name, '百度汉语');
    });

    test('ofKind_givenUnreadableSeeds_warnsAndKeepsTheListEmpty', () async {
      final RuleRepositoryImpl repository = RuleRepositoryImpl(
        dao: dao,
        seeds: const _FixedSeeds(
          ParseFailure<List<RuleDraft>>(
            kind: ParseFailureKind.parseFailed,
            rulePath: 'rules.seed',
          ),
        ),
        preferences: preferences,
        invalidator: invalidator,
        clock: FakeClock(start: DateTime.utc(2026, 10, 24)),
        logger: AppLogger(printer: printer),
      );

      expect(await repository.ofKind(RuleKind.toc), isEmpty);
      expect(printer.events.first.level, Level.warning);
      // 标记没写：下次启动还能再试。
      expect(preferences.readBool('rules.builtInSeeded'), isNull);
    });
  });

  group('RuleRepositoryImpl reads', () {
    test('ofKind_givenABrokenPayload_keepsTheRowAsMalformed', () async {
      await preferences.writeBool('rules.builtInSeeded', true);
      await dao.insert(
        kind: RuleKind.replace.value,
        name: '坏规则',
        payload: const <String, Object?>{},
      );
      final int id = (await dao.ofKind(RuleKind.replace.value)).single.id;
      await dao.updateRow(id, payload: <String, Object?>{'oops': 1});

      final Rule rule = (await repository().ofKind(RuleKind.replace)).single;

      // 读不懂的 payload 不静默丢弃：列表里仍有一条「规则损坏」，用户可以删或改（ADR-0070 §决策 1）。
      expect(rule.payload, isA<MalformedPayload>());
      expect(rule.name, '坏规则');
      expect(printer.events, isNotEmpty);
    });

    test('ofKind_givenSeveralRows_answersThemInManualOrder', () async {
      await preferences.writeBool('rules.builtInSeeded', true);
      await dao.insert(
        kind: RuleKind.replace.value,
        name: '第一',
        payload: <String, Object?>{'pattern': 'a', 'replacement': ''},
      );
      await dao.insert(
        kind: RuleKind.replace.value,
        name: '第二',
        payload: <String, Object?>{'pattern': 'b', 'replacement': ''},
      );

      expect(
        (await repository().ofKind(RuleKind.replace))
            .map((Rule rule) => rule.name),
        <String>['第一', '第二'],
      );
    });
  });

  group('RuleRepositoryImpl writes', () {
    test('create_givenAReplaceDraft_retiresTheCachedBodies', () async {
      // 净化规则一改，缓存里的成品正文就过期了（ADR-0070 增补 §7）。
      await repository().create(
        const RuleDraft(
          kind: RuleKind.replace,
          name: '去广告',
          payload: RulePayload.replace(pattern: '广告', replacement: ''),
        ),
      );

      expect(invalidator.calls, 1);
      expect((await repository().ofKind(RuleKind.replace)).single.name, '去广告');
    });

    test('create_givenATocDraft_leavesTheChapterCacheAlone', () async {
      await repository().create(
        const RuleDraft(
          kind: RuleKind.toc,
          name: '目录',
          payload: RulePayload.toc(rule: '^章'),
        ),
      );

      expect(invalidator.calls, 0);
    });

    test('save_givenAValidRule_writesItsEditableFields', () async {
      await repository().create(
        const RuleDraft(
          kind: RuleKind.replace,
          name: '旧名',
          payload: RulePayload.replace(pattern: 'a', replacement: 'b'),
        ),
      );
      final Rule stored = (await repository().ofKind(RuleKind.replace)).single;

      await repository().save(
        stored.copyWith(
          name: '新名',
          isEnabled: false,
          payload: const RulePayload.replace(
            pattern: 'c',
            replacement: 'd',
            isRegex: false,
          ),
        ),
      );

      final Rule saved = (await repository().ofKind(RuleKind.replace)).single;
      expect(saved.name, '新名');
      expect(saved.isEnabled, isFalse);
      expect(saved.payload, isA<ReplacePayload>());
      expect((saved.payload as ReplacePayload).pattern, 'c');
      expect(invalidator.calls, 2);
    });

    test('save_givenAPayloadOfAnotherKind_throws', () async {
      await repository().create(
        const RuleDraft(
          kind: RuleKind.replace,
          name: '净化',
          payload: RulePayload.replace(pattern: 'a', replacement: 'b'),
        ),
      );
      final Rule stored = (await repository().ofKind(RuleKind.replace)).single;

      // kind 不是可编辑字段：把字典 payload 写进净化行会让列表说谎，属调用方的编程错误。
      await expectLater(
        repository().save(
          stored.copyWith(payload: const RulePayload.toc(rule: '^章')),
        ),
        throwsArgumentError,
      );
    });

    test('setEnabled_givenAReplaceRule_retiresTheCachedBodies', () async {
      await repository().create(
        const RuleDraft(
          kind: RuleKind.replace,
          name: '净化',
          payload: RulePayload.replace(pattern: 'a', replacement: 'b'),
        ),
      );
      final Rule stored = (await repository().ofKind(RuleKind.replace)).single;

      await repository().setEnabled(id: stored.id, isEnabled: false);

      expect(
        (await repository().ofKind(RuleKind.replace)).single.isEnabled,
        isFalse,
      );
      expect(invalidator.calls, 2);
    });

    test(
      'setEnabled_givenAMissingRow_writesNothingAndInvalidatesNothing',
      () async {
        await repository().setEnabled(id: 4242, isEnabled: false);

        expect(invalidator.calls, 0);
      },
    );

    test(
      'reorder_givenANewOrder_renumbersTheKindAndRetiresTheBodies',
      () async {
        // 顺序对净化是有意义的（从上到下依次跑），所以重排同样作废已缓存的成品正文。
        await repository().create(
          const RuleDraft(
            kind: RuleKind.replace,
            name: '第一',
            payload: RulePayload.replace(pattern: 'a', replacement: ''),
          ),
        );
        await repository().create(
          const RuleDraft(
            kind: RuleKind.replace,
            name: '第二',
            payload: RulePayload.replace(pattern: 'b', replacement: ''),
          ),
        );
        final List<Rule> stored = await repository().ofKind(RuleKind.replace);

        await repository().reorder(
          kind: RuleKind.replace,
          orderedIds: <int>[stored.last.id, stored.first.id],
        );

        expect(
          (await repository().ofKind(RuleKind.replace))
              .map((Rule rule) => rule.name),
          <String>['第二', '第一'],
        );
        expect(invalidator.calls, 3);
      },
    );

    test('reorder_givenATocKind_leavesTheChapterCacheAlone', () async {
      await repository().reorder(kind: RuleKind.toc, orderedIds: const <int>[]);

      expect(invalidator.calls, 0);
    });

    test(
      'delete_givenAReplaceRule_removesItAndRetiresTheCachedBodies',
      () async {
        await repository().create(
          const RuleDraft(
            kind: RuleKind.replace,
            name: '净化',
            payload: RulePayload.replace(pattern: 'a', replacement: 'b'),
          ),
        );
        final Rule stored = (await repository().ofKind(RuleKind.replace))
            .single;

        await repository().delete(stored.id);

        expect(await repository().ofKind(RuleKind.replace), isEmpty);
        expect(invalidator.calls, 2);
      },
    );

    test('delete_givenAMissingRow_doesNothing', () async {
      await repository().delete(4242);

      expect(invalidator.calls, 0);
    });
  });
}
