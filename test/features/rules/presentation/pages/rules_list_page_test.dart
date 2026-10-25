import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/json_file_saver.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/rules/di.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/presentation/pages/rule_edit_page.dart';
import 'package:flutter_reader/features/rules/presentation/pages/rules_list_page.dart';
import 'package:flutter_reader/features/rules/presentation/rules_route.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_rule_repository.dart';

/// Pumps the list page of [kind] over [repository].
///
/// The pushed route is built here instead of coming from `app.dart`: the page table lives in the
/// composition root (ADR-0011), and a test only has to prove **which** typed route the page opened.
Future<void> _pump(
  WidgetTester tester,
  FakeRuleRepository repository, {
  RuleKind kind = RuleKind.replace,
  JsonFileSaver? saver,
  void Function(Object? arguments)? onPush,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ruleRepositoryProvider.overrideWith((Ref ref) async => repository),
        appLoggerProvider.overrideWithValue(AppLogger()),
        jsonFileSaverProvider.overrideWithValue(
          saver ?? const UnsupportedJsonFileSaver(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        onGenerateRoute: (RouteSettings settings) {
          onPush?.call(settings.arguments);

          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) => switch (settings.arguments) {
              final RulesEditRoute route => RuleEditPage(
                kind: route.kind,
                ruleId: route.ruleId,
              ),
              _ => const SizedBox.shrink(),
            },
          );
        },
        home: RulesListPage(kind: kind),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(RulesListPage)));

void main() {
  group('RulesListPage', () {
    testWidgets('build_givenNoRule_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FakeRuleRepository());

      expect(find.text(_l10n(tester).rulesEmpty), findsOneWidget);
    });

    testWidgets('build_givenAnUnreadableList_showsTheFailureState', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        FakeRuleRepository()..readFailure = Exception('database is gone'),
      );

      // 「读不出来」不能显示成「一条规则也没有」，否则用户会以为规则被删光了。
      expect(find.text(_l10n(tester).rulesLoadFailed), findsOneWidget);
    });

    testWidgets('build_givenARule_showsItsNameSummaryAndBuiltInBadge', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        FakeRuleRepository()..seed(
          kind: RuleKind.replace,
          name: '去广告',
          payload: const RulePayload.replace(pattern: '广告', replacement: ''),
          isBuiltIn: true,
        ),
      );

      expect(find.text('去广告'), findsOneWidget);
      expect(
        find.textContaining('广告 → '),
        findsOneWidget,
        reason: '净化规则的摘要读作 pattern → replacement',
      );
      expect(find.textContaining(_l10n(tester).rulesBuiltIn), findsOneWidget);
    });

    testWidgets('build_givenAnUnreadablePayload_marksTheRowAsBroken', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        FakeRuleRepository()..seed(
          kind: RuleKind.replace,
          name: '坏规则',
          payload: const RulePayload.malformed(raw: '{oops'),
        ),
      );

      expect(find.textContaining(_l10n(tester).rulesBroken), findsOneWidget);
    });

    testWidgets('switch_whenToggled_storesTheNewValue', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository()
        ..seed(
          kind: RuleKind.replace,
          name: '净化',
          payload: const RulePayload.replace(pattern: 'a', replacement: ''),
        );
      await _pump(tester, repository);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(repository.rows.single.isEnabled, isFalse);
    });

    testWidgets('delete_whenPressed_removesTheRow', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository()
        ..seed(
          kind: RuleKind.replace,
          name: '净化',
          payload: const RulePayload.replace(pattern: 'a', replacement: ''),
        );
      await _pump(tester, repository);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(repository.rows, isEmpty);
      expect(find.text(_l10n(tester).rulesEmpty), findsOneWidget);
    });

    testWidgets('tap_whenAddIsPressed_opensAnEmptyForm', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FakeRuleRepository());

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add rule'));
      await tester.pumpAndSettle();

      final RuleEditPage page = tester.widget<RuleEditPage>(
        find.byType(RuleEditPage),
      );
      expect(page.kind, RuleKind.replace);
      expect(page.ruleId, isNull);
    });

    testWidgets('menu_whenOpened_offersImportAndExport', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FakeRuleRepository());
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.rulesListMenu));
      await tester.pumpAndSettle();

      expect(find.text(l10n.actionImport), findsOneWidget);
      expect(find.text(l10n.rulesExportAction), findsOneWidget);
    });

    testWidgets('menu_whenImportIsChosen_opensTheImportRoute', (
      WidgetTester tester,
    ) async {
      // 四类规则里只有净化有上游交换格式：入口挂在净化列表上（ADR-0071 §决策 2）。
      final List<Object?> pushed = <Object?>[];
      await _pump(tester, FakeRuleRepository(), onPush: pushed.add);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.rulesListMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionImport));
      await tester.pumpAndSettle();

      expect(pushed.single, isA<RulesImportRoute>());
    });

    testWidgets('export_whenChosen_writesTheUpstreamDocument', (
      WidgetTester tester,
    ) async {
      final _RecordingSaver saver = _RecordingSaver();
      await _pump(
        tester,
        FakeRuleRepository()..seed(
          kind: RuleKind.replace,
          name: '去广告',
          payload: const RulePayload.replace(pattern: '广告', replacement: ''),
        ),
        saver: saver,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.rulesListMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.rulesExportAction));
      await tester.pumpAndSettle();

      expect(saver.savedName, 'replaceRules-1.json');
      // 缩进过的上游数组（ADR-0071 §决策 1）：人也能读，上游也能导入。
      expect(saver.savedContents, contains('"pattern": "广告"'));
      expect(find.text(l10n.rulesExportSaved(1)), findsOneWidget);
    });

    testWidgets('export_givenNoRule_saysThereIsNothingToExport', (
      WidgetTester tester,
    ) async {
      final _RecordingSaver saver = _RecordingSaver();
      await _pump(tester, FakeRuleRepository(), saver: saver);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.rulesListMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.rulesExportAction));
      await tester.pumpAndSettle();

      expect(saver.savedContents, isNull);
      expect(find.text(l10n.rulesExportEmpty), findsOneWidget);
    });

    testWidgets('tap_whenARowIsChosen_opensThatRule', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository();
      final int id = repository
          .seed(
            kind: RuleKind.replace,
            name: '净化',
            payload: const RulePayload.replace(pattern: 'a', replacement: ''),
          )
          .id;
      await _pump(tester, repository);

      await tester.tap(find.text('净化'));
      await tester.pumpAndSettle();

      expect(tester.widget<RuleEditPage>(find.byType(RuleEditPage)).ruleId, id);
    });
  });
}

/// A saver that records what the page asked to write.
final class _RecordingSaver implements JsonFileSaver {
  String? savedName;
  String? savedContents;

  @override
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required String contents,
  }) async {
    savedName = suggestedName;
    savedContents = contents;

    return const ParseSuccess<bool>(true);
  }
}
