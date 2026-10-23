import 'package:flutter/material.dart';
import 'package:flutter_reader/app_shell.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/search_books_page.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_reader/features/bookshelf/presentation/pages/bookshelf_page.dart';
import 'package:flutter_reader/features/shell/presentation/pages/my_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'support/fake_book_source_repository.dart';
import 'support/fake_book_source_view_store.dart';
import 'support/fake_bookshelf_repository.dart';

/// Pumps the shell with the repository doubles the four tabs need.
Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
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
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The bottom-navigation label, not the same text in a page's app bar.
Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  group('AppShell', () {
    testWidgets('build_givenNoInteraction_opensOnTheShelf', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppShell)),
      );

      expect(find.byType(BookshelfPage, skipOffstage: false), findsOneWidget);
      expect(find.byType(MyPage, skipOffstage: false), findsOneWidget);
      // IndexedStack 让四个页面同时存活：切走再回来不重拉数据（ADR-0055 §决策 2）。
      expect(find.byType(SearchBooksPage, skipOffstage: false), findsOneWidget);
      expect(_tab(l10n.shellTabBookshelf), findsOneWidget);
    });

    testWidgets('tap_whenTheMeTabIsChosen_showsTheEntryPointPage', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppShell)),
      );

      await tester.tap(_tab(l10n.shellTabMy));
      await tester.pumpAndSettle();

      // 「我的」页的入口只有在被选中时才可见（IndexedStack 的可见性）。
      expect(find.text(l10n.myBookSources), findsOneWidget);
    });
  });
}
