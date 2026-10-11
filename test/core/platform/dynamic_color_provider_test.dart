import 'package:flutter/material.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_platform_info.dart';

void main() {
  group('resolveDynamicColorProvider', () {
    test(
      'resolveDynamicColorProvider_whenPlatformIsAndroid_returnsSystemProvider',
      () {
        expect(
          resolveDynamicColorProvider(const FakePlatformInfo.android()),
          isA<SystemDynamicColorProvider>(),
        );
      },
    );

    test('resolveDynamicColorProvider_whenPlatformIsIos_returnsNull', () {
      // platform.md §3：iOS 不支持动态取色，走默认种子色（C-PLT-4）。
      expect(resolveDynamicColorProvider(const FakePlatformInfo.ios()), isNull);
    });

    test('resolveDynamicColorProvider_whenPlatformIsDesktop_returnsNull', () {
      expect(
        resolveDynamicColorProvider(const FakePlatformInfo.desktop()),
        isNull,
      );
    });
  });

  group('SystemDynamicColorProvider', () {
    testWidgets(
      'resolve_whenPlatformHasNoDynamicColor_handsNullSchemesToTheBuilder',
      (WidgetTester tester) async {
        ColorScheme? lightScheme;
        ColorScheme? darkScheme;

        await tester.pumpWidget(
          const SystemDynamicColorProvider().resolve((
            ColorScheme? light,
            ColorScheme? dark,
          ) {
            lightScheme = light;
            darkScheme = dark;
            return const SizedBox.shrink();
          }),
        );
        await tester.pumpAndSettle();

        expect(lightScheme, isNull);
        expect(darkScheme, isNull);
      },
    );
  });
}
