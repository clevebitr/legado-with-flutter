import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/rules/di.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/presentation/pages/rule_edit_page.dart';
import 'package:flutter_reader/features/rules/presentation/rules_route.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_rule_repository.dart';

/// Pumps the form for [kind] (editing [ruleId] when given) above a page one can pop back to.
Future<void> _pump(
  WidgetTester tester,
  FakeRuleRepository repository, {
  RuleKind kind = RuleKind.replace,
  int? ruleId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ruleRepositoryProvider.overrideWith((Ref ref) async => repository),
        appLoggerProvider.overrideWithValue(AppLogger()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => switch (settings.arguments) {
            final RulesEditRoute route => RuleEditPage(
              kind: route.kind,
              ruleId: route.ruleId,
            ),
            _ => const SizedBox.shrink(),
          },
        ),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => pushRulesRoute(
                  context,
                  RulesRoute.edit(kind: kind, ruleId: ruleId),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The form's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(RuleEditPage)));

/// Fills one labelled field of the form.
Future<void> _fill(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await tester.pump();
}

/// Presses 保存 — scrolling it into view first, since the form is taller than the test viewport.
Future<void> _save(WidgetTester tester, AppLocalizations l10n) async {
  final Finder button = find.widgetWithText(FilledButton, l10n.actionSave);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('RuleEditPage', () {
    testWidgets('save_givenAValidPurgeRule_storesItAndClosesTheForm', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository();
      await _pump(tester, repository);
      final AppLocalizations l10n = _l10n(tester);

      await _fill(tester, l10n.rulesNameLabel, '去广告');
      await _fill(tester, l10n.rulesPatternLabel, '广告\\d+');
      await _fill(tester, l10n.rulesReplacementLabel, '');
      await _save(tester, l10n);

      final Rule stored = repository.rows.single;
      expect(stored.name, '去广告');
      expect(stored.kind, RuleKind.replace);
      expect(
        stored.payload,
        const RulePayload.replace(pattern: '广告\\d+', replacement: ''),
      );
      // 保存后回到上一页，而不是留在一张已经写过的表上。
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('save_givenNoName_showsTheRequiredMessageAndWritesNothing', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository();
      await _pump(tester, repository);
      final AppLocalizations l10n = _l10n(tester);

      await _fill(tester, l10n.rulesPatternLabel, 'a');
      await _save(tester, l10n);

      expect(find.text(l10n.rulesRequired), findsOneWidget);
      expect(repository.rows, isEmpty);
    });

    testWidgets('save_givenABrokenExpression_showsTheRegexMessage', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository();
      await _pump(tester, repository);
      final AppLocalizations l10n = _l10n(tester);

      await _fill(tester, l10n.rulesNameLabel, '坏正则');
      await _fill(tester, l10n.rulesPatternLabel, '(');
      await _save(tester, l10n);

      expect(find.text(l10n.rulesInvalidRegex), findsOneWidget);
      expect(repository.rows, isEmpty);
    });

    testWidgets('save_givenPlainTextMatching_acceptsAnyPattern', (
      WidgetTester tester,
    ) async {
      // 关掉正则之后 `( ` 只是普通文本，不该被正则校验拦下。
      final FakeRuleRepository repository = FakeRuleRepository();
      await _pump(tester, repository);
      final AppLocalizations l10n = _l10n(tester);

      await _fill(tester, l10n.rulesNameLabel, '字面量');
      await _fill(tester, l10n.rulesPatternLabel, '(');
      await tester.tap(find.text(l10n.rulesIsRegexLabel));
      await tester.pump();
      await _save(tester, l10n);

      expect(
        (repository.rows.single.payload as ReplacePayload).isRegex,
        isFalse,
      );
    });

    testWidgets('save_givenAnEditedRule_keepsTheFieldsTheFormDoesNotOwn', (
      WidgetTester tester,
    ) async {
      // `timeoutMs` 与未知键（`excludeScope`）不在表单里，但一次编辑不能把它们丢掉。
      final FakeRuleRepository repository = FakeRuleRepository();
      final Rule stored = repository.seed(
        kind: RuleKind.replace,
        name: '旧的',
        payload: const RulePayload.replace(
          pattern: 'a',
          replacement: 'b',
          timeoutMs: 3000,
          extra: <String, Object?>{'excludeScope': '@js:true'},
        ),
        isBuiltIn: true,
      );
      await _pump(tester, repository, ruleId: stored.id);
      final AppLocalizations l10n = _l10n(tester);

      await _fill(tester, l10n.rulesNameLabel, '新的');
      await _save(tester, l10n);

      final ReplacePayload saved =
          repository.rows.single.payload as ReplacePayload;
      expect(repository.rows.single.name, '新的');
      expect(saved.timeoutMs, 3000);
      expect(saved.extra, <String, Object?>{'excludeScope': '@js:true'});
      expect(repository.rows.single.isBuiltIn, isTrue);
    });

    testWidgets(
      'build_givenAnUnreadablePayload_showsItRawAndLetsItBeReplaced',
      (WidgetTester tester) async {
        final FakeRuleRepository repository = FakeRuleRepository();
        final Rule stored = repository.seed(
          kind: RuleKind.replace,
          name: '坏规则',
          payload: const RulePayload.malformed(raw: '{"pattern":42}'),
        );
        await _pump(tester, repository, ruleId: stored.id);
        final AppLocalizations l10n = _l10n(tester);

        expect(find.text(l10n.rulesBrokenNotice), findsOneWidget);
        expect(find.text('{"pattern":42}'), findsOneWidget);

        await _fill(tester, l10n.rulesPatternLabel, '好规则');
        await _save(tester, l10n);

        expect(
          repository.rows.single.payload,
          const RulePayload.replace(pattern: '好规则', replacement: ''),
        );
      },
    );

    testWidgets('build_givenARuleThatIsGone_explainsItInsteadOfAnEmptyForm', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FakeRuleRepository(), ruleId: 4242);

      expect(find.text(_l10n(tester).rulesGone), findsOneWidget);
    });

    testWidgets('save_givenATocRule_storesRuleAndSerialNumber', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository();
      await _pump(tester, repository, kind: RuleKind.toc);
      final AppLocalizations l10n = _l10n(tester);

      await _fill(tester, l10n.rulesNameLabel, '目录');
      await _fill(tester, l10n.rulesRuleLabel, '^第.+章');
      await _fill(tester, l10n.rulesSerialNumberLabel, '2');
      await _save(tester, l10n);

      expect(
        repository.rows.single.payload,
        const RulePayload.toc(rule: '^第.+章', serialNumber: 2),
      );
    });

    testWidgets('save_givenADictRule_storesBothExpressions', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository();
      await _pump(tester, repository, kind: RuleKind.dict);
      final AppLocalizations l10n = _l10n(tester);

      await _fill(tester, l10n.rulesNameLabel, '词典');
      await _fill(tester, l10n.rulesUrlRuleLabel, 'https://d.test/?q={{key}}');
      await _fill(tester, l10n.rulesShowRuleLabel, 'tag.body@all');
      await _save(tester, l10n);

      expect(
        repository.rows.single.payload,
        const RulePayload.dict(
          urlRule: 'https://d.test/?q={{key}}',
          showRule: 'tag.body@all',
        ),
      );
    });

    testWidgets('save_givenAHighlightRule_rejectsAMalformedColour', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository();
      await _pump(tester, repository, kind: RuleKind.highlight);
      final AppLocalizations l10n = _l10n(tester);

      await _fill(tester, l10n.rulesNameLabel, '标签');
      await _fill(tester, l10n.rulesPatternLabel, '第.章');
      await _fill(tester, l10n.rulesColorLabel, 'red');
      await _save(tester, l10n);

      expect(find.text(l10n.rulesInvalidColor), findsOneWidget);
      expect(repository.rows, isEmpty);

      await _fill(tester, l10n.rulesColorLabel, '#80FF0000');
      await _save(tester, l10n);

      expect(
        repository.rows.single.payload,
        const RulePayload.highlight(pattern: '第.章', colorHex: '#80FF0000'),
      );
    });
  });
}
