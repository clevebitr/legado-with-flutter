import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/json_file_saver.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_list_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/offline_corpus.dart';

/// A source with [name] and an optional user group.
BookSource _source(String name, {String? group, String? url}) =>
    loadCorpusBookSource().copyWith(
      name: name,
      url: url ?? 'https://$name.test',
      group: group,
    );

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(BookSourceListPage));

/// Seeds two sources and pumps the page.
Future<FakeBookSourceRepository> _pump(
  WidgetTester tester, {
  JsonFileSaver? saver,
}) async {
  final FakeBookSourceRepository repository = FakeBookSourceRepository()
    ..add(source: _source('甲', group: '精选'))
    ..add(source: _source('乙', group: '玄幻'));

  await pumpSourceManagementPage(
    tester,
    page: const BookSourceListPage(),
    repository: repository,
    saver: saver,
  );

  return repository;
}

void main() {
  group('BookSourceListPage search', () {
    testWidgets('search_givenAName_filtersTheRows', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), '乙');
      await tester.pumpAndSettle();

      expect(find.text('乙'), findsWidgets);
      expect(find.text('甲'), findsNothing);
    });

    testWidgets('search_givenAGroup_filtersTheRows', (
      WidgetTester tester,
    ) async {
      // 搜索也认分组：用户分组在 payload 里（ADR-0050 §决策 1）。
      await _pump(tester);

      await tester.enterText(find.byType(TextField), '精选');
      await tester.pumpAndSettle();

      expect(find.text('甲'), findsWidgets);
      expect(find.text('乙'), findsNothing);
    });
  });

  group('BookSourceListPage selection', () {
    testWidgets('selection_whenARowIsLongPressed_offersTheBatchActions', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.longPress(find.text('甲'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceListSelectedCount(1)), findsOneWidget);
      expect(find.text(l10n.bookSourceListBatchEnable), findsOneWidget);
      expect(find.text(l10n.bookSourceListBatchDisable), findsOneWidget);
      expect(find.text(l10n.bookSourceListBatchDelete), findsOneWidget);
    });

    testWidgets('selection_whenDisableIsChosen_disablesEverySelectedRow', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = await _pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.longPress(find.text('甲'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.select_all));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListBatchDisable));
      await tester.pumpAndSettle();

      // 一个事务写完两行（ADR-0050 §决策 2），选择模式随之退出。
      final List<StoredBookSource> rows = await repository.getAll();
      expect(rows.every((StoredBookSource row) => !row.isEnabled), isTrue);
      expect(find.text(l10n.bookSourceListTitle), findsOneWidget);
    });

    testWidgets('selection_whenDeleteIsConfirmed_removesEverySelectedRow', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = await _pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.longPress(find.text('甲'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.select_all));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListBatchDelete));
      await tester.pumpAndSettle();
      // 确认对话框里的同名按钮。
      await tester.tap(find.text(l10n.bookSourceListBatchDelete).last);
      await tester.pumpAndSettle();

      expect(await repository.getAll(), isEmpty);
    });

    testWidgets('selection_whenInvertIsChosen_flipsTheTicks', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.longPress(find.text('甲'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.flip_to_back));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceListSelectedCount(1)), findsOneWidget);
      expect(find.text('乙'), findsOneWidget);
    });
  });

  group('BookSourceListPage check filter', () {
    testWidgets('checkFilter_givenAFailureGroup_hidesTheSourceFromHealthy', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('坏源'), groupName: '搜索失效')
        ..add(source: _source('好源'));

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.text(l10n.bookSourceCheckFilterHealthy));
      await tester.pumpAndSettle();

      expect(find.text('好源'), findsOneWidget);
      expect(find.text('坏源'), findsNothing);
    });
  });

  group('BookSourceListPage status light', () {
    testWidgets('light_givenAFreshVerdict_showsTheLabelAndTheElapsedTime', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(
          source: _source('甲'),
          lastCheck: SourceCheckRecord(
            sourceId: 1,
            checkedAt: DateTime(2026, 10, 22, 11, 58),
            status: SourceCheckStatus.succeeded,
            elapsedMillis: 640,
          ),
        );

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
        clock: _FixedClock(DateTime(2026, 10, 22, 12)),
      );
      final AppLocalizations l10n = _l10n(tester);

      // 灯的可访问名称 + 「上次校验 2 分钟前 · 640 毫秒」（ADR-0052 §决策 2）。
      expect(find.byTooltip(l10n.bookSourceCheckStatusPassed), findsOneWidget);
      expect(
        find.text(
          l10n.bookSourceListLastCheckLine(
            l10n.bookSourceListLastCheckMinutesAgo(2),
            640,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('light_givenFourSources_showsEveryState', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(
          source: _source('passed'),
          lastCheck: _record(SourceCheckStatus.succeeded),
        )
        ..add(
          source: _source('failed'),
          lastCheck: _record(
            SourceCheckStatus.failed,
            groups: <String>['搜索失效'],
          ),
        )
        ..add(
          source: _source('degraded'),
          lastCheck: _record(
            SourceCheckStatus.failed,
            groups: <String>['校验超时'],
          ),
        )
        ..add(source: _source('unchecked'));

      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.byTooltip(l10n.bookSourceCheckStatusPassed), findsOneWidget);
      expect(find.byTooltip(l10n.bookSourceCheckStatusFailed), findsOneWidget);
      expect(
        find.byTooltip(l10n.bookSourceCheckStatusDegraded),
        findsOneWidget,
      );
      expect(
        find.byTooltip(l10n.bookSourceCheckStatusUnchecked),
        findsOneWidget,
      );
    });
  });

  group('BookSourceListPage view options', () {
    testWidgets('sort_whenTheDirectionIsToggled_reversesTheRows', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('alpha', url: 'https://a.test'))
        ..add(source: _source('beta', url: 'https://b.test'));
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);
      expect(_rowNames(tester), <String>['alpha', 'beta']);

      await tester.tap(find.byTooltip(l10n.bookSourceListSortAscending));
      await tester.pumpAndSettle();

      expect(_rowNames(tester), <String>['beta', 'alpha']);
    });

    testWidgets('view_whenGroupByDomainIsChosen_showsOneHeaderPerHost', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('alpha', url: 'https://one.test/a'))
        ..add(source: _source('beta', url: 'https://two.test/b'));
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.bookSourceListViewOptions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListGroupByDomain));
      await tester.pumpAndSettle();

      expect(find.text('one.test'), findsOneWidget);
      expect(find.text('two.test'), findsOneWidget);
    });

    testWidgets('groups_whenRenamedThroughTheManager_rewritesThePayload', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = await _pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.bookSourceListViewOptions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListGroupManage));
      await tester.pumpAndSettle();
      // 分组名同时出现在筛选 chip、行副标题和对话框里，只点对话框里那一份。
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('精选'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListGroupRename));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '收藏',
      );
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      final List<StoredBookSource> rows = await repository.getAll();
      expect(
        rows.map((StoredBookSource row) => row.source.group),
        contains('收藏'),
      );
      expect(
        rows.map((StoredBookSource row) => row.source.group),
        isNot(contains('精选')),
      );
    });
  });

  group('BookSourceListPage batch overflow', () {
    testWidgets('batch_whenMoveToTopIsChosen_movesTheSelectionFirst', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = await _pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.longPress(find.text('乙'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.bookSourceListMoreActions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListBatchMoveTop));
      await tester.pumpAndSettle();

      final List<StoredBookSource> rows = await repository.getAll();
      expect(rows.first.source.name, '乙');
      expect(rows.every((StoredBookSource row) => row.isEnabled), isTrue);
    });

    testWidgets('batch_whenExploreIsDisabled_flipsTheColumn', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = await _pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.longPress(find.text('甲'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.bookSourceListMoreActions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceRowExploreDisable));
      await tester.pumpAndSettle();

      final List<StoredBookSource> rows = await repository.getAll();
      expect(
        rows.where((StoredBookSource row) => !row.isExploreEnabled),
        hasLength(1),
      );
    });
  });

  group('BookSourceListPage check handover', () {
    testWidgets('selection_whenCheckIsChosen_handsTheTickedRowsOver', (
      WidgetTester tester,
    ) async {
      // 回归点（ADR-0057）：多选后要能把「这几条」直接交给校验页。旧的选择工具栏只有启停、
      // 分组、删除，没有测试入口。
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('甲', group: '精选'))
        ..add(source: _source('乙', group: '玄幻'))
        ..add(source: _source('丙', group: '玄幻'));
      Object? pushed;
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
        onPush: (Object? arguments) => pushed = arguments,
      );
      final AppLocalizations l10n = _l10n(tester);
      final List<StoredBookSource> rows = await repository.getAll();
      final Set<int> picked = <int>{rows[0].id, rows[2].id};

      await tester.longPress(find.text('甲'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('丙'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListBatchCheck));
      await tester.pumpAndSettle();

      expect(pushed, isA<BookSourceCheckRoute>());
      expect(
        (pushed! as BookSourceCheckRoute).sourceIds,
        unorderedEquals(picked),
        reason: '只交出勾选的两条，不是全库',
      );
    });

    testWidgets('toolbar_whenAGroupIsFiltered_handsTheGroupOver', (
      WidgetTester tester,
    ) async {
      // 「选中分组并单独测试该组」：工具栏的校验入口要把当前分组带上（ADR-0057）。
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('甲', group: '精选'))
        ..add(source: _source('乙', group: '玄幻'));
      Object? pushed;
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
        onPush: (Object? arguments) => pushed = arguments,
      );

      await tester.tap(find.widgetWithText(FilterChip, '精选'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.fact_check_outlined));
      await tester.pumpAndSettle();

      expect(pushed, isA<BookSourceCheckRoute>());
      expect((pushed! as BookSourceCheckRoute).group, '精选');
      expect(
        (pushed! as BookSourceCheckRoute).sourceIds,
        isNull,
        reason: '按分组进来时由分组决定参测源，不另写一份 id',
      );
    });

    testWidgets('toolbar_whenNoGroupIsFiltered_handsNoTargetOver', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = await _pump(tester);
      Object? pushed;
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
        onPush: (Object? arguments) => pushed = arguments,
      );

      await tester.tap(find.byIcon(Icons.fact_check_outlined));
      await tester.pumpAndSettle();

      expect((pushed! as BookSourceCheckRoute).group, isNull);
      expect((pushed! as BookSourceCheckRoute).sourceIds, isNull);
    });
  });

  group('BookSourceListPage select mode', () {
    testWidgets('selection_whenTheToolbarEntryIsUsed_startsEmptyAndTicksRows', (
      WidgetTester tester,
    ) async {
      // 回归点（ADR-0059 §决策 1）：多选过去只能长按进入，且一进去就带着一行。
      // 桌面用户需要能看见的入口，也需要能从零开始挑。
      await _pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.bookSourceListSelectMode));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceListSelectedCount(0)), findsOneWidget);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((Checkbox box) => box.value != true),
        isTrue,
      );

      await tester.tap(find.text('甲'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceListSelectedCount(1)), findsOneWidget);
    });

    testWidgets('selection_whenTheRowSwitchIsReached_itIsInert', (
      WidgetTester tester,
    ) async {
      // 多选期间行内开关与行菜单关掉：否则一个误触就把单条源改了或开了某个菜单。
      final FakeBookSourceRepository repository = await _pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.bookSourceListSelectMode));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Switch>(find.byType(Switch).first).onChanged,
        isNull,
      );
      // 行菜单（tooltip 是源名）也关掉：多选时点行是「勾选」，不该弹出编辑 / 删除菜单。
      // 批量工具栏自己的“⋯”仍然可用，所以只断言行上那个。
      expect(
        tester
            .widget<PopupMenuButton<Object?>>(
              find.byWidgetPredicate(
                (Widget widget) =>
                    widget is PopupMenuButton<Object?> && widget.tooltip == '甲',
              ),
            )
            .enabled,
        isFalse,
      );
      expect(
        (await repository.getAll()).every(
          (StoredBookSource row) => row.isEnabled,
        ),
        isTrue,
      );
    });
  });

  group('BookSourceListPage failing actions', () {
    /// Two failing sources (a note and a check-owned group) and one healthy source.
    FakeBookSourceRepository failingRepository() => FakeBookSourceRepository()
      ..add(source: _source('好源'))
      ..add(source: _source('坏源'), comment: '// Error: 404')
      ..add(source: _source('坏源二'), groupName: searchInvalidGroup);

    testWidgets('failing_whenDisableIsChosen_disablesEveryListedFailure', (
      WidgetTester tester,
    ) async {
      // 一键处置（ADR-0059 §决策 2）：「有失效」筛选下面的就是被处理的集合。
      final FakeBookSourceRepository repository = failingRepository();
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(
        find.widgetWithText(ChoiceChip, l10n.bookSourceCheckFilterFailing),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.bookSourceListInvalidDisable),
      );
      await tester.pumpAndSettle();

      final List<StoredBookSource> rows = await repository.getAll();
      expect(
        rows
            .where((StoredBookSource row) => row.source.name == '好源')
            .single
            .isEnabled,
        isTrue,
      );
      expect(
        rows
            .where((StoredBookSource row) => row.source.name != '好源')
            .every((StoredBookSource row) => !row.isEnabled),
        isTrue,
      );
    });

    testWidgets('failing_whenDeleteIsConfirmed_removesOnlyTheFailures', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = failingRepository();
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(
        find.widgetWithText(ChoiceChip, l10n.bookSourceCheckFilterFailing),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.bookSourceListInvalidDelete),
      );
      await tester.pumpAndSettle();
      // 确认对话框里的同名按钮。
      await tester.tap(
        find.widgetWithText(TextButton, l10n.bookSourceListInvalidDelete).last,
      );
      await tester.pumpAndSettle();

      expect(
        (await repository.getAll()).map(
          (StoredBookSource row) => row.source.name,
        ),
        <String>['好源'],
      );
    });
  });

  group('BookSourceListPage group actions', () {
    /// Opens 「视图 → 分组管理」 and picks [group] in the list of groups.
    Future<void> openGroupDialog(WidgetTester tester, String group) async {
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.bookSourceListViewOptions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceListGroupManage));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(group),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('groups_whenSelectEverySourceIsChosen_ticksTheWholeGroup', (
      WidgetTester tester,
    ) async {
      // 「根据分组一键管理」（ADR-0059 §决策 3）：先把列表切到该组，再把它的行全部勾上。
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('甲', group: '精选'))
        ..add(source: _source('乙', group: '玄幻'))
        ..add(source: _source('丙', group: '玄幻'));
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      await openGroupDialog(tester, '玄幻');
      await tester.tap(find.text(l10n.bookSourceListGroupSelectSources));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceListSelectedCount(2)), findsOneWidget);
      // 列表已经切到该分组：别的组不在视野里，勾选也不会被剪掉。
      expect(find.text('甲'), findsNothing);

      // 选中之后就能用批量动作（一键禁用 / 删除 / 分组 / 移动）。
      await tester.tap(find.text(l10n.bookSourceListBatchDisable));
      await tester.pumpAndSettle();

      final List<StoredBookSource> rows = await repository.getAll();
      expect(
        rows
            .where((StoredBookSource row) => row.source.group == '玄幻')
            .every((StoredBookSource row) => !row.isEnabled),
        isTrue,
      );
      expect(
        rows
            .where((StoredBookSource row) => row.source.group == '精选')
            .single
            .isEnabled,
        isTrue,
      );
    });

    testWidgets('groups_whenDeleteEverySourceIsConfirmed_deletesThatGroup', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('甲', group: '精选'))
        ..add(source: _source('乙', group: '玄幻'))
        ..add(source: _source('丙', group: '玄幻'));
      await pumpSourceManagementPage(
        tester,
        page: const BookSourceListPage(),
        repository: repository,
      );
      final AppLocalizations l10n = _l10n(tester);

      await openGroupDialog(tester, '玄幻');
      await tester.tap(find.text(l10n.bookSourceListGroupDeleteSources));
      await tester.pumpAndSettle();
      // 确认对话框里的同名按钮。
      await tester.tap(
        find
            .widgetWithText(TextButton, l10n.bookSourceListGroupDeleteSources)
            .last,
      );
      await tester.pumpAndSettle();

      expect(
        (await repository.getAll()).map(
          (StoredBookSource row) => row.source.name,
        ),
        <String>['甲'],
      );
    });
  });

  group('BookSourceListPage export', () {
    testWidgets('appBarExport_whenChosen_writesEverySourceAsOneArray', (
      WidgetTester tester,
    ) async {
      // 5.8 的批量导出（ADR-0071 §决策 3）：一个文件、上游数组、未知键保真。
      final _RecordingSaver saver = _RecordingSaver();
      await _pump(tester, saver: saver);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.bookSourceListMoreActions).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceExportAll));
      await tester.pumpAndSettle();

      expect(saver.savedName, 'bookSources-2.json');
      expect(saver.savedContents, isNotNull);
      expect(saver.savedContents, contains('"bookSourceUrl"'));
      expect(saver.savedContents, startsWith('['));
      expect(find.text(l10n.bookSourceExportAllSaved(2)), findsOneWidget);
    });

    testWidgets('batchExport_whenChosen_writesOnlyTheTickedSources', (
      WidgetTester tester,
    ) async {
      final _RecordingSaver saver = _RecordingSaver();
      await _pump(tester, saver: saver);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.bookSourceListSelectMode));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.bookSourceListMoreActions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceExportSelected(1)));
      await tester.pumpAndSettle();

      expect(saver.savedName, 'bookSources-1.json');
      expect(find.text(l10n.bookSourceExportAllSaved(1)), findsOneWidget);
    });
  });

  group('BookSourceListPage row actions', () {
    testWidgets('row_whenExportIsChosen_copiesThePayload', (
      WidgetTester tester,
    ) async {
      // 导出走 payload 原文（ADR-0050 §决策 4）；剪贴板写入由 `Clipboard` 平台通道完成，
      // 这里只断言动作跑完并给出提示。
      final _RecordingSaver saver = _RecordingSaver();
      await _pump(tester, saver: saver);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.bookSourceRowExport));
      await tester.pumpAndSettle();

      expect(saver.savedContents, isNotNull);
      expect(saver.savedContents, contains('bookSourceUrl'));
    });
  });
}

/// The names of the visible rows, in order.
List<String> _rowNames(WidgetTester tester) => <String>[
  for (final ListTile tile in tester.widgetList<ListTile>(
    find.byType(ListTile),
  ))
    (tile.title as Text?)?.data ?? '',
];

/// One recorded verdict for the source with [sourceId].
SourceCheckRecord _record(
  SourceCheckStatus status, {
  List<String> groups = const <String>[],
  int sourceId = 1,
}) => SourceCheckRecord(
  sourceId: sourceId,
  checkedAt: DateTime(2026, 10, 22, 11),
  status: status,
  elapsedMillis: 320,
  invalidGroups: groups,
);

/// A clock the test pins (testing.md §4).
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  final DateTime _now;

  @override
  DateTime now() => _now;
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
