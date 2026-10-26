import 'package:flutter/material.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_group.dart';
import 'package:flutter_reader/features/bookshelf/presentation/pages/shelf_groups_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_bookshelf_repository.dart';
import '../../../../support/offline_corpus.dart';

void main() {
  group('ShelfGroupsPage', () {
    late FakeBookshelfRepository repository;

    setUp(() => repository = FakeBookshelfRepository());

    /// Pumps the page against [repository].
    Future<void> pump(WidgetTester tester) => pumpShelfPage(
      tester,
      page: const ShelfGroupsPage(),
      repository: repository,
    );

    /// The page's own strings.
    AppLocalizations l10n(WidgetTester tester) =>
        localizationOf(tester, find.byType(ShelfGroupsPage));

    testWidgets('build_givenNoGroup_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expect(find.text(l10n(tester).shelfGroupsEmpty), findsOneWidget);
    });

    testWidgets('create_whenANameIsTyped_addsTheGroup', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text(l10n(tester).shelfGroupCreate));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '仙侠');
      await tester.tap(find.text(l10n(tester).actionSave));
      await tester.pumpAndSettle();

      expect(repository.groups.single.name, '仙侠');
      expect(find.text('仙侠'), findsOneWidget);
    });

    testWidgets('create_whenTheNameIsTaken_showsTheFailureMessage', (
      WidgetTester tester,
    ) async {
      await repository.createGroup('仙侠');
      await pump(tester);

      await tester.tap(find.text(l10n(tester).shelfGroupCreate));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '仙侠');
      await tester.tap(find.text(l10n(tester).actionSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).shelfGroupNameTaken), findsOneWidget);
      expect(repository.groups, hasLength(1));
    });

    testWidgets('rename_whenANewNameIsTyped_changesIt', (
      WidgetTester tester,
    ) async {
      await repository.createGroup('仙侠');
      await pump(tester);

      await tester.tap(find.byTooltip(l10n(tester).shelfGroupRename));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '修真');
      await tester.tap(find.text(l10n(tester).actionSave));
      await tester.pumpAndSettle();

      expect(repository.groups.single.name, '修真');
    });

    testWidgets('delete_whenConfirmed_removesTheGroupButNotItsBooks', (
      WidgetTester tester,
    ) async {
      await repository.createGroup('仙侠');
      final ShelfGroup group = repository.groups.single;
      repository.seed(name: '剑来', groupId: group.id);
      await pump(tester);

      await tester.tap(find.byTooltip(l10n(tester).shelfGroupDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n(tester).actionDelete));
      await tester.pumpAndSettle();

      expect(repository.groups, isEmpty);
      // 删组不删书：书回到「未分组」（ADR-0066 §决策 2）。
      expect(repository.entries.single.groupId, isNull);
    });

    testWidgets('reorder_whenAGroupIsDragged_writesTheNewOrder', (
      WidgetTester tester,
    ) async {
      await repository.createGroup('仙侠');
      await repository.createGroup('历史');
      await pump(tester);

      // 拖动手势在 widget 测试里不稳定：直接调用回调等价于一次完成的拖拽。
      final ReorderableListView list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      final void Function(int, int)? onReorder = list.onReorderItem;
      expect(onReorder, isNotNull);
      onReorder?.call(1, 0);
      await tester.pumpAndSettle();

      expect(
        (await repository.getGroups()).map((ShelfGroup g) => g.name),
        <String>['历史', '仙侠'],
      );
    });
  });
}
