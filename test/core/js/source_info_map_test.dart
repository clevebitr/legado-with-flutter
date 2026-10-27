import 'package:flutter_reader/core/js/source_info_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceInfoMapStore', () {
    test('snapshot_givenNoWrite_answersAnEmptyMap', () {
      expect(SourceInfoMapStore().snapshot('https://a.test'), isEmpty);
    });

    test('merge_thenSnapshot_keepsTheValuesPerSource', () {
      final SourceInfoMapStore store = SourceInfoMapStore();

      store.merge('https://a.test', <String, String?>{'token': 'a'});
      store.merge('https://b.test', <String, String?>{'token': 'b'});

      expect(store.snapshot('https://a.test'), <String, String>{'token': 'a'});
      expect(store.snapshot('https://b.test'), <String, String>{'token': 'b'});
    });

    test('merge_givenANullValue_removesTheKey', () {
      // `infoMap['x'] = null`（或 `delete infoMap.x`）在上游等于删键。
      final SourceInfoMapStore store = SourceInfoMapStore();
      store.merge('https://a.test', <String, String?>{
        'token': 'a',
        'kind': 'x',
      });

      store.merge('https://a.test', <String, String?>{'token': null});

      expect(store.snapshot('https://a.test'), <String, String>{'kind': 'x'});
    });

    test('merge_givenAnEmptyReport_leavesTheMapAlone', () {
      final SourceInfoMapStore store = SourceInfoMapStore();
      store.merge('https://a.test', <String, String?>{'token': 'a'});

      store.merge('https://a.test', const <String, String?>{});

      expect(store.snapshot('https://a.test'), <String, String>{'token': 'a'});
    });

    test('merge_pastTheSourceBound_dropsTheOldestSource', () {
      final SourceInfoMapStore store = SourceInfoMapStore();
      for (var index = 0; index <= SourceInfoMapStore.maxSources; index++) {
        store.merge('https://$index.test', <String, String?>{'n': '$index'});
      }

      expect(store.snapshot('https://0.test'), isEmpty);
      expect(store.snapshot('https://1.test'), isNotEmpty);
    });

    test('snapshot_countsAsUse_soTheTouchedSourceStays', () {
      // 读也算「用过」：批量校验会把同一个源读很多次，读不该让它被挤掉。
      final SourceInfoMapStore store = SourceInfoMapStore();
      store.merge('https://keep.test', <String, String?>{'n': '1'});
      for (var index = 0; index < SourceInfoMapStore.maxSources; index++) {
        store.snapshot('https://keep.test');
        store.merge('https://$index.test', <String, String?>{'n': '$index'});
      }

      expect(store.snapshot('https://keep.test'), <String, String>{'n': '1'});
    });

    test('snapshot_answersAnUnmodifiableMap', () {
      final SourceInfoMapStore store = SourceInfoMapStore();
      store.merge('https://a.test', <String, String?>{'token': 'a'});

      expect(
        () => store.snapshot('https://a.test')['token'] = 'b',
        throwsUnsupportedError,
      );
    });
  });
}
