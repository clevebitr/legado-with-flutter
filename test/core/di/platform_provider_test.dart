import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/background_image_picker.dart';
import 'package:flutter_reader/core/platform/backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/backup_directory_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_background_image_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_directory_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_saver.dart';
import 'package:flutter_reader/core/platform/file_sharer.dart';
import 'package:flutter_reader/core/platform/flutter_secure_storage_secret_store.dart';
import 'package:flutter_reader/core/platform/json_file_picker.dart';
import 'package:flutter_reader/core/platform/json_file_saver.dart';
import 'package:flutter_reader/core/platform/long_running_task.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';
import 'package:flutter_reader/core/platform/secret_store.dart';
import 'package:flutter_reader/core/platform/share_plus_file_sharer.dart';
import 'package:flutter_reader/core/platform/sharing_backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/sharing_json_file_saver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../support/fake_platform_info.dart';

/// One platform-backed port: its name, the implementation a shipped platform
/// must get, and how to read it from a container.
typedef _Port = (String, Type, Object Function(ProviderContainer));

/// The three platforms the app ships, keyed by the fake that reports them.
const Map<String, FakePlatformInfo> _shippedPlatforms =
    <String, FakePlatformInfo>{
      'android': FakePlatformInfo.android(),
      'ios': FakePlatformInfo.ios(),
      'desktop': FakePlatformInfo.desktop(),
    };

/// Ports whose real implementation is available on every shipped platform.
const List<_Port> _dialogPorts = <_Port>[
  ('jsonFilePicker', FileSelectorJsonFilePicker, _jsonFilePicker),
  ('backupArchivePicker', FileSelectorBackupArchivePicker, _archivePicker),
  (
    'backupDirectoryPicker',
    FileSelectorBackupDirectoryPicker,
    _directoryPicker,
  ),
  ('backgroundImagePicker', FileSelectorBackgroundImagePicker, _imagePicker),
  ('secretStore', FlutterSecureStorageSecretStore, _secretStore),
];

Object _jsonFilePicker(ProviderContainer container) =>
    container.read(jsonFilePickerProvider);
Object _jsonFileSaver(ProviderContainer container) =>
    container.read(jsonFileSaverProvider);
Object _archiveSaver(ProviderContainer container) =>
    container.read(backupArchiveSaverProvider);
Object _fileSharer(ProviderContainer container) =>
    container.read(fileSharerProvider);
Object _archivePicker(ProviderContainer container) =>
    container.read(backupArchivePickerProvider);
Object _directoryPicker(ProviderContainer container) =>
    container.read(backupDirectoryPickerProvider);
Object _imagePicker(ProviderContainer container) =>
    container.read(backgroundImagePickerProvider);
Object _secretStore(ProviderContainer container) =>
    container.read(secretStoreProvider);

/// A container whose platform is [platform].
ProviderContainer _containerFor(PlatformInfo platform) =>
    ProviderContainer.test(
      overrides: <Override>[platformInfoProvider.overrideWithValue(platform)],
    );

const FakePlatformInfo _android = FakePlatformInfo.android();
const FakePlatformInfo _desktop = FakePlatformInfo.desktop();
const FakePlatformInfo _unsupported = FakePlatformInfo.unsupported();

