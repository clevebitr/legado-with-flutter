import 'package:flutter/material.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_platform_info.dart';

void main() {
  test('resolveDynamicColorProvider_givenThePlatform_answersItsPort', () {
    // platform.md §3 / C-PLT-4：只有 Android 支持动态取色；iOS 与桌面走默认种子色
    // （null 表示「不用系统取色」）。
    const Map<String, (FakePlatformInfo, Type?)> cases =
        <String, (FakePlatformInfo, Type?)>{
          'android': (FakePlatformInfo.android(), SystemDynamicColorProvider),
          'ios': (FakePlatformInfo.ios(), null),
          'desktop': (FakePlatformInfo.desktop(), null),
        };

    for (final MapEntry<String, (FakePlatformInfo, Type?)> entry
        in cases.entries) {
      final DynamicColorProvider? resolved = resolveDynamicColorProvider(
        entry.value.$1,
      );

      expect(resolved?.runtimeType, entry.value.$2, reason: entry.key);
    }
  });

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
}
