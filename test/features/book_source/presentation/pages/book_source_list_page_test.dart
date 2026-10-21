import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_list_view.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_list_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_book_source_view_store.dart';
import '../../../../support/offline_corpus.dart';

/// A stored source with a distinct [name] and URL.
BookSource _source(String name, {String? url}) => loadCorpusBookSource()
    .copyWith(name: name, url: url ?? 'https://$name.test');

/// The strings the page renders, taken from the page's own localization.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(BookSourceListPage));

/// The names rendered, in the order the list shows them.
List<String> _rowOrder(WidgetTester tester, List<String> candidates) {
  final List<String> shown = <String>[];
  for (final String name in candidates) {
    if (find.text(name).evaluate().isEmpty) {
      continue;
    }
    shown.add(name);
  }
  // 以控件的 y 坐标排序：列表顺序就是视觉顺序。
  shown.sort((String left, String right) {
    final double leftY = tester.getTopLeft(find.text(left)).dy;
    final double rightY = tester.getTopLeft(find.text(right)).dy;

    return leftY.compareTo(rightY);
  });

  return shown;
}

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

      // 删除在行菜单里（5.5 起行尾是开关 + 菜单，避免四个图标挤在一行）。
      await tester.tap(find.byTooltip('first'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionDelete));
      await tester.pumpAndSettle();
      expect(find.text(l10n.bookSourceListDeleteTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, l10n.actionDelete));
      await tester.pumpAndSettle();

      expect(find.text('first'), findsNothing);
      expect(find.text(l10n.bookSourceListEmpty), findsOneWidget);
    });

    testWidgets('sort_whenTheWeightKeyIsChosen_ordersByWeight', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      repository.add(source: _source('light'), weight: 1);
      repository.add(source: _source('heavy'), weight: 9);
      final FakeBookSourceViewStore store = FakeBookSourceViewStore();

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
        viewStore: store,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.bookSourceListSortLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListSortWeight));
      await tester.pumpAndSettle();

      expect(_rowOrder(tester, <String>['heavy', 'light']), <String>[
        'heavy',
        'light',
      ]);
      // 选择被记住（ADR-0045 §决策 4）。
      expect(store.view.order, BookSourceSortOrder.weight);
    });

    testWidgets('filter_whenAGroupChipIsTapped_showsThatGroupOnly', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      repository.add(source: _source('picked'), groupName: '精选');
      repository.add(source: _source('other'), groupName: '玄幻');

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.widgetWithText(FilterChip, '精选'));
      await tester.pumpAndSettle();

      expect(find.text('picked'), findsOneWidget);
      expect(find.text('other'), findsNothing);
      expect(find.textContaining(l10n.bookSourceListGroupAll), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilterChip, l10n.bookSourceListGroupAll),
      );
      await tester.pumpAndSettle();
      expect(find.text('other'), findsOneWidget);
    });

    testWidgets('filter_givenAStoredGroupThatIsGone_showsEverySource', (
      WidgetTester tester,
    ) async {
      // 存的分组已经不存在：渲染期回落到「全部分组」，而不是给一个永远空的列表。
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      repository.add(source: _source('kept'), groupName: '精选');

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
        viewStore: FakeBookSourceViewStore(
          initial: const BookSourceListView(group: '已删除的分组'),
        ),
      );

      expect(find.text('kept'), findsOneWidget);
    });

    testWidgets('row_whenAVerdictWasWritten_showsTheFourProjectedFields', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final int id = repository
          .add(source: _source('checked'), groupName: '精选')
          .id;
      await repository.applyCheckReport(
        id: id,
        report: const SourceCheckReport(
          status: SourceCheckStatus.failed,
          invalidGroups: <String>[searchInvalidGroup],
          errorComment: searchInvalidGroup,
          elapsedMillis: 4321,
        ),
      );

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      // 分组（列投影，含校验写的「搜索失效」）、响应耗时、注释第一行都在行内。
      expect(find.textContaining(searchInvalidGroup), findsWidgets);
      expect(
        find.textContaining(l10n.bookSourceListRespondTimeLine(4321)),
        findsOneWidget,
      );
    });

    testWidgets('rowComment_whenViewed_showsTheWholeNote', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final int id = repository.add(source: _source('note')).id;
      await repository.applyCheckReport(
        id: id,
        report: const SourceCheckReport(
          status: SourceCheckStatus.failed,
          invalidGroups: <String>[searchInvalidGroup],
          errorComment: searchInvalidGroup,
          elapsedMillis: 12,
        ),
      );

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip('note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListCommentAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceListCommentTitle), findsOneWidget);
      // 行内只显示注释的第一行，对话框里是全文；这里断言对话框内那一段。
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('// Error: $searchInvalidGroup'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('list_givenTheManualOrder_isReorderable', (
      WidgetTester tester,
    ) async {
      // 只有手动序给拖拽：其它排序键下拖动会「拖了又跳回去」（ADR-0045 §决策 3）。
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      repository.add(source: _source('alpha'));
      repository.add(source: _source('beta'));
      final FakeBookSourceViewStore store = FakeBookSourceViewStore();

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
        viewStore: store,
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.byType(ReorderableListView), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.bookSourceListSortLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListSortName));
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsNothing);
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