void main() {
  test('platformInfo_whenRead_returnsTheSystemImplementation', () {
    expect(
      ProviderContainer.test().read(platformInfoProvider),
      isA<SystemPlatformInfo>(),
    );
  });

  test('dialogPorts_givenAShippedPlatform_useTheRealDialogOrKeyStore', () {
    // 三端（Android / iOS / Windows 桌面）都有官方实现，所以取真实端口。
    for (final MapEntry<String, FakePlatformInfo> platform
        in _shippedPlatforms.entries) {
      final ProviderContainer container = _containerFor(platform.value);

      for (final _Port port in _dialogPorts) {
        expect(
          port.$3(container).runtimeType,
          port.$2,
          reason: '${port.$1} on ${platform.key}',
        );
      }
    }
  });

  test('fileExportPorts_givenAMobilePlatform_shareInsteadOfSaving', () {
    // Android / iOS 没有保存对话框（file_selector 的 getSaveLocation 未实现），
    // 导出改走系统分享（ADR-0083 §决策 1）。
    for (final MapEntry<String, FakePlatformInfo> platform
        in _shippedPlatforms.entries) {
      final ProviderContainer container = _containerFor(platform.value);
      final bool isMobile = !platform.value.isDesktop;

      expect(
        _jsonFileSaver(container).runtimeType,
        isMobile ? SharingJsonFileSaver : FileSelectorJsonFileSaver,
        reason: 'jsonFileSaver on ${platform.key}',
      );
      expect(
        _archiveSaver(container).runtimeType,
        isMobile ? SharingBackupArchiveSaver : FileSelectorBackupArchiveSaver,
        reason: 'backupArchiveSaver on ${platform.key}',
      );
      expect(
        _fileSharer(container).runtimeType,
        isMobile ? SharePlusFileSharer : UnsupportedFileSharer,
        reason: 'fileSharer on ${platform.key}',
      );
    }
  });

  group('unsupported platform', () {
    test('filePorts_answerNotSavedInsteadOfThrowing', () async {
      // platform.md §2：没有该能力的平台给 no-op 实现，调用方不必判断平台。
      final ProviderContainer container = _containerFor(_unsupported);

      expect(
        container.read(jsonFileSaverProvider),
        isA<UnsupportedJsonFileSaver>(),
      );
      expect(container.read(fileSharerProvider), isA<UnsupportedFileSharer>());
      final ParseResult<bool> saved = await container
          .read(jsonFileSaverProvider)
          .save(suggestedName: 'a.json', contents: '{}');
      // 没对话框的平台 = 用户取消：`ParseSuccess(false)`，不是失败。
      expect((saved as ParseSuccess<bool>).data, isFalse);

      expect(
        container.read(jsonFilePickerProvider),
        isA<UnsupportedJsonFilePicker>(),
      );
      // JSON 导入走「解析失败」而不是「空数据」，由调用方显示导入错误。
      expect(
        (await container.read(jsonFilePickerProvider).pick(maxBytes: 8))
            .dataOrNull,
        isNull,
      );
    });

    test('backupPorts_pickAndSaveNothing', () async {
      final ProviderContainer container = _containerFor(_unsupported);

      expect(
        container.read(backupArchiveSaverProvider),
        isA<UnsupportedBackupArchiveSaver>(),
      );
      final ParseResult<bool> saved = await container
          .read(backupArchiveSaverProvider)
          .save(suggestedName: 'backup.zip', bytes: <int>[1]);
      expect((saved as ParseSuccess<bool>).data, isFalse);

      expect(
        container.read(backupArchivePickerProvider),
        isA<UnsupportedBackupArchivePicker>(),
      );
      expect(
        (await container.read(backupArchivePickerProvider).pick(maxBytes: 8))
            .dataOrNull,
        isNull,
      );

      expect(
        container.read(backupDirectoryPickerProvider),
        isA<UnsupportedBackupDirectoryPicker>(),
      );
      expect(
        (await container.read(backupDirectoryPickerProvider).pick()).dataOrNull,
        isNull,
      );

      expect(
        container.read(backgroundImagePickerProvider),
        isA<UnsupportedBackgroundImagePicker>(),
      );
      expect(
        await container.read(backgroundImagePickerProvider).pick(),
        isNull,
      );
    });

    test('secretStore_forgetsEverything', () async {
      final ProviderContainer container = _containerFor(_unsupported);

      final SecretStore store = container.read(secretStoreProvider);

      expect(store, isA<UnsupportedSecretStore>());
      expect(await store.write('k', 'v'), isFalse);
      expect(await store.read('k'), isNull);
    });
  });

  group('longRunningTask', () {
    test('longRunningTask_whenPlatformIsAndroid_holdsAWakeLock', () {
      expect(
        _containerFor(_android).read(longRunningTaskProvider),
        isA<MethodChannelLongRunningTask>(),
      );
    });

    test('longRunningTask_whenPlatformIsDesktop_isTheNoOpPort', () {
      // platform.md §2 / §7：没有该能力的平台给 no-op，调用方不必判断平台。
      final LongRunningTask task = _containerFor(_desktop)
          .read(longRunningTaskProvider);

      expect(task, isA<UnsupportedLongRunningTask>());
      expect(task.isSupported, isFalse);
    });
  });
}
