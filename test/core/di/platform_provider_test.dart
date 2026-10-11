import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
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
}
