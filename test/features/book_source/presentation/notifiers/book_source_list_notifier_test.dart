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
import '../../../../support/offline_corpus.dart';

/// A stored source built from the offline corpus with a distinct name.
BookSource _source(String name) =>
    loadCorpusBookSource().copyWith(name: name, url: 'https://$name.test');

/// One stored source with [name] and an optional user group / verdict group.
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
    'bookSourceGroup': group,
    'ruleSearch': <String, Object?>{'bookList': 'class.item'},
    'ruleBookInfo': <String, Object?>{'name': 'class.name'},
    'ruleToc': <String, Object?>{'chapterList': 'class.chapter'},
    'ruleContent': <String, Object?>{'content': 'class.body'},
  }),
  groupName: checkGroup,
  comment: comment,
  weight: weight,
);

void main() {
  group('SelectedBookSource', () {
    late FakeBookSourceRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeBookSourceRepository();
      container = ProviderContainer(
        overrides: [bookSourceRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    /// Settles the selection and returns it.
    Future<StoredBookSource?> settle() =>
        container.read(selectedBookSourceProvider.future);

    test('build_givenSeveralSources_selectsTheFirstEnabledOne', () async {
      // ADR-0040 §决策 3 的顺序（启用位 → customOrder → id）就是「默认源」的口径。
      repository
        ..add(source: _source('disabled'), isEnabled: false, customOrder: 1)
        ..add(source: _source('later'), customOrder: 5)
        ..add(source: _source('first'), customOrder: 2);

      expect((await settle())?.source.name, 'first');
      expect(container.read(currentBookSourceProvider)?.name, 'first');
    });

    test('build_givenOnlyDisabledSources_selectsNothing', () async {
      repository.add(source: _source('disabled'), isEnabled: false);

      expect(await settle(), isNull);
      expect(container.read(currentBookSourceProvider), isNull);
    });

    test('select_givenAStoredSource_changesTheProjection', () async {
      final StoredBookSource first = repository.add(source: _source('a'));
      final StoredBookSource second = repository.add(source: _source('b'));
      await settle();

      await container
          .read(selectedBookSourceProvider.notifier)
          .select(second.id);

      expect(container.read(currentBookSourceProvider)?.name, 'b');
      expect(first.id, isNot(second.id));
    });

    test('select_givenAnUnknownId_keepsTheCurrentSelection', () async {
      repository
        ..add(source: _source('a'))
        ..add(source: _source('b'));
      await settle();

      await container.read(selectedBookSourceProvider.notifier).select(404);

      expect(container.read(currentBookSourceProvider)?.name, 'a');
    });

    test('remove_givenTheSelectedSource_fallsBackToTheDefault', () async {
      final StoredBookSource first = repository.add(source: _source('a'));
      final StoredBookSource second = repository.add(source: _source('b'));
      await settle();
      await container
          .read(selectedBookSourceProvider.notifier)
          .select(second.id);

      await container
          .read(selectedBookSourceProvider.notifier)
          .remove(second.id);

      // 悬空选择是禁止的：选中的行没了就必须回落到默认源（docs/dev/roadmap.md 5.1）。
      expect(container.read(currentBookSourceProvider)?.name, 'a');
      expect(first.id, isNot(second.id));
    });

    test('remove_givenTheLastSource_leavesNothingSelected', () async {
      final StoredBookSource only = repository.add(source: _source('only'));
      await settle();

      await container.read(selectedBookSourceProvider.notifier).remove(only.id);

      expect(container.read(currentBookSourceProvider), isNull);
    });

    test('remove_givenANonSelectedSource_keepsTheSelection', () async {
      final StoredBookSource first = repository.add(source: _source('a'));
      final StoredBookSource second = repository.add(source: _source('b'));
      await settle();
      await container
          .read(selectedBookSourceProvider.notifier)
          .select(second.id);

      await container
          .read(selectedBookSourceProvider.notifier)
          .remove(first.id);

      expect(container.read(currentBookSourceProvider)?.name, 'b');
    });

    test('toggleEnabled_givenTheSelectedSource_keepsItSelected', () async {
      final StoredBookSource first = repository.add(source: _source('a'));
      await settle();

      await container
          .read(selectedBookSourceProvider.notifier)
          .toggleEnabled(id: first.id, isEnabled: false);

      // 关掉自己不是「删除」：用户的选择保留，列表里那一行显示为已禁用。
      expect(container.read(currentBookSourceProvider)?.name, 'a');
      expect(
        (await container.read(bookSourceListProvider.future)).single.isEnabled,
        isFalse,
      );
    });
  });

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
      final ProviderContainer scope = container();

      expect(
        await scope.read(bookSourceViewProvider.future),
        BookSourceListView.defaults,
      );
    });

    test('setOrder_whenCalled_storesAndPublishesIt', () async {
      final ProviderContainer scope = container();
      await scope.read(bookSourceViewProvider.future);

      await scope
          .read(bookSourceViewProvider.notifier)
          .setOrder(BookSourceSortOrder.respondTime);

      expect(
        scope.read(bookSourceViewProvider).value?.order,
        BookSourceSortOrder.respondTime,
      );
      expect(store.view.order, BookSourceSortOrder.respondTime);
    });

    test('setGroup_givenNull_dropsTheFilter', () async {
      store.view = const BookSourceListView(group: '精选');
      final ProviderContainer scope = container();
      await scope.read(bookSourceViewProvider.future);

      await scope.read(bookSourceViewProvider.notifier).setGroup(null);

      expect(scope.read(bookSourceViewProvider).value?.group, isNull);
      expect(store.view.group, isNull);
    });

    test('reorder_whenCalled_renumbersTheStoredRows', () async {
      final StoredBookSource first = _seed(repository, 'first');
      final StoredBookSource second = _seed(repository, 'second');
      final ProviderContainer scope = container();
      await scope.read(bookSourceViewProvider.future);

      await scope.read(bookSourceViewProvider.notifier).reorder(<int>[
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
      // 视图把方向存成实际方向：权重的默认方向是降序（ADR-0052 §决策 4）。
      store.view = const BookSourceListView(
        order: BookSourceSortOrder.weight,
        ascending: false,
      );

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
