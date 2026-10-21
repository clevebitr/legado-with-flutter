import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/book_source/data/search_scope_store_impl.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the store on a mocked `shared_preferences` store.
Future<SearchScopeStoreImpl> _store([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);

  return SearchScopeStoreImpl(
    store: PreferenceStore(await SharedPreferences.getInstance()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchScopeStoreImpl', () {
    test('load_givenNothingStored_answersAll', () async {
      expect(await (await _store()).load(), const BookSearchScope.all());
    });

    test('save_thenLoad_roundTripsGroups', () async {
      final SearchScopeStoreImpl store = await _store();
      const BookSearchScope scope = BookSearchScope.groups(<String>{
        '玄幻',
        '精选',
      });

      await store.save(scope);

      expect(await store.load(), scope);
    });

    test('save_thenLoad_roundTripsNamedSources', () async {
      final SearchScopeStoreImpl store = await _store();
      const BookSearchScope scope = BookSearchScope.sources(<ScopeSource>[
        ScopeSource(name: 'A', url: 'https://a.test'),
      ]);

      await store.save(scope);

      expect(await store.load(), scope);
    });

    test('save_givenAll_removesTheStoredScope', () async {
      // 「全部」是「没有范围」：删键比存一个标记更不会过期（ADR-0046 §决策 1）。
      final SearchScopeStoreImpl store = await _store(<String, Object>{
        'bookSource.searchScope': '{"type":"group","groups":["x"]}',
      });

      await store.save(const BookSearchScope.all());

      expect(await store.load(), const BookSearchScope.all());
    });

    test('load_givenAHandEditedPayload_fallsBackToAll', () async {
      final SearchScopeStoreImpl store = await _store(<String, Object>{
        'bookSource.searchScope': 'not json',
      });

      expect(await store.load(), const BookSearchScope.all());
    });
  });
}
