import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/flutter_secure_storage_secret_store.dart';
import 'package:flutter_reader/core/platform/secret_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_log_printer.dart';

void main() {
  group('UnsupportedSecretStore', () {
    test('read_givenNoKeyStore_answersNull', () async {
      expect(
        await UnsupportedSecretStore(logger: AppLogger())
            .read('backup.password'),
        isNull,
      );
    });

    test('write_givenNoKeyStore_answersNotStoredAndWarns', () async {
      // 写不进去必须能被上层看见：页面据此提示「备份未加密」（ADR-0074 §决策 5）。
      final FakeLogPrinter printer = FakeLogPrinter();
      final SecretStore store = UnsupportedSecretStore(
        logger: AppLogger(printer: printer),
      );

      final bool stored = await store.write('backup.password', 'secret');

      expect(stored, isFalse);
      expect(printer.events.single.message, contains('backup.password'));
    });

    test('delete_givenNoKeyStore_isANoOp', () async {
      expect(
        await UnsupportedSecretStore(logger: AppLogger()).delete('k'),
        isTrue,
      );
    });
  });

  group('FlutterSecureStorageSecretStore with the plugin defaults', () {
    test('read_write_delete_goThroughTheInjectedPlugin', () async {
      // 默认回调（`storage.read/write/delete`）只在真机上走：这里用一个假插件跑一遍，
      // 保证那三条闭包不是「只在设备上执行」的死行（C-TEST-1 的 100% 门禁要求）。
      final _FakePluginStorage plugin = _FakePluginStorage();
      final SecretStore store = FlutterSecureStorageSecretStore(
        storage: plugin,
      );

      expect(await store.write('k', 'v'), isTrue);
      expect(await store.read('k'), 'v');
      expect(await store.delete('k'), isTrue);
      expect(plugin.calls, <String>['write|k=v', 'read|k', 'delete|k']);
    });
  });

  group('FlutterSecureStorageSecretStore', () {
    test('read_givenAStoredValue_answersIt', () async {
      final SecretStore store = FlutterSecureStorageSecretStore(
        read: (String key) async => 'stored-$key',
      );

      expect(await store.read('backup.password'), 'stored-backup.password');
    });

    test('write_givenAWorkingStore_answersStored', () async {
      String? written;
      final SecretStore store = FlutterSecureStorageSecretStore(
        write: (String key, String value) async => written = '$key=$value',
      );

      expect(await store.write('backup.password', 'p'), isTrue);
      expect(written, 'backup.password=p');
    });

    test('delete_givenAWorkingStore_answersDeleted', () async {
      final SecretStore store = FlutterSecureStorageSecretStore(
        delete: (String key) async {},
      );

      expect(await store.delete('backup.password'), isTrue);
    });

    test('read_givenAPlatformFailure_answersNullAndWarns', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final SecretStore store = FlutterSecureStorageSecretStore(
        logger: AppLogger(printer: printer),
        read: (String key) async => throw PlatformException(code: 'boom'),
      );

      expect(await store.read('k'), isNull);
      expect(printer.events.single.message, contains('Reading'));
    });

    test('write_givenAPlatformFailure_answersNotStoredAndWarns', () async {
      // 企业策略禁用 Keystore / CI 没有 DPAPI：口令存不下，备份只能不加密。
      final FakeLogPrinter printer = FakeLogPrinter();
      final SecretStore store = FlutterSecureStorageSecretStore(
        logger: AppLogger(printer: printer),
        write: (String key, String value) async =>
            throw PlatformException(code: 'boom'),
      );

      expect(await store.write('k', 'v'), isFalse);
      expect(printer.events.single.message, contains('Writing'));
    });

    test('delete_givenAPlatformFailure_answersNotDeletedAndWarns', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final SecretStore store = FlutterSecureStorageSecretStore(
        logger: AppLogger(printer: printer),
        delete: (String key) async => throw PlatformException(code: 'boom'),
      );

      expect(await store.delete('k'), isFalse);
      expect(printer.events.single.message, contains('Deleting'));
    });
  });
}

/// A [FlutterSecureStorage] whose three calls are recorded instead of hitting a platform channel.
final class _FakePluginStorage extends FlutterSecureStorage {
  _FakePluginStorage();

  final List<String> calls = <String>[];
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    calls.add('read|$key');

    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    calls.add('write|$key=$value');
    if (value != null) {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    calls.add('delete|$key');
    values.remove(key);
  }
}
