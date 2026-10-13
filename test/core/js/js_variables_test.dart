import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsVariableStore', () {
    test('snapshot_givenAWrittenVariable_returnsACopyOfIt', () {
      final JsVariableStore store = JsVariableStore()
        ..write('https://a.test', 'token', 'abc');

      final Map<String, String> snapshot = store.snapshot('https://a.test');
      store.write('https://a.test', 'token', 'changed');

      // 快照是副本：job 拿到它之后，宿主再写也不会改到 job 里的那份（ADR-0034 §决策 1）。
      expect(snapshot, <String, String>{'token': 'abc'});
      expect(store.read('https://a.test', 'token'), 'changed');
    });

    test('snapshot_givenAnUnknownSource_returnsAnEmptyMap', () {
      expect(JsVariableStore().snapshot('https://a.test'), isEmpty);
    });

    test('snapshot_givenASnapshot_mutationIsRejected', () {
      final JsVariableStore store = JsVariableStore()
        ..write('https://a.test', 'token', 'abc');
      final Map<String, String> snapshot = store.snapshot('https://a.test');

      expect(() => snapshot['token'] = 'changed', throwsUnsupportedError);
    });

    test('read_givenAnotherSource_isIsolated', () {
      final JsVariableStore store = JsVariableStore()
        ..write('https://a.test', 'token', 'abc');

      // 变量按书源键控（ADR-0030 §决策 4）：另一个书源看不到它。
      expect(store.read('https://b.test', 'token'), isNull);
    });

    test('write_givenANullValue_removesTheVariable', () {
      final JsVariableStore store = JsVariableStore()
        ..write('https://a.test', 'token', 'abc');

      store.write('https://a.test', 'token', null);

      expect(store.read('https://a.test', 'token'), isNull);
      expect(store.snapshot('https://a.test'), isEmpty);
    });

    test('write_givenANullValueForAnUnknownSource_doesNothing', () {
      final JsVariableStore store = JsVariableStore();

      expect(
        () => store.write('https://a.test', 'token', null),
        returnsNormally,
      );
      expect(store.snapshot('https://a.test'), isEmpty);
    });

    test('write_givenASecondKey_keepsTheFirstOne', () {
      final JsVariableStore store = JsVariableStore()
        ..write('https://a.test', 'a', '1')
        ..write('https://a.test', 'b', '2');

      // 清掉一个键后源里还有别的键：整源条目保留（这条钉的是空源清理的边界）。
      store.write('https://a.test', 'a', null);

      expect(store.snapshot('https://a.test'), <String, String>{'b': '2'});
    });

    test('merge_givenAJavaReport_appliesEveryEntry', () {
      final JsVariableStore store = JsVariableStore()
        ..write('https://a.test', 'kept', 'yes');

      store.merge('https://a.test', <String, String?>{
        'token': 'abc',
        'kept': null,
      });

      // `java.put` 的回报是整份 map：没提到的键原样保留（并发 job 的写入不能被抹掉）。
      expect(store.snapshot('https://a.test'), <String, String>{
        'token': 'abc',
      });
    });
  });
}
