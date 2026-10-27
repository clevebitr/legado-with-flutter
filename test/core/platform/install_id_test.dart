import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/install_id.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_log_printer.dart';

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<PreferenceStore> _preferences([
  Map<String, Object> seed = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(seed);

  return PreferenceStore(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferenceInstallIdStore', () {
    test('write_thenRead_roundTripsThroughThePreferenceStore', () async {
      // 这是 `main()` 真正用的那条路：一个短字符串进轻量开关（C-DEP-2 允许的唯一形态）。
      final PreferenceInstallIdStore store = PreferenceInstallIdStore(
        await _preferences(),
      );
      expect(store.read(), isNull);

      await store.write('install-1');

      expect(store.read(), 'install-1');
    });

    test('read_givenAStoredValue_answersIt', () async {
      final PreferenceInstallIdStore store = PreferenceInstallIdStore(
        await _preferences(<String, Object>{
          InstallId.preferenceKey: 'install-2',
        }),
      );

      expect(store.read(), 'install-2');
    });
  });

  group('InstallId', () {
    test('value_beforeHydrate_isNull', () {
      // 沙箱读到 null 就答空串：hydrate 是 `main()` 的责任，早读只会拿不到值。
      expect(InstallId().value, isNull);
    });

    test('hydrate_givenNoStoredId_generatesAndPersistsOne', () async {
      final _RecordingStore store = _RecordingStore();
      final InstallId id = InstallId();

      await id.hydrate(store);

      final String? generated = id.value;
      expect(generated, isNotNull);
      expect(_uuidV4.hasMatch(generated ?? ''), isTrue, reason: generated);
      expect(store.stored, generated);
    });

    test('hydrate_givenAStoredId_reusesIt', () async {
      final _RecordingStore store = _RecordingStore(stored: 'stored-id');
      final InstallId id = InstallId();

      await id.hydrate(store);

      expect(id.value, 'stored-id');
      expect(store.writes, isEmpty);
    });

    test('hydrate_givenABlankStoredId_generatesATrimmedOne', () async {
      final _RecordingStore store = _RecordingStore(stored: '   ');
      final InstallId id = InstallId();

      await id.hydrate(store);

      expect(id.value, isNot('   '));
      expect(_uuidV4.hasMatch(id.value ?? ''), isTrue);
    });

    test('hydrate_calledTwice_keepsTheFirstValue', () async {
      final _RecordingStore store = _RecordingStore();
      final InstallId id = InstallId();
      await id.hydrate(store);
      final String? first = id.value;

      await id.hydrate(store);

      expect(id.value, first);
    });

    test(
      'hydrate_whenTheStoreCannotBeWritten_keepsTheValueForTheSession',
      () async {
        // 写不进去只是下一次启动看起来像新安装：值得一条 warning，不该让启动失败。
        final FakeLogPrinter printer = FakeLogPrinter();
        final InstallId id = InstallId(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
        );

        await id.hydrate(_FailingStore());

        expect(_uuidV4.hasMatch(id.value ?? ''), isTrue);
        expect(
          printer.events.map((LogEvent event) => event.message),
          contains(contains('Could not persist the install id')),
        );
      },
    );
  });
}

/// In-memory [InstallIdStore] that records the writes.
final class _RecordingStore implements InstallIdStore {
  _RecordingStore({this.stored});

  String? stored;
  final List<String> writes = <String>[];

  @override
  String? read() => stored;

  @override
  Future<void> write(String id) async {
    writes.add(id);
    stored = id;
  }
}

/// A store whose reads always miss and whose writes always fail.
final class _FailingStore implements InstallIdStore {
  @override
  String? read() => null;

  @override
  Future<void> write(String id) async {
    throw const FormatException('read-only');
  }
}
