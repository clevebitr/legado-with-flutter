import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'support/fake_platform_info.dart';

void main() {
  testWidgets('ReaderApp_whenPlatformHasNoDynamicColor_rendersFallbackTheme', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // testing.md §5：固定种子色并禁用动态取色。
        overrides: <Override>[
          platformDynamicColorProvider.overrideWithValue(null),
        ],
        child: const ReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(
      find.text('Book sources'),
      findsOneWidget,
      reason: 'The English template locale should be used in tests.',
    );
  });

  testWidgets('ReaderApp_whenPlatformIsAndroid_rendersWithTheSeedFallback', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // 测试环境没有动态取色通道，Android 分支同样落到种子色；
        // 这里断言的是接线不会崩溃、也不会出现空屏（C-PLT-3/4）。
        overrides: <Override>[
          platformInfoProvider.overrideWithValue(
            const FakePlatformInfo.android(),
          ),
        ],
        child: const ReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Book sources'), findsOneWidget);
  });
}
