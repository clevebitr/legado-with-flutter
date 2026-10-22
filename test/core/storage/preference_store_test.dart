import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PreferenceStore', () {
    late PreferenceStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'int': 7,
        'double': 1.5,
        'string': 'stored',
        'bool': true,
      });
      store = PreferenceStore(await SharedPreferences.getInstance());
    });

    test('readInt_givenAStoredValue_answersIt', () {
      expect(store.readInt('int'), 7);
    });

    test('readInt_givenAnUnknownKey_answersNull', () {
      expect(store.readInt('missing'), isNull);
    });

    test('readInt_givenAnotherType_answersNull', () {
      // 类型不对时按「没存过」处理：调用方拿到 null 就会回落到默认值，而不是崩溃。
      expect(store.readInt('string'), isNull);
    });

    test('readDouble_whenStored_answersIt', () {
      expect(store.readDouble('double'), 1.5);
    });

    test('readString_whenStored_answersIt', () {
      expect(store.readString('string'), 'stored');
    });

    test('readBool_whenStored_answersIt', () {
      expect(store.readBool('bool'), isTrue);
    });

    test('readBool_givenAnotherType_answersNull', () {
      // 同 readInt：类型不对按「没存过」处理，视图回落到默认值而不是崩溃。
      expect(store.readBool('int'), isNull);
    });

    test('writeInt_whenCalled_isVisibleToTheNextRead', () async {
      await store.writeInt('int', 9);

      expect(store.readInt('int'), 9);
    });

    test('writeDouble_whenCalled_isVisibleToTheNextRead', () async {
      await store.writeDouble('double', 1.25);

      expect(store.readDouble('double'), 1.25);
    });

    test('writeString_whenCalled_isVisibleToTheNextRead', () async {
      await store.writeString('string', 'next');

      expect(store.readString('string'), 'next');
    });

    test('writeBool_whenCalled_isVisibleToTheNextRead', () async {
      await store.writeBool('bool', false);

      expect(store.readBool('bool'), isFalse);
    });

    test('remove_whenCalled_dropsTheKey', () async {
      await store.remove('int');

      expect(store.readInt('int'), isNull);
    });
  });
}
