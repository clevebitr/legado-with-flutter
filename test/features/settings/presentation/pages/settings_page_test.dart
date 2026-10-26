import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/platform/background_image_picker.dart';
import 'package:flutter_reader/core/storage/local_image_store.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_reader/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_settings_repository.dart';
import '../../../../support/offline_corpus.dart';

/// The localization the settings page sees.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(SettingsPage));

void main() {
  group('SettingsPage', () {
    late FakeSettingsRepository repository;
    late FakeCachePurger purger;

    setUp(() {
      repository = FakeSettingsRepository();
      purger = FakeCachePurger();
    });

    /// Pumps the page against the doubles.
    Future<void> pump(
      WidgetTester tester, {
      BackgroundImagePicker? imagePicker,
      LocalImageStore? imageStore,
    }) => pumpSettingsPage(
      tester,
      page: const SettingsPage(),
      repository: repository,
      purger: purger,
      imagePicker: imagePicker,
      imageStore: imageStore,
    );

    testWidgets('page_whenOpened_showsTheThreeThemeModes', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.settingsTitle), findsOneWidget);
      expect(find.text(l10n.settingsThemeSystem), findsOneWidget);
      expect(find.text(l10n.settingsThemeLight), findsOneWidget);
      expect(find.text(l10n.settingsThemeDark), findsOneWidget);
    });

    testWidgets('page_whenASeedColourIsChosen_storesIt', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final Color preset = themeSeedPresets().first;

      await tester.tap(
        find.byKey(ValueKey<String>('seedColor-${preset.toARGB32()}')),
      );
      await tester.pumpAndSettle();

      expect(repository.stored.seedColor, preset.toARGB32());
    });

    testWidgets('page_whenTheDefaultSeedIsChosen_clearsIt', (
      WidgetTester tester,
    ) async {
      repository = FakeSettingsRepository(
        initial: AppSettings(seedColor: 0xFF112233),
      );
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey<String>('seedColor-default')));
      await tester.pumpAndSettle();

      expect(repository.stored.seedColor, isNull);
    });

    testWidgets('page_givenNoBackground_saysSo', (WidgetTester tester) async {
      await pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.settingsBackgroundImageNone), findsOneWidget);
      expect(find.text(l10n.settingsBackgroundImageRemove), findsNothing);
    });

    testWidgets('page_whenABackgroundIsPicked_copiesItAndStoresTheName', (
      WidgetTester tester,
    ) async {
      final Directory support = await tester.runAsync(
        () => Directory.systemTemp.createTemp('bg'),
      ) as Directory;
      addTearDown(() => support.delete(recursive: true));
      await pump(
        tester,
        imagePicker: const _FakeImagePicker(),
        imageStore: LocalImageStore(supportDirectory: () async => support),
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.text(l10n.settingsBackgroundImageChoose));
      await tester.pump();
      // 复制图片是真实文件 IO：假时钟等不到它，要给真实事件循环几轮。
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (repository.stored.backgroundImageName != null) {
          break;
        }
      }
      await tester.pumpAndSettle();

      expect(repository.stored.backgroundImageName, 'background.png');
      expect(find.text('background.png'), findsOneWidget);
      expect(find.text(l10n.settingsBackgroundImageRemove), findsOneWidget);
    });

    testWidgets('page_whenTheBackgroundIsRemoved_dropsIt', (
      WidgetTester tester,
    ) async {
      final Directory support = await tester.runAsync(
        () => Directory.systemTemp.createTemp('bg'),
      ) as Directory;
      addTearDown(() => support.delete(recursive: true));
      repository = FakeSettingsRepository(
        initial: AppSettings(backgroundImageName: 'background.png'),
      );
      await pump(
        tester,
        imagePicker: const _FakeImagePicker(),
        imageStore: LocalImageStore(supportDirectory: () async => support),
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.text(l10n.settingsBackgroundImageRemove));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(repository.stored.backgroundImageName, isNull);
    });

    testWidgets('page_whenDarkIsChosen_storesIt', (WidgetTester tester) async {
      await pump(tester);

      await tester.tap(find.text(_l10n(tester).settingsThemeDark));
      await tester.pumpAndSettle();

      expect(repository.stored.themeMode, AppThemeMode.dark);
    });

    testWidgets('page_whenTheBudgetIsRaised_storesTheNextValue', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final int before = repository.stored.maxConcurrentPerSource;

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(repository.stored.maxConcurrentPerSource, before + 1);
    });

    testWidgets('page_whenTheBudgetIsAtTheFloor_disablesDecrease', (
      WidgetTester tester,
    ) async {
      repository = FakeSettingsRepository(
        initial: AppSettings(maxConcurrentPerSource: minConcurrentBudget),
      );
      await pump(tester);

      // 不许点出 0：`RequestLimiter` 会因此让该源的每个请求永久排队（roadmap §3.7）。
      final IconButton decrease = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove),
      );
      expect(decrease.onPressed, isNull);
    });

    testWidgets('page_whenPlainHttpIsTurnedOn_storesIt', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      expect(repository.stored.allowPlainHttp, isFalse);
      await tester.tap(find.text(l10n.settingsPlainHttp));
      await tester.pumpAndSettle();

      expect(repository.stored.allowPlainHttp, isTrue);
    });

    testWidgets('page_whenTheCacheIsCleared_showsTheCount', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.text(l10n.settingsClearCache));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionDelete));
      await tester.pumpAndSettle();

      expect(purger.calls, 1);
      expect(find.text(l10n.settingsCacheCleared(3)), findsOneWidget);
    });

    testWidgets('page_whenTheLoadFails_showsTheFailure', (
      WidgetTester tester,
    ) async {
      repository.fail = true;

      await pump(tester);

      expect(find.text(_l10n(tester).settingsLoadFailed), findsOneWidget);
    });
  });
}

/// A picker that always answers one small image.
final class _FakeImagePicker implements BackgroundImagePicker {
  const _FakeImagePicker();

  @override
  Future<PickedBackgroundImage?> pick() async =>
      const PickedBackgroundImage(name: 'sky.png', bytes: <int>[1, 2, 3]);
}
