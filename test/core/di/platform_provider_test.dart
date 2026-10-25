import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/backup_directory_picker.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_directory_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_saver.dart';
import 'package:flutter_reader/core/platform/flutter_secure_storage_secret_store.dart';
import 'package:flutter_reader/core/platform/json_file_picker.dart';
import 'package:flutter_reader/core/platform/json_file_saver.dart';
import 'package:flutter_reader/core/platform/long_running_task.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';
import 'package:flutter_reader/core/platform/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../support/fake_platform_info.dart';

void main() {
  group('platformInfo', () {
    test('platformInfo_whenRead_returnsTheSystemImplementation', () {
      final ProviderContainer container = ProviderContainer.test();

      expect(container.read(platformInfoProvider), isA<SystemPlatformInfo>());
    });
  });

  group('platformDynamicColor', () {
    test(
      'platformDynamicColor_whenPlatformIsAndroid_returnsTheSystemProvider',
      () {
        final ProviderContainer container = ProviderContainer.test(
          overrides: <Override>[
            platformInfoProvider.overrideWithValue(
              const FakePlatformInfo.android(),
            ),
          ],
        );

        expect(
          container.read(platformDynamicColorProvider),
          isA<SystemDynamicColorProvider>(),
        );
      },
    );

    test('platformDynamicColor_whenPlatformIsDesktop_returnsNull', () {
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.desktop(),
          ),
        ],
      );

      expect(container.read(platformDynamicColorProvider), isNull);
    });
  });

  group('jsonFilePicker', () {
    test('jsonFilePicker_givenAShippedPlatform_usesTheRealDialog', () {
      // 三端（Android / iOS / Windows）都有官方实现，所以取真实选择器。
      for (final FakePlatformInfo platform in <FakePlatformInfo>[
        const FakePlatformInfo.android(),
        const FakePlatformInfo.ios(),
        const FakePlatformInfo.desktop(),
      ]) {
        final ProviderContainer container = ProviderContainer.test(
          overrides: <Override>[
            platformInfoProvider.overrideWithValue(platform),
          ],
        );

        expect(
          container.read(jsonFilePickerProvider),
          isA<FileSelectorJsonFilePicker>(),
        );
      }
    });

    test('jsonFilePicker_givenAnUnshippedPlatform_fallsBack', () {
      // platform.md §2：不支持的平台给 no-op 实现（答「没选」），而不是抛异常。
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.unsupported(),
          ),
        ],
      );

      expect(
        container.read(jsonFilePickerProvider),
        isA<UnsupportedJsonFilePicker>(),
      );
    });
  });
  group('jsonFileSaver', () {
    test('jsonFileSaver_givenAShippedPlatform_usesTheRealDialog', () {
      for (final FakePlatformInfo platform in <FakePlatformInfo>[
        const FakePlatformInfo.android(),
        const FakePlatformInfo.ios(),
        const FakePlatformInfo.desktop(),
      ]) {
        final ProviderContainer container = ProviderContainer.test(
          overrides: <Override>[
            platformInfoProvider.overrideWithValue(platform),
          ],
        );

        expect(
          container.read(jsonFileSaverProvider),
          isA<FileSelectorJsonFileSaver>(),
        );
      }
    });

    test('jsonFileSaver_givenAnUnshippedPlatform_doesNotSave', () async {
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.unsupported(),
          ),
        ],
      );

      expect(
        container.read(jsonFileSaverProvider),
        isA<UnsupportedJsonFileSaver>(),
      );
      // 没对话框的平台 = 用户取消：`ParseSuccess(false)`，不是失败。
      final ParseResult<bool> saved = await container
          .read(jsonFileSaverProvider)
          .save(suggestedName: 'a.json', contents: '{}');
      expect((saved as ParseSuccess<bool>).data, isFalse);
    });
  });

  group('backupArchiveSaver', () {
    test('backupArchiveSaver_givenAShippedPlatform_usesTheRealDialog', () {
      for (final FakePlatformInfo platform in <FakePlatformInfo>[
        const FakePlatformInfo.android(),
        const FakePlatformInfo.ios(),
        const FakePlatformInfo.desktop(),
      ]) {
        final ProviderContainer container = ProviderContainer.test(
          overrides: <Override>[
            platformInfoProvider.overrideWithValue(platform),
          ],
        );

        expect(
          container.read(backupArchiveSaverProvider),
          isA<FileSelectorBackupArchiveSaver>(),
        );
      }
    });

    test('backupArchiveSaver_givenAnUnshippedPlatform_doesNotSave', () async {
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.unsupported(),
          ),
        ],
      );

      final BackupArchiveSaver saver = container.read(
        backupArchiveSaverProvider,
      );
      expect(saver, isA<UnsupportedBackupArchiveSaver>());
      final ParseResult<bool> saved = await saver.save(
        suggestedName: 'backup.zip',
        bytes: <int>[1],
      );
      expect((saved as ParseSuccess<bool>).data, isFalse);
    });
  });

  group('backupArchivePicker', () {
    test('backupArchivePicker_givenAShippedPlatform_usesTheRealDialog', () {
      for (final FakePlatformInfo platform in <FakePlatformInfo>[
        const FakePlatformInfo.android(),
        const FakePlatformInfo.ios(),
        const FakePlatformInfo.desktop(),
      ]) {
        final ProviderContainer container = ProviderContainer.test(
          overrides: <Override>[
            platformInfoProvider.overrideWithValue(platform),
          ],
        );

        expect(
          container.read(backupArchivePickerProvider),
          isA<FileSelectorBackupArchivePicker>(),
        );
      }
    });

    test('backupArchivePicker_givenAnUnshippedPlatform_picksNothing', () async {
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.unsupported(),
          ),
        ],
      );

      final BackupArchivePicker picker = container.read(
        backupArchivePickerProvider,
      );
      expect(picker, isA<UnsupportedBackupArchivePicker>());
      expect((await picker.pick(maxBytes: 8)).dataOrNull, isNull);
    });
  });

  group('secretStore', () {
    test('secretStore_givenAShippedPlatform_usesThePlatformKeyStore', () {
      for (final FakePlatformInfo platform in <FakePlatformInfo>[
        const FakePlatformInfo.android(),
        const FakePlatformInfo.ios(),
        const FakePlatformInfo.desktop(),
      ]) {
        final ProviderContainer container = ProviderContainer.test(
          overrides: <Override>[
            platformInfoProvider.overrideWithValue(platform),
          ],
        );

        expect(
          container.read(secretStoreProvider),
          isA<FlutterSecureStorageSecretStore>(),
        );
      }
    });

    test('secretStore_givenAnUnshippedPlatform_doesNotStore', () async {
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.unsupported(),
          ),
        ],
      );

      final SecretStore store = container.read(secretStoreProvider);
      expect(store, isA<UnsupportedSecretStore>());
      expect(await store.write('k', 'v'), isFalse);
      expect(await store.read('k'), isNull);
    });
  });

  group('backupDirectoryPicker', () {
    test('backupDirectoryPicker_givenAShippedPlatform_usesTheRealDialog', () {
      for (final FakePlatformInfo platform in <FakePlatformInfo>[
        const FakePlatformInfo.android(),
        const FakePlatformInfo.ios(),
        const FakePlatformInfo.desktop(),
      ]) {
        final ProviderContainer container = ProviderContainer.test(
          overrides: <Override>[
            platformInfoProvider.overrideWithValue(platform),
          ],
        );

        expect(
          container.read(backupDirectoryPickerProvider),
          isA<FileSelectorBackupDirectoryPicker>(),
        );
      }
    });

    test(
      'backupDirectoryPicker_givenAnUnshippedPlatform_picksNothing',
      () async {
        final ProviderContainer container = ProviderContainer.test(
          overrides: <Override>[
            platformInfoProvider.overrideWithValue(
              const FakePlatformInfo.unsupported(),
            ),
          ],
        );

        final BackupDirectoryPicker picker = container.read(
          backupDirectoryPickerProvider,
        );
        expect(picker, isA<UnsupportedBackupDirectoryPicker>());
        expect((await picker.pick()).dataOrNull, isNull);
      },
    );
  });

  group('longRunningTask', () {
    test('longRunningTask_whenPlatformIsAndroid_holdsAWakeLock', () {
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.android(),
          ),
        ],
      );

      expect(
        container.read(longRunningTaskProvider),
        isA<MethodChannelLongRunningTask>(),
      );
    });

    test('longRunningTask_whenPlatformIsDesktop_isTheNoOpPort', () {
      // platform.md §2 / §7：没有该能力的平台给 no-op，调用方不必判断平台。
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.desktop(),
          ),
        ],
      );

      final LongRunningTask task = container.read(longRunningTaskProvider);

      expect(task, isA<UnsupportedLongRunningTask>());
      expect(task.isSupported, isFalse);
    });
  });
}
