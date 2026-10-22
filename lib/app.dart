import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/router/app_navigation.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_detail_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_check_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_debug_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_edit_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_import_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_list_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/explore_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/search_books_page.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/presentation/bookshelf_route.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/bookshelf_notifier.dart';
import 'package:flutter_reader/features/bookshelf/presentation/pages/bookshelf_page.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
import 'package:flutter_reader/features/reader/presentation/pages/reader_page.dart';
import 'package:flutter_reader/features/reader/presentation/reader_route.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_reader/features/settings/presentation/notifiers/settings_notifier.dart';
import 'package:flutter_reader/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter_reader/features/settings/presentation/settings_route.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// The composition root's provider overrides (ADR-0041 §决策 2, ADR-0042).
///
/// This is the **only** place that knows both sides of a cross-feature port: `book_source` declares
/// `BookshelfWriter` and `core` declares `AppNavigation`; the bindings below hand them the shelf's
/// and the settings' real implementations. Composing them here — and not inside either feature —
/// is what keeps `features/A` free of `features/B` imports (C-ARCH-2).
///
/// It is a function rather than a constant because two of the three bindings need a `Ref`.
List<Override> appProviderOverrides() => <Override>[
  appNavigationProvider.overrideWith((Ref ref) => const _RootNavigation()),
  bookshelfWriterProvider.overrideWith(_ShelfWriter.new),
  // 用户设置里的并发上限只影响请求层的策略，因此在**根**上把它接进 `core` 声明的位置；
  // `core` 自己不能 import `features/settings`（C-ARCH-2），而 `select` 保证改字号 / 主题
  // 不会重建 HttpPolicy（也就不会丢掉正在排队的预算）。
  concurrencySettingProvider.overrideWith(
    (Ref ref) => ref.watch(
      settingsProvider.select(
        (AsyncValue<AppSettings> value) => value.value?.maxConcurrentPerSource,
      ),
    ),
  ),
  // 阅读器的三个端口（ADR-0041 §决策 2、ADR-0044 §决策 2）：`reader` 声明、这里绑定到
  // `book_source` 的规则链路与 `bookshelf` 的进度表，两个 feature 之间零 import。
  readerChapterListProvider.overrideWith(_ChapterListSource.new),
  readerChapterContentProvider.overrideWith(_ChapterContentSource.new),
  readerProgressStoreProvider.overrideWith(_ProgressStore.new),
];

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
    // 设置还没读出来时用 defaults：主题与字号**不会**因为一次平台读盘而抖动成空白。
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? AppSettings.defaults;

    // 平台没有动态取色（Windows/iOS/测试）时直接走种子色 fallback（C-PLT-3/4）。
    return dynamicColor?.resolve(
          (ColorScheme? light, ColorScheme? dark) =>
              _buildApp(light, dark, settings),
        ) ??
        _buildApp(null, null, settings);
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
    BookSourceCheckRoute() => const BookSourceCheckPage(),
    final BookSourceDebugRoute route => BookSourceDebugPage(
      sourceId: route.sourceId,
    ),
    final BookSourceEditRoute route => BookSourceEditPage(
      sourceId: route.sourceId,
    ),
    ShelfRoute() => const BookshelfPage(),
    SettingsPageRoute() => const SettingsPage(),
    final BookDetailRoute route => BookDetailPage(book: route.book),
    final ReaderRoute route => ReaderPage(
      book: route.book,
      chapterUrl: route.chapterUrl,
    ),
    _ => const SearchBooksPage(),
  };

  /// Builds the [MaterialApp] from the resolved platform schemes and the user's settings.
  ///
  /// A `null` scheme means "the platform has none", which is the normal fallback
  /// branch and never an error (C-TYPE-2, ADR-0004 §6).
  ///
  /// The stored text scale is applied **on top of** the platform's own accessibility scale
  /// rather than replacing it, so a user who enlarged text system-wide keeps that and only adds
  /// the app's preference.
  Widget _buildApp(
    ColorScheme? lightDynamic,
    ColorScheme? darkDynamic,
    AppSettings settings,
  ) => MaterialApp(
    onGenerateTitle: (BuildContext context) =>
        AppLocalizations.of(context).appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildReaderTheme(lightDynamic ?? fallbackLightColorScheme()),
    darkTheme: buildReaderTheme(darkDynamic ?? fallbackDarkColorScheme()),
    themeMode: switch (settings.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    },
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.textScalerOf(context).scale(1) * settings.fontScale,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    ),
    initialRoute: AppRouter.homePath,
    onGenerateRoute: (RouteSettings settings) =>
        const AppRouter().onGenerateRoute(settings, pageFor: _pageFor),
  );
}

/// The app-level destinations, bound to the real pages (ADR-0042).
final class _RootNavigation implements AppNavigation {
  /// Creates the binding.
  const _RootNavigation();

  @override
  void openBookshelf(BuildContext context) =>
      pushBookshelfRoute(context, const BookshelfRoute.shelf());

  @override
  void openSettings(BuildContext context) =>
      pushSettingsRoute(context, const SettingsRoute.settings());

