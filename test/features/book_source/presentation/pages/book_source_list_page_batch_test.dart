import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/book_source_file_saver.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
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
  BookSourceFileSaver? saver,
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
final class _RecordingSaver implements BookSourceFileSaver {
  String? savedContents;

  @override
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required String contents,
  }) async {
    savedContents = contents;

    return const ParseSuccess<bool>(true);
  }
}
