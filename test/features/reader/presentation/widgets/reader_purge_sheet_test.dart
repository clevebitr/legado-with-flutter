import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/repositories/purge_rule_switches.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_purge_sheet.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_log_printer.dart';

/// The book under test.
const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '剑来',
  tocUrl: 'https://source.test/book/1/toc',
);

/// In-memory [PurgeRuleSwitches] double (`docs/dev/testing.md` §4).
final class _FakeSwitches implements PurgeRuleSwitches {
  _FakeSwitches({List<PurgeRuleSwitch>? rules, this.writes = true})
    : rules =
          rules ??
          <PurgeRuleSwitch>[
            const PurgeRuleSwitch(
              id: 1,
              pattern: '请收藏本站',
              replacement: '',
              isEnabled: true,
            ),
            const PurgeRuleSwitch(id: 2, pattern: '本章未完', isEnabled: false),
          ];

  final List<PurgeRuleSwitch> rules;

  /// What `setEnabled` answers; `false` models an unbound / failed write.
  final bool writes;

  /// Every write, as `(id, enabled, bookUrl)`, for assertions.
  final List<({int id, bool enabled, String bookUrl})> calls =
      <({int id, bool enabled, String bookUrl})>[];

  @override
  Future<List<PurgeRuleSwitch>> list() async => rules;

  @override
  Future<bool> setEnabled({
    required int id,
    required bool enabled,
    required String sourceUrl,
    required String bookUrl,
  }) async {
    calls.add((id: id, enabled: enabled, bookUrl: bookUrl));

    return writes;
  }
}

/// Pumps the sheet over [switches].
Future<void> _pump(WidgetTester tester, _FakeSwitches switches) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        purgeRuleSwitchesProvider.overrideWithValue(switches),
        appLoggerProvider.overrideWithValue(
          AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReaderPurgeSheet(book: _book)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sheet_whenOpened_listsTheRulesWithTheirSwitchState', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeSwitches());
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(ReaderPurgeSheet)),
    );

    expect(find.text(l10n.readerPurgeTitle), findsOneWidget);
    expect(find.text(l10n.readerPurgeHint), findsOneWidget);
    expect(find.text('请收藏本站'), findsOneWidget);
    expect(find.text('本章未完'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isTrue,
    );
  });

  testWidgets('switch_whenToggled_writesThatRuleForThisBook', (
    WidgetTester tester,
  ) async {
    // ADR-0094 §决策 1：写的是**这本**书的缓存作用域，不是全库。
    final _FakeSwitches switches = _FakeSwitches();
    await _pump(tester, switches);

    await tester.tap(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();

    expect(switches.calls.single.id, 2);
    expect(switches.calls.single.enabled, isTrue);
    expect(switches.calls.single.bookUrl, _book.bookUrl);
  });

  testWidgets('switch_whenThePortRefuses_saysTheRuleWasNotChanged', (
    WidgetTester tester,
  ) async {
    final _FakeSwitches switches = _FakeSwitches(writes: false);
    await _pump(tester, switches);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(ReaderPurgeSheet)),
    );

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(find.text(l10n.readerPurgeFailed), findsOneWidget);
  });

  testWidgets('sheet_givenNoRules_explainsWhereToAddThem', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeSwitches(rules: <PurgeRuleSwitch>[]));
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(ReaderPurgeSheet)),
    );

    expect(find.text(l10n.readerPurgeEmpty), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });
}
