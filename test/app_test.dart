import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_reader/app_shell.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'support/fake_book_source_repository.dart';
import 'support/fake_book_source_view_store.dart';
import 'support/fake_bookshelf_repository.dart';
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
          // 外壳会同时构建四个 tab：宿主 VM 里的真实 Drift 读不出来，
          // 用端口替身让每个 tab 都能落到「有数据 / 空态」而不是永久 spinner（testing.md §4）。
          bookSourceRepositoryProvider.overrideWithValue(
            FakeBookSourceRepository(),
          ),
          bookSourceViewStoreProvider.overrideWith(
            (Ref ref) async => FakeBookSourceViewStore(),
          ),
          bookshelfRepositoryProvider.overrideWithValue(
            FakeBookshelfRepository(),
          ),
        ],
        child: const ReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    // 落地路由是应用外壳（ADR-0055 §决策 5），默认停在书架 tab。
    expect(find.byType(AppShell), findsOneWidget);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppShell)),
    );
    expect(find.text(l10n.shellTabBookshelf), findsOneWidget);
    expect(find.text(l10n.shellTabMy), findsOneWidget);
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
          bookSourceRepositoryProvider.overrideWithValue(
            FakeBookSourceRepository(),
          ),
          bookSourceViewStoreProvider.overrideWith(
            (Ref ref) async => FakeBookSourceViewStore(),
          ),
          bookshelfRepositoryProvider.overrideWithValue(
            FakeBookshelfRepository(),
          ),
        ],
        child: const ReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
  });
}
