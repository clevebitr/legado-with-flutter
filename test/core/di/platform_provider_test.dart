import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/book_source_file_picker.dart';
import 'package:flutter_reader/core/platform/book_source_file_saver.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/platform/file_selector_book_source_file_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_book_source_file_saver.dart';
import 'package:flutter_reader/core/platform/long_running_task.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';
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

  group('bookSourceFilePicker', () {
    test('bookSourceFilePicker_givenAShippedPlatform_usesTheRealDialog', () {
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
          container.read(bookSourceFilePickerProvider),
          isA<FileSelectorBookSourceFilePicker>(),
        );
      }
    });

    test('bookSourceFilePicker_givenAnUnshippedPlatform_fallsBack', () {
      // platform.md §2：不支持的平台给 no-op 实现（答「没选」），而不是抛异常。
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.unsupported(),
          ),
        ],
      );

      expect(
        container.read(bookSourceFilePickerProvider),
        isA<UnsupportedBookSourceFilePicker>(),
      );
    });
  });
  group('bookSourceFileSaver', () {
    test('bookSourceFileSaver_givenAShippedPlatform_usesTheRealDialog', () {
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
          container.read(bookSourceFileSaverProvider),
          isA<FileSelectorBookSourceFileSaver>(),
        );
      }
    });

    test('bookSourceFileSaver_givenAnUnshippedPlatform_doesNotSave', () async {
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.unsupported(),
          ),
        ],
      );

      expect(
        container.read(bookSourceFileSaverProvider),
        isA<UnsupportedBookSourceFileSaver>(),
      );
      // 没对话框的平台 = 用户取消：`ParseSuccess(false)`，不是失败。
      final ParseResult<bool> saved = await container
          .read(bookSourceFileSaverProvider)
          .save(suggestedName: 'a.json', contents: '{}');
      expect((saved as ParseSuccess<bool>).data, isFalse);
    });
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
