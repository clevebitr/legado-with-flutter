import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_detail_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_import_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_list_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/explore_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/reader_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/search_books_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: wires theming, localization and the route table.
///
/// Dynamic color is resolved through `core/platform/`, so this file never talks to
/// `dynamic_color` nor asks which platform it runs on (C-PLT-1, C-PLT-2).
class ReaderApp extends ConsumerWidget {
  /// Creates the root widget.
  const ReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DynamicColorProvider? dynamicColor = ref.watch(
      platformDynamicColorProvider,
    );

    // 平台没有动态取色（Windows/iOS/测试）时直接走种子色 fallback（C-PLT-3/4）。
    return dynamicColor?.resolve(_buildApp) ?? _buildApp(null, null);
  }

  /// The app's page table: a typed route of the table becomes a page (ADR-0011).
  ///
  /// It lives in the composition root rather than in `core/router/`, because `core/`
  /// must not import `features/` (`docs/dev/architecture.md` §2) while the typed
  /// routes carry feature entities. The search page is also the landing page: the
  /// initial route carries no arguments, and unknown arguments fall back to it
  /// instead of tripping an assertion.
  static Widget _pageFor(Object? arguments) => switch (arguments) {
    ExploreRoute() => const ExplorePage(),
    BookSourceListRoute() => const BookSourceListPage(),
    BookSourceImportRoute() => const BookSourceImportPage(),
    final BookDetailRoute route => BookDetailPage(book: route.book),
    final ReaderRoute route => ReaderPage(chapter: route.chapter),
    _ => const SearchBooksPage(),
  };

  /// Builds the [MaterialApp] from the resolved platform schemes.
  ///
  /// A `null` scheme means "the platform has none", which is the normal fallback
  /// branch and never an error (C-TYPE-2, ADR-0004 §6).
  Widget _buildApp(ColorScheme? lightDynamic, ColorScheme? darkDynamic) =>
      MaterialApp(
        onGenerateTitle: (BuildContext context) =>
            AppLocalizations.of(context).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(lightDynamic ?? fallbackLightColorScheme()),
        darkTheme: buildReaderTheme(darkDynamic ?? fallbackDarkColorScheme()),
        initialRoute: AppRouter.homePath,
        onGenerateRoute: (RouteSettings settings) =>
            const AppRouter().onGenerateRoute(settings, pageFor: _pageFor),
      );
}
