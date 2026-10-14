import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_list_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/offline_corpus.dart';

/// A stored source with a distinct [name] and URL.
BookSource _source(String name, {String? url}) => loadCorpusBookSource()
    .copyWith(name: name, url: url ?? 'https://$name.test');

/// The strings the page renders, taken from the page's own localization.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(BookSourceListPage));

/// Whether the row titled [name] is the one the pages currently use.
bool _isSelected(WidgetTester tester, String name) => tester
    .widget<ListTile>(
      find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
    )
    .selected;

void main() {
  group('BookSourceListPage', () {
    testWidgets('build_givenNoStoredSource_showsTheImportGuide', (
      WidgetTester tester,
    ) async {
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: FakeBookSourceRepository(),
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.bookSourceListEmpty), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.actionImport),
        findsOneWidget,
      );
    });

    testWidgets('build_givenStoredSources_showsTheCurrentAndVariantMarkers', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        // 同 URL 的两条变体都要带「同站点的另一份规则」标记（ADR-0040 §决策 3）。
        ..add(source: _source('first', url: 'https://shared.test'))
        ..add(source: _source('variant', url: 'https://shared.test'))
        ..add(source: _source('disabled'), isEnabled: false);

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text('first'), findsOneWidget);
      expect(find.text('variant'), findsOneWidget);
      expect(find.text('disabled'), findsOneWidget);
      expect(
        find.textContaining(l10n.bookSourceVariantLabel),
        findsNWidgets(2),
      );
      // 默认选中「启用且排序第一」的那条（这里就是 first）。
      expect(_isSelected(tester, 'first'), isTrue);
      expect(_isSelected(tester, 'variant'), isFalse);
    });

    testWidgets('tap_givenAnotherRow_selectsIt', (WidgetTester tester) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('first'))
        ..add(source: _source('second'));

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );

      await tester.tap(find.text('second'));
      await tester.pumpAndSettle();

      expect(_isSelected(tester, 'second'), isTrue);
      expect(_isSelected(tester, 'first'), isFalse);
    });

    testWidgets('toggle_givenTheCurrentRow_disablesItAndKeepsItSelected', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('first'));

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect((await repository.getAll()).single.isEnabled, isFalse);
      expect(_isSelected(tester, 'first'), isTrue);
    });

    testWidgets('delete_givenTheOnlySource_returnsToTheEmptyState', (
      WidgetTester tester,
    ) async {
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: FakeBookSourceRepository()..add(source: _source('first')),
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.actionDelete));
      await tester.pumpAndSettle();
      expect(find.text(l10n.bookSourceListDeleteTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, l10n.actionDelete));
      await tester.pumpAndSettle();

      expect(find.text('first'), findsNothing);
      expect(find.text(l10n.bookSourceListEmpty), findsOneWidget);
    });

    testWidgets('load_whenTheRepositoryThrows_offersARetry', (
      WidgetTester tester,
    ) async {
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: FakeBookSourceRepository()..failReads = true,
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.bookSourceListLoadFailed), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.actionRetry),
        findsOneWidget,
      );
    });
  });
}
