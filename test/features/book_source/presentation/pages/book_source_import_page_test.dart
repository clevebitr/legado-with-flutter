import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/book_source_file_picker.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
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

/// A [BookSourceFilePicker] double that answers whatever a test pins.
final class _FakePicker implements BookSourceFilePicker {
  _FakePicker(this._answer);

  final ParseResult<String?> _answer;

  /// The `maxBytes` caps the page asked for, in order.
  final List<int> limits = <int>[];

  @override
  Future<ParseResult<String?>> pick({required int maxBytes}) async {
    limits.add(maxBytes);

    return _answer;
  }
}

/// Confirms the preview by importing [count] ticked entries.
Future<void> _commit(
  WidgetTester tester,
  AppLocalizations l10n,
  int count,
) async {
  await tester.tap(find.text(l10n.bookSourceImportCommit(count)));
  await tester.pumpAndSettle();
}

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
      // 提交只读文件：先出预览，再确认（ADR-0052 §决策 5）。
      expect(
        find.textContaining(l10n.bookSourceImportEntryNew),
        findsOneWidget,
      );
      expect(await repository.getAll(), isEmpty);
      await _commit(tester, l10n, 1);

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
      // 被拒绝的条目也在预览里，并带着原因（不再是只出现在计数里）。
      expect(
        find.text(l10n.bookSourceImportRejectionMissingUrl),
        findsOneWidget,
      );
      await _commit(tester, l10n, 1);

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
      await _commit(tester, l10n, 1);

      expect(find.text(l10n.bookSourceImportSucceeded(1)), findsOneWidget);
      expect(http.requestedRulePaths, <String>['import.url']);
      // 上限必须真的走请求层（在读的时候生效，ADR-0040 §决策 5）。
      expect(http.requestedMaxBytes, <int?>[bookSourceImportSizeLimitBytes]);
    });

    testWidgets('file_givenAPickedFile_importsItWithTheSameCap', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final _FakePicker picker = _FakePicker(
        ParseSuccess<String?>(_corpusFile()),
      );
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceImportPage(),
        repository: repository,
        picker: picker,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceImportFileAction),
      );
      await tester.pumpAndSettle();
      await _commit(tester, l10n, 1);

      expect(find.text(l10n.bookSourceImportSucceeded(1)), findsOneWidget);
      expect(await repository.getAll(), hasLength(1));
      // 选择器拿到的上限与粘贴路径是同一个数（ADR-0040 §决策 5）。
      expect(picker.limits, <int>[bookSourceImportSizeLimitBytes]);
    });

    testWidgets('file_givenACancelledDialog_changesNothing', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceImportPage(),
        repository: repository,
        // 取消 = ParseSuccess(null)：不是失败，界面保持原样。
        picker: _FakePicker(const ParseSuccess<String?>(null)),
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceImportFileAction),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.failureInvalidBookSource), findsNothing);
      expect(find.text(l10n.bookSourceImportSucceeded(1)), findsNothing);
      expect(await repository.getAll(), isEmpty);
    });

    testWidgets('preview_givenAnExistingIdentity_labelsTheEntryAsARefresh', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      // 先导入一次，再提交同一个文件：第二次的预览必须是「将刷新」而不是「新增」。
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceImportPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);
      await _type(tester, text: _corpusFile());
      await tester.tap(find.byTooltip(l10n.actionImport));
      await tester.pumpAndSettle();
      await _commit(tester, l10n, 1);

      await _type(tester, text: _corpusFile());
      await tester.tap(find.byTooltip(l10n.actionImport));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(l10n.bookSourceImportEntryRefresh),
        findsOneWidget,
      );
      expect(find.textContaining(l10n.bookSourceImportEntryNew), findsNothing);
      // 预览阶段仍然没有写库：刷新是提交后才会发生。
      expect(await repository.getAll(), hasLength(1));
    });

    testWidgets('preview_whenAnEntryIsUnticked_isNotStored', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceImportPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);
      final Map<String, Object?> first =
          jsonDecode(_corpusFile()) as Map<String, Object?>;
      final Map<String, Object?> second = <String, Object?>{...first}
        ..['bookSourceName'] = '第二条'
        ..['bookSourceUrl'] = 'https://second.test';

      await _type(tester, text: jsonEncode(<Object?>[first, second]));
      await tester.tap(find.byTooltip(l10n.actionImport));
      await tester.pumpAndSettle();

      // 取消勾选第一条，只提交剩下的一条（ADR-0052 §决策 5）。
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await _commit(tester, l10n, 1);

      final List<StoredBookSource> rows = await repository.getAll();
      expect(rows, hasLength(1));
      expect(rows.single.source.url, 'https://second.test');
    });

    testWidgets('file_givenAnOversizedFile_showsTheInvalidSourceMessage', (
      WidgetTester tester,
    ) async {
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceImportPage(),
        repository: FakeBookSourceRepository(),
        picker: _FakePicker(
          const ParseFailure<String?>(
            kind: ParseFailureKind.invalidBookSource,
            rulePath: 'import.sizeLimit',
          ),
        ),
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceImportFileAction),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.failureInvalidBookSource), findsOneWidget);
    });
  });
}
