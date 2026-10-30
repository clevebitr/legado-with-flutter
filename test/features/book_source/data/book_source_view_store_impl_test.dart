import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/book_source/data/book_source_view_store_impl.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_list_view.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the store on a mocked `shared_preferences` store.
Future<BookSourceViewStoreImpl> _store([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);

  return BookSourceViewStoreImpl(
    store: PreferenceStore(await SharedPreferences.getInstance()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookSourceListView', () {
    test('defaults_whenNothingIsStored_isTheManualOrderAndEveryGroup', () {
      const BookSourceListView view = BookSourceListView.defaults;

      expect(view.order, BookSourceSortOrder.defaultOrder);
      expect(view.group, isNull);
    });

    test('copyWith_givenAGroup_replacesIt', () {
      const BookSourceListView view = BookSourceListView.defaults;

      expect(view.copyWith(group: '精选').group, '精选');
      expect(
        view.copyWith(order: BookSourceSortOrder.weight).order,
        BookSourceSortOrder.weight,
      );
    });

    test('copyWith_givenClearGroup_dropsTheFilter', () {
      // 「保持」与「回到全部分组」都是合法操作，所以清除要显式：传 null 是保持。
      const BookSourceListView filtered = BookSourceListView(group: '精选');

      expect(filtered.copyWith().group, '精选');
      expect(filtered.copyWith(clearGroup: true).group, isNull);
    });
  });

  group('BookSourceViewStoreImpl', () {
    test('load_givenNothingStored_answersTheDefaults', () async {
      expect(await (await _store()).load(), BookSourceListView.defaults);
    });

    test('save_thenLoad_roundTripsOrderAndGroup', () async {
      final BookSourceViewStoreImpl store = await _store();
      const BookSourceListView view = BookSourceListView(
        order: BookSourceSortOrder.respondTime,
        group: '精选',
      );

      await store.save(view);

      expect(await store.load(), view);
    });

    test('save_givenNoGroup_removesTheStoredOne', () async {
      final BookSourceViewStoreImpl store = await _store(<String, Object>{
        'bookSource.listGroup': '精选',
      });

      await store.save(
        const BookSourceListView(order: BookSourceSortOrder.weight),
      );

      expect(
        await store.load(),
        const BookSourceListView(order: BookSourceSortOrder.weight),
      );
    });

    test('load_givenAnUnknownOrderName_fallsBackToTheManualOrder', () async {
      // 索引会随枚举增长指错位置，所以存名字；名字不认识时回落到默认序（ADR-0045 §决策 4）。
      final BookSourceViewStoreImpl store = await _store(<String, Object>{
        'bookSource.listOrder': 'byPopularity',
      });

      expect((await store.load()).order, BookSourceSortOrder.defaultOrder);
    });

    test('load_givenAStoredGroup_answersItUnchanged', () async {
      // 分组是否还存在由列表在渲染时判断（存储层看不到行）。
      final BookSourceViewStoreImpl store = await _store(<String, Object>{
        'bookSource.listGroup': '已删除的分组',
      });

      expect((await store.load()).group, '已删除的分组');
    });
  });
}
