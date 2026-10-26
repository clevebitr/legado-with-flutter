import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/json_file_picker.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/rules/di.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/presentation/pages/rules_import_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_rule_repository.dart';

/// A [JsonFilePicker] answering the same text every time.
final class _FakePicker implements JsonFilePicker {
  _FakePicker(this.text);

  final String? text;

  @override
  Future<ParseResult<String?>> pick({required int maxBytes}) async =>
      ParseSuccess<String?>(text);
}

const String _document = '''
[
  {"name":"数字标题","pattern":"^第","replacement":"","scopeTitle":true,"scopeContent":false},
  {"name":"去广告","pattern":"广告","replacement":""},
  {"name":"坏的"}
]''';

/// Pumps the import page over [repository].
Future<void> _pump(
  WidgetTester tester,
  FakeRuleRepository repository, {
  JsonFilePicker? picker,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ruleRepositoryProvider.overrideWith((Ref ref) async => repository),
        jsonFilePickerProvider.overrideWithValue(
          picker ?? _FakePicker(_document),
        ),
        appLoggerProvider.overrideWithValue(AppLogger()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const RulesImportPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(RulesImportPage)));

/// Submits [text] through the paste field.
Future<void> _submit(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump();
  await tester.tap(find.byTooltip(_l10n(tester).actionImport));
  await tester.pumpAndSettle();
}

void main() {
  group('RulesImportPage', () {
    testWidgets('build_givenNothingSubmitted_showsTheForm', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FakeRuleRepository());
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.rulesImportTextLabel), findsOneWidget);
      expect(find.text(l10n.rulesImportUrlLabel), findsOneWidget);
      expect(find.text(l10n.rulesImportFileAction), findsOneWidget);
    });

    testWidgets('submit_givenAFile_previewsEveryEntryIncludingTheBadOne', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FakeRuleRepository());
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.text(l10n.rulesImportFileAction));
      await tester.pumpAndSettle();

      expect(find.text('数字标题'), findsOneWidget);
      expect(find.text('去广告'), findsOneWidget);
      // 读不懂的条目留在列表里、带着原因，并且不可勾选（ADR-0052 §决策 5）。
      expect(
        find.textContaining(l10n.rulesImportProblemMissingPattern),
        findsOneWidget,
      );
      expect(find.text(l10n.rulesImportSelected(2, 2)), findsOneWidget);
      // 只改标题的规则在预览里就说清楚，免得导完发现正文没变。
      expect(find.textContaining(l10n.rulesScopeTitle), findsOneWidget);
    });

    testWidgets('commit_givenTheTickedEntries_writesThemAndReports', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository();
      await _pump(tester, repository);
      final AppLocalizations l10n = _l10n(tester);
      await tester.tap(find.text(l10n.rulesImportFileAction));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.rulesImportCommit(2)));
      await tester.pumpAndSettle();

      expect(repository.rows, hasLength(2));
      expect(
        find.text(l10n.rulesImportSucceededWithSkipped(2, 0, 1)),
        findsOneWidget,
      );
    });

    testWidgets('commit_givenEverythingUnticked_writesNothing', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository();
      await _pump(tester, repository);
      final AppLocalizations l10n = _l10n(tester);
      await tester.tap(find.text(l10n.rulesImportFileAction));
      await tester.pumpAndSettle();

      // 「全部导入」取消勾选后提交按钮没有可提交的东西。
      await tester.tap(find.text(l10n.rulesImportSelectAll));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.rulesImportCommit(0)),
            )
            .onPressed,
        isNull,
      );
      expect(repository.rows, isEmpty);
    });

    testWidgets('submit_givenTextThatIsNotJson_showsTheFailure', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FakeRuleRepository());

      await _submit(tester, 'not json');

      expect(find.text(_l10n(tester).failureParseFailed), findsOneWidget);
    });

    testWidgets('submit_givenAnExistingRule_marksItAsAnUpdate', (
      WidgetTester tester,
    ) async {
      final FakeRuleRepository repository = FakeRuleRepository()
        ..seed(
          kind: RuleKind.replace,
          name: '去广告',
          payload: const RulePayload.replace(pattern: '广告', replacement: ''),
        );
      await _pump(tester, repository);

      await _submit(tester, _document);

      expect(
        find.textContaining(_l10n(tester).rulesImportUpdate),
        findsOneWidget,
      );
    });
  });
}
