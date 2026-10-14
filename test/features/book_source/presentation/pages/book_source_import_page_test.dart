import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_import_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/offline_corpus.dart';

/// The corpus book source as an import file (a real export, sanitized).
String _corpusFile() =>
    File('test/fixtures/book_sources/legado_default_rules_source.json')
        .readAsStringSync();

/// The strings the page renders, taken from the page's own localization.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(BookSourceImportPage));

/// Types `text` into the first field, or `url` into the second one.
Future<void> _type(WidgetTester tester, {String? text, String? url}) async {
  final Finder field = find.byType(TextField);
  await tester.enterText(
    text != null ? field.first : field.last,
    text ?? url ?? '',
  );
  await tester.pumpAndSettle();
}

void main() {
  group('BookSourceImportPage', () {
    testWidgets('submit_givenPastedJson_storesItAndShowsTheSummary', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceImportPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      await _type(tester, text: _corpusFile());
      await tester.tap(find.byTooltip(l10n.actionImport));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceImportSucceeded(1)), findsOneWidget);
      expect(await repository.getAll(), hasLength(1));
    });

    testWidgets('submit_givenAValidAndAnInvalidEntry_reportsBothCounts', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceImportPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);
      final Map<String, Object?> valid =
          jsonDecode(_corpusFile()) as Map<String, Object?>;

      // 第二条缺 bookSourceUrl：跳过并计数（ADR-0040 §决策 6），文件本身仍然成功。
      await _type(
        tester,
        text: jsonEncode(<Object?>[
          valid,
          <String, Object?>{'bookSourceName': '缺 URL'},
        ]),
      );
      await tester.tap(find.byTooltip(l10n.actionImport));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.bookSourceImportPartiallySkipped(1, 1)),
        findsOneWidget,
      );
      expect(await repository.getAll(), hasLength(1));
    });

    testWidgets('submit_givenBrokenJson_showsTheInvalidSourceMessage', (
      WidgetTester tester,
    ) async {
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceImportPage(),
        repository: FakeBookSourceRepository(),
      );
      final AppLocalizations l10n = _l10n(tester);

      await _type(tester, text: '{not json');
      await tester.tap(find.byTooltip(l10n.actionImport));
      await tester.pumpAndSettle();

      expect(find.text(l10n.failureInvalidBookSource), findsOneWidget);
      // 失败也给重试路径（C-UI-6 的可达性：不能只有一个死胡同提示）。
      expect(
        find.widgetWithText(FilledButton, l10n.actionRetry),
        findsOneWidget,
      );
    });

    testWidgets('submit_givenAUrl_downloadsItWithTheImportCap', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final FakeHttpClient http = FakeHttpClient()
        ..serve('https://sources.test/all.json', _corpusFile());
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceImportPage(),
        repository: repository,
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);

      await _type(tester, url: 'https://sources.test/all.json');
      await tester.tap(find.byTooltip(l10n.actionImport));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceImportSucceeded(1)), findsOneWidget);
      expect(http.requestedRulePaths, <String>['import.url']);
      // 上限必须真的走请求层（在读的时候生效，ADR-0040 §决策 5）。
      expect(http.requestedMaxBytes, <int?>[bookSourceImportSizeLimitBytes]);
    });
  });
}