  /// Opens the reader on one book (ADR-0042 §决策 2, ADR-0044 §决策 2).
  ///
  /// The port carries primitives, so this is where they become the reader's own `ReaderBook` —
  /// the one place allowed to know two features' types (ADR-0041 §决策 3).
  @override
  void openReader(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    required String tocUrl,
    String? chapterUrl,
  }) => pushReaderRoute(
    context,
    ReaderRoute(
      book: ReaderBook(
        sourceUrl: sourceUrl,
        bookUrl: bookUrl,
        name: bookName,
        tocUrl: tocUrl,
      ),
      chapterUrl: chapterUrl,
    ),
  );
}

/// `BookshelfWriter` bound to the shelf feature (ADR-0041 §决策 2).
///
/// The mapping `ShelfBookDraft` → `ShelfCandidate` happens **here**, in the composition root:
/// it is the one place allowed to know both features' types (ADR-0041 §决策 3).
final class _ShelfWriter implements BookshelfWriter {
  const _ShelfWriter(this._ref);

  final Ref _ref;

  @override
  Future<ParseResult<void>> addToShelf(ShelfBookDraft draft) => _ref
      .read(bookshelfProvider.notifier)
      .add(
        ShelfCandidate(
          sourceUrl: draft.sourceUrl,
          bookUrl: draft.bookUrl,
          tocUrl: draft.tocUrl,
          canReName: draft.canReName,
          name: draft.name,
          author: draft.author,
          kind: draft.kind,
          coverUrl: draft.coverUrl,
          intro: draft.intro,
          lastChapter: draft.lastChapter,
        ),
      );
}

/// Resolves a stored book source by its URL, or `null` when it is gone.
///
/// The reader knows a source only by URL (it may not import `book_source`), so the adapter looks
/// the row up. A deleted source answers `null`, and the caller reports it as an invalid source
/// rather than reading with a rule set nobody has.
Future<BookSource?> _sourceByUrl(Ref ref, String sourceUrl) async {
  for (final StoredBookSource stored
      in await ref.read(bookSourceRepositoryProvider).getAll()) {
    if (stored.source.url == sourceUrl) {
      return stored.source;
    }
  }

  return null;
}

/// `ChapterListProvider` bound to `book_source`'s `FetchToc` (ADR-0041 §决策 2).
final class _ChapterListSource implements ChapterListProvider {
  const _ChapterListSource(this._ref);

  final Ref _ref;

  @override
  Future<ParseResult<List<ReadingChapter>>> fetch({
    required String sourceUrl,
    required String tocUrl,
    String bookName = '',
  }) async {
    final BookSource? source = await _sourceByUrl(_ref, sourceUrl);
    if (source == null) {
      return failureAt<List<ReadingChapter>>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'reader.chapterList',
      );
    }

    final ParseResult<List<Chapter>> result = await _ref
        .read(fetchTocProvider)
        .execute(source, tocUrl, bookName: bookName);

    return switch (result) {
      ParseSuccess<List<Chapter>>(:final List<Chapter> data) =>
        ParseSuccess<List<ReadingChapter>>(<ReadingChapter>[
          for (final Chapter chapter in data)
            ReadingChapter(title: chapter.name, url: chapter.url),
        ]),
      ParseFailure<List<Chapter>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<List<ReadingChapter>>(kind: kind, rulePath: rulePath),
    };
  }
}

/// `ChapterContentProvider` bound to `book_source`'s `FetchContent` (ADR-0041 §决策 2).
///
/// Going through the use case (and not a bare HTTP call) is what keeps the 5.2 body cache and the
/// `concurrentRate` budget in force for everything the reader reads.
final class _ChapterContentSource implements ChapterContentProvider {
  const _ChapterContentSource(this._ref);

  final Ref _ref;

  @override
  Future<ParseResult<String>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
  }) async {
    final BookSource? source = await _sourceByUrl(_ref, sourceUrl);
    if (source == null) {
      return failureAt<String>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'reader.chapterContent',
      );
    }

    return _ref
        .read(fetchContentProvider)
        .execute(
          source,
          ChapterRequest(
            url: chapterUrl,
            title: chapterTitle,
            bookName: bookName,
          ),
        );
  }
}

/// `ReadingProgressStore` bound to the shelf, which owns the table (ADR-0041 §决策 4).
final class _ProgressStore implements ReadingProgressStore {
  const _ProgressStore(this._ref);

  final Ref _ref;

  @override
  Future<ReadingPosition?> read({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    final ReadingProgressPosition? stored = await _ref
        .read(bookshelfRepositoryProvider)
        .findProgress(sourceUrl: sourceUrl, bookUrl: bookUrl);
    if (stored == null) {
      return null;
    }

    return ReadingPosition(
      chapterUrl: stored.chapterUrl,
      chapterName: stored.chapterName,
      charOffset: stored.charOffset,
    );
  }

  @override
  Future<void> write({
    required String sourceUrl,
    required String bookUrl,
    required ReadingPosition position,
  }) async {
    await _ref
        .read(bookshelfRepositoryProvider)
        .saveProgress(
          sourceUrl: sourceUrl,
          bookUrl: bookUrl,
          chapterUrl: position.chapterUrl,
          chapterName: position.chapterName,
          charOffset: position.charOffset,
        );
    // 进度写进的是书架的「阅读到」那一行，所以由这里（唯一同时认识两侧的地方）让书架重新读一次：
    // 阅读器不必知道还有个书架页，`keepAlive` 的书架也不会一直显示旧位置。
    _ref.invalidate(bookshelfProvider);
  }
}
