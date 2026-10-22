import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_list_view.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_book_source_view_store.dart';

/// One stored source with [name] and an optional [group].
StoredBookSource _seed(
  FakeBookSourceRepository repository,
  String name, {
  String? group,
  String? checkGroup,
  String? comment,
  int weight = 0,
}) => repository.add(
  source: BookSource.fromLegadoJson(<String, Object?>{
    'bookSourceName': name,
    'bookSourceUrl': 'https://$name.test',
    // 用户分组在 payload 里（ADR-0050 §决策 1）；`checkGroup` 才是校验列。
    'bookSourceGroup': ?group,
    'ruleSearch': <String, Object?>{'bookList': 'class.item'},
    'ruleToc': <String, Object?>{'chapterList': 'class.c'},
    'ruleContent': <String, Object?>{'content': 'class.body'},
  }),
  groupName: checkGroup,
  comment: comment,
  weight: weight,
);

void main() {
  group('BookSourceView', () {
    late FakeBookSourceRepository repository;
    late FakeBookSourceViewStore store;

    setUp(() {
      repository = FakeBookSourceRepository();
      store = FakeBookSourceViewStore();
    });

    ProviderContainer container() => ProviderContainer.test(
      overrides: <Override>[
        bookSourceRepositoryProvider.overrideWithValue(repository),
        bookSourceViewStoreProvider.overrideWith((Ref ref) async => store),
      ],
    );

    test('build_givenNothingStored_answersTheDefaults', () async {
      final ProviderContainer container$ = container();

      expect(
        await container$.read(bookSourceViewProvider.future),
        BookSourceListView.defaults,
      );
    });

    test('setOrder_whenCalled_storesAndPublishesIt', () async {
      final ProviderContainer container$ = container();
      await container$.read(bookSourceViewProvider.future);

      await container$
          .read(bookSourceViewProvider.notifier)
          .setOrder(BookSourceSortOrder.respondTime);

      expect(
        container$.read(bookSourceViewProvider).value?.order,
        BookSourceSortOrder.respondTime,
      );
      expect(store.view.order, BookSourceSortOrder.respondTime);
    });

    test('setGroup_givenNull_dropsTheFilter', () async {
      store.view = const BookSourceListView(group: '精选');
      final ProviderContainer container$ = container();
      await container$.read(bookSourceViewProvider.future);

      await container$.read(bookSourceViewProvider.notifier).setGroup(null);

      expect(container$.read(bookSourceViewProvider).value?.group, isNull);
      expect(store.view.group, isNull);
    });

    test('reorder_whenCalled_renumbersTheStoredRows', () async {
      final StoredBookSource first = _seed(repository, 'first');
      final StoredBookSource second = _seed(repository, 'second');
      final ProviderContainer container$ = container();
      await container$.read(bookSourceViewProvider.future);

      await container$.read(bookSourceViewProvider.notifier).reorder(<int>[
        second.id,
        first.id,
      ]);

      final List<StoredBookSource> rows = await repository.getAll();
      expect(
        rows.map((StoredBookSource source) => source.source.name),
        <String>['second', 'first'],
      );
      expect(rows.map((StoredBookSource source) => source.customOrder), <int>[
        0,
        1,
      ]);
    });
  });

  group('bookSourceListData', () {
    late FakeBookSourceRepository repository;
    late FakeBookSourceViewStore store;

    setUp(() {
      repository = FakeBookSourceRepository();
      store = FakeBookSourceViewStore();
    });

    ProviderContainer container() => ProviderContainer.test(
      overrides: <Override>[
        bookSourceRepositoryProvider.overrideWithValue(repository),
        bookSourceViewStoreProvider.overrideWith((Ref ref) async => store),
      ],
    );

    test('build_givenStoredGroups_answersTheGroupsAndEveryRow', () async {
      _seed(repository, 'a', group: '精选');
      _seed(repository, 'b', group: '玄幻');
      _seed(repository, 'c');

      final BookSourceListData data = await container().read(
        bookSourceListDataProvider.future,
      );

      expect(data.groups, <String>['玄幻', '精选']);
      expect(data.rows, hasLength(3));
      expect(data.view.group, isNull);
    });

    test('build_givenAStoredGroup_filtersTheRows', () async {
      _seed(repository, 'a', group: '精选');
      _seed(repository, 'b', group: '玄幻');
      store.view = const BookSourceListView(group: '精选');

      final BookSourceListData data = await container().read(
        bookSourceListDataProvider.future,
      );

      expect(
        data.rows.map((StoredBookSource source) => source.source.name),
        <String>['a'],
      );
      expect(data.view.group, '精选');
    });

    test('build_givenACheckGroup_doesNotChangeTheGroupAxis', () async {
      // ADR-0050 §决策 1 的回归点：校验写回的「搜索失效」以前会顶掉用户分组，
      // 现在它只属于校验状态轴。
      _seed(repository, 'a', group: '精选', checkGroup: searchInvalidGroup);

      final BookSourceListData data = await container().read(
        bookSourceListDataProvider.future,
      );

      expect(data.groups, <String>['精选']);
    });

    test('checkFilter_givenAFailureGroup_hidesTheSourceFromHealthy', () async {
      _seed(repository, 'bad', checkGroup: searchInvalidGroup);
      _seed(repository, 'good');
      final ProviderContainer scope = container();
      scope
          .read(bookSourceCheckFilterSelectionProvider.notifier)
          .select(BookSourceCheckFilter.healthy);

      final BookSourceListData data = await scope.read(
        bookSourceListDataProvider.future,
      );

      expect(
        data.rows.map((StoredBookSource source) => source.source.name),
        <String>['good'],
      );
    });

    test('build_givenAStoredGroupThatIsGone_dropsTheFilter', () async {
      // 分组被改名 / 删源后不再存在：渲染期回落到「全部分组」，并且不写回存储。
      _seed(repository, 'a', group: '精选');
      store.view = const BookSourceListView(group: '已删除的分组');

      final BookSourceListData data = await container().read(
        bookSourceListDataProvider.future,
      );

      expect(data.rows, hasLength(1));
      expect(data.view.group, isNull);
      expect(store.view.group, '已删除的分组');
    });

    test('build_givenTheWeightOrder_ordersTheRows', () async {
      _seed(repository, 'light', weight: 1);
      _seed(repository, 'heavy', weight: 9);
      store.view = const BookSourceListView(order: BookSourceSortOrder.weight);

      final BookSourceListData data = await container().read(
        bookSourceListDataProvider.future,
      );

      expect(
        data.rows.map((StoredBookSource source) => source.source.name),
        <String>['heavy', 'light'],
      );
    });
  });
}
