import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/js/source_login_header.dart';
import 'package:flutter_reader/core/js/source_login_info.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/background_image_picker.dart';
import 'package:flutter_reader/core/platform/json_file_picker.dart';
import 'package:flutter_reader/core/platform/json_file_saver.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_reader/core/storage/local_image_store.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/search_books_page.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_reader/features/settings/di.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'fake_app_navigation.dart';
import 'fake_book_source_repository.dart';
import 'fake_book_source_view_store.dart';
import 'fake_bookshelf_repository.dart';
import 'fake_bookshelf_writer.dart';
import 'fake_content_cache.dart';
import 'fake_http_client.dart';
import 'fake_log_printer.dart';
import 'fake_search_scope_store.dart';
import 'fake_settings_repository.dart';

/// The offline corpus of `docs/dev/book-source.md` §10, wired for widget tests.
///
/// The pages are driven through the **production chain** (notifier → use case →
/// `renderUrlTemplate` → `HttpClient` → `RuleEngine`) with a fake client, which is
/// what `docs/dev/roadmap.md` §6 trap #1 asks for: a widget test that passes because the page
/// renders must still exercise the real pipeline.
const String corpusSearchUrl =
    'https://example-novel.test/search.php?q=%E5%89%91%E6%9D%A5';

/// The book URL the corpus search page points at.
const String corpusBookUrl = 'https://example-novel.test/book/1/';

/// The chapter URL of the first corpus chapter.
const String corpusChapterUrl = 'https://example-novel.test/book/1/1.html';

/// The keyword the corpus search URL belongs to.
const String corpusKeyword = '剑来';

/// Loads the sanitized real book source of the corpus.
BookSource loadCorpusBookSource() => BookSource.fromLegadoJson(
  jsonDecode(
    File('test/fixtures/book_sources/legado_default_rules_source.json')
        .readAsStringSync(),
  ) as Map<String, Object?>,
);

/// Reads one page of the corpus.
String corpusPage(String name) =>
    File('test/fixtures/html/$name').readAsStringSync();

/// Serves the pages of the four corpus stages on [http].
FakeHttpClient serveCorpusPages(FakeHttpClient http) {
  http.serve(corpusSearchUrl, corpusPage('search_result.html'));
  http.serve(corpusBookUrl, corpusPage('book_page.html'));
  http.serve(corpusChapterUrl, corpusPage('chapter_page.html'));

  return http;
}

/// Pumps the whole app behind [source] and [http].
///
/// This is the shortest path to the production wiring: `ReaderApp` owns the route
/// table, so a test can walk search → detail → reader by tapping.
Future<void> pumpReaderApp(
  WidgetTester tester, {
  required BookSource? source,
  required FakeHttpClient http,
  FakeBookSourceRepository? repository,
}) async {
  _fixViewSize(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        // testing.md §5：固定种子色并禁用动态取色。
        platformDynamicColorProvider.overrideWithValue(null),
        currentBookSourceProvider.overrideWithValue(source),
        // 发现页读的是**存储投影**（探索开关是列，ADR-0052 §决策 3），所以替身也要给出它：
        // 只覆盖 `currentBookSourceProvider` 会让页面误判「没有书源」。
        selectedBookSourceProvider.overrideWith(
          () => _FixedSelectedBookSource(source),
        ),
        httpClientProvider.overrideWithValue(http),
        // 登录头（`source.putLoginHeader`，M25/S3b）与登录信息的写入口（M25/S5a）默认写穿数据库：
        // 页面测试换成内存实现。
        sourceLoginHeaderStoreProvider.overrideWithValue(
          SourceLoginHeaderStore(),
        ),
        sourceLoginInfoWriterProvider.overrideWithValue(
          InMemorySourceLoginInfoWriter(),
        ),
        // 5.2 的正文缓存默认接真实 Drift；宿主 VM 里没有可用的执行器，页面测试用内存替身
        // （端口是 total，替身与适配器对页面是同一件事）。
        contentCacheProvider.overrideWithValue(FakeContentCache()),
        appLoggerProvider.overrideWithValue(_logger()),
        // 5.1 的页面（书源列表 / 导入）走仓储；不传时给一个空库，
        // 免得整条链在 widget 测试里去找真实数据库（testing.md §4）。
        bookSourceRepositoryProvider.overrideWithValue(
          repository ?? FakeBookSourceRepository(),
        ),
        bookSourceViewStoreProvider.overrideWith(
          (Ref ref) async => FakeBookSourceViewStore(),
        ),
        // 外壳会同时构建书架 tab：宿主 VM 没有真实 Drift，给内存替身免于永久 spinner。
        bookshelfRepositoryProvider.overrideWithValue(
          FakeBookshelfRepository(),
        ),
      ],
      child: const ReaderApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a single [page] with the same providers, theme and localization.
///
/// Used for the per-page smoke tests of C-TEST-2, i.e. where navigation is not part
/// of what is being asserted.
Future<ProviderContainer?> pumpBookSourcePage(
  WidgetTester tester, {
  required Widget page,
  required BookSource? source,
  required FakeHttpClient http,
  FakeAppNavigation? navigation,
  FakeBookSourceRepository? repository,
  FakeBookshelfWriter? writer,
  FakeContentCache? contentCache,
}) async {
  _fixViewSize(tester);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      // 传 [repository] 时让真实的「当前源」派生（列表 → 选中行）：换源相关的测试需要它。
      if (repository == null) ...<Override>[
        currentBookSourceProvider.overrideWithValue(source),
        // 发现页读的是**存储投影**（探索开关是列，ADR-0052 §决策 3），所以替身也要给出它：
        // 只覆盖 `currentBookSourceProvider` 会让页面误判「没有书源」。
        selectedBookSourceProvider.overrideWith(
          () => _FixedSelectedBookSource(source),
        ),
      ] else
        bookSourceRepositoryProvider.overrideWithValue(repository),
      httpClientProvider.overrideWithValue(http),
      // 登录头（`source.putLoginHeader`，M25/S3b）与登录信息的写入口（M25/S5a）默认写穿数据库：
      // 页面测试换成内存实现。
      sourceLoginHeaderStoreProvider.overrideWithValue(
        SourceLoginHeaderStore(),
      ),
      sourceLoginInfoWriterProvider.overrideWithValue(
        InMemorySourceLoginInfoWriter(),
      ),
      // 跨 feature 的入口是端口（ADR-0042）：测试可以塞一个记录器，断言页面**请求了**
      // 什么（哪一章 / 哪本书），而不是去追一个路由。
      if (navigation != null)
        appNavigationProvider.overrideWithValue(navigation),
      // 5.2 的正文缓存默认接真实 Drift；宿主 VM 里没有可用的执行器，页面测试用内存替身
      // （端口是 total，替身与适配器对页面是同一件事）。
      contentCacheProvider.overrideWithValue(
        contentCache ?? FakeContentCache(),
      ),
      if (writer != null) bookshelfWriterProvider.overrideWithValue(writer),
      appLoggerProvider.overrideWithValue(_logger()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        // 固定英文：断言取的是 `AppLocalizations` 的值，而不是写死的字面量。
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return repository == null ? null : container;
}

/// Pumps a source-management [page] (the source list, the import screen) against an in-memory
/// repository (`docs/dev/roadmap.md` 5.1).
///
/// The database is what `testing.md` §4 replaces with a double: 5.1's screens talk to
/// `BookSourceRepository`, so overriding the port is enough to drive them without Drift.
Future<void> pumpSourceManagementPage(
  WidgetTester tester, {
  required Widget page,
  required FakeBookSourceRepository repository,
  FakeHttpClient? http,
  JsonFilePicker? picker,
  FakeBookSourceViewStore? viewStore,
  JsonFileSaver? saver,
  Clock? clock,
  SourceVerification? verification,
  void Function(Object? arguments)? onPush,
}) async {
  _fixViewSize(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookSourceRepositoryProvider.overrideWithValue(repository),
        httpClientProvider.overrideWithValue(http ?? FakeHttpClient()),
        // 登录头（`source.putLoginHeader`，M25/S3b）与登录信息的写入口（M25/S5a）默认写穿数据库：
        // 页面测试换成内存实现。
        sourceLoginHeaderStoreProvider.overrideWithValue(
          SourceLoginHeaderStore(),
        ),
        sourceLoginInfoWriterProvider.overrideWithValue(
          InMemorySourceLoginInfoWriter(),
        ),
        appLoggerProvider.overrideWithValue(_logger()),
        // 文件选择器的默认实现要走平台通道；测试永远覆盖端口（testing.md §4）。
        jsonFilePickerProvider.overrideWithValue(
          picker ?? const UnsupportedJsonFilePicker(),
        ),
        // 单条导出同理：保存对话框是平台通道，测试覆盖端口。
        jsonFileSaverProvider.overrideWithValue(
          saver ?? const UnsupportedJsonFileSaver(),
        ),
        // 5.5 起列表页还读「排序 + 分组筛选」这条视图偏好；宿主 VM 里没有平台存储，
        // 所以端口给内存替身（testing.md §4）。
        bookSourceViewStoreProvider.overrideWith(
          (Ref ref) async => viewStore ?? FakeBookSourceViewStore(),
        ),
        // 列表里的「上次校验 2 分钟前」由注入时钟换算（testing.md §4）。
        if (clock != null) clockProvider.overrideWithValue(clock),
        // 可见 WebView 验证页是平台通道：需要断言「打开了哪个地址」的测试覆盖端口。
        if (verification != null)
          sourceVerificationProvider.overrideWithValue(verification),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        // 要断言「点了哪个入口、带着什么参数」的测试传 [onPush]：真实路由表归 `app.dart`
        // （ADR-0011），这里只把握到的 typed route 交回去。
        onGenerateRoute: onPush == null
            ? null
            : (RouteSettings settings) {
                onPush(settings.arguments);

                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (BuildContext context) => const SizedBox.shrink(),
                );
              },
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps one of the two source consoles (batch check / single-source debug) and hands back its
/// container, so a test can stop a run in the middle (`docs/dev/roadmap.md` 5.10).
///
/// Both pages run the **real** chain — notifier → use case → `HttpClient` → `RuleEngine` — so the
/// overrides are the same ports every other page test replaces: the repository, the client, the
/// body cache (the check reads a chapter) and the logger.
Future<ProviderContainer> pumpSourceConsolePage(
  WidgetTester tester, {
  required Widget page,
  required FakeBookSourceRepository repository,
  required FakeHttpClient http,
}) async {
  _fixViewSize(tester);
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      bookSourceRepositoryProvider.overrideWithValue(repository),
      httpClientProvider.overrideWithValue(http),
      // 登录头（`source.putLoginHeader`，M25/S3b）与登录信息的写入口（M25/S5a）默认写穿数据库：
      // 页面测试换成内存实现。
      sourceLoginHeaderStoreProvider.overrideWithValue(
        SourceLoginHeaderStore(),
      ),
      sourceLoginInfoWriterProvider.overrideWithValue(
        InMemorySourceLoginInfoWriter(),
      ),
      contentCacheProvider.overrideWithValue(FakeContentCache()),
      appLoggerProvider.overrideWithValue(_logger()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

/// Pumps the search page and hands back its container (`docs/dev/roadmap.md` 3.8).
///
/// The page resolves its scope into sources and runs the aggregate search, so the overrides are the
/// repository (the source list), the client, the body cache and the scope store — all ports, never a
/// plugin (`docs/dev/testing.md` §4).
Future<ProviderContainer> pumpSearchPage(
  WidgetTester tester, {
  required FakeBookSourceRepository repository,
  required FakeHttpClient http,
  FakeSearchScopeStore? scopeStore,
}) async {
  _fixViewSize(tester);
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      bookSourceRepositoryProvider.overrideWithValue(repository),
      httpClientProvider.overrideWithValue(http),
      // 登录头（`source.putLoginHeader`，M25/S3b）与登录信息的写入口（M25/S5a）默认写穿数据库：
      // 页面测试换成内存实现。
      sourceLoginHeaderStoreProvider.overrideWithValue(
        SourceLoginHeaderStore(),
      ),
      sourceLoginInfoWriterProvider.overrideWithValue(
        InMemorySourceLoginInfoWriter(),
      ),
      contentCacheProvider.overrideWithValue(FakeContentCache()),
      searchScopeStoreProvider.overrideWith(
        (Ref ref) async => scopeStore ?? FakeSearchScopeStore(),
      ),
      appLoggerProvider.overrideWithValue(_logger()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const SearchBooksPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

/// Pumps the shelf page against an in-memory repository (`docs/dev/roadmap.md` 5.4).
///
/// The shelf talks to `BookshelfRepository`, so overriding the port is enough: no Drift, no
/// platform channel (`docs/dev/testing.md` §4).
Future<void> pumpShelfPage(
  WidgetTester tester, {
  required Widget page,
  required FakeBookshelfRepository repository,
}) async {
  _fixViewSize(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        bookshelfRepositoryProvider.overrideWithValue(repository),
        appLoggerProvider.overrideWithValue(_logger()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the settings page against in-memory settings and cache doubles
/// (`docs/dev/roadmap.md` 5.6).
Future<void> pumpSettingsPage(
  WidgetTester tester, {
  required Widget page,
  required FakeSettingsRepository repository,
  required FakeCachePurger purger,
  BackgroundImagePicker? imagePicker,
  LocalImageStore? imageStore,
}) async {
  _fixViewSize(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWith((Ref ref) async => repository),
        cachePurgerProvider.overrideWithValue(purger),
        appLoggerProvider.overrideWithValue(_logger()),
        if (imagePicker != null)
          backgroundImagePickerProvider.overrideWithValue(imagePicker),
        if (imageStore != null)
          localImageStoreProvider.overrideWithValue(imageStore),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The localization the widget behind [finder] sees.
AppLocalizations localizationOf(WidgetTester tester, Finder finder) =>
    AppLocalizations.of(tester.element(finder));

AppLogger _logger() =>
    AppLogger(level: LogLevel.debug, printer: FakeLogPrinter());

void _fixViewSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A [SelectedBookSource] that always answers [stored].
///
/// The discover page reads the stored projection (the explore flag is a column), so the shared
/// harness has to provide it instead of only the sync `currentBookSourceProvider` shortcut.
final class _FixedSelectedBookSource extends SelectedBookSource {
  _FixedSelectedBookSource(this.stored);

  final BookSource? stored;

  @override
  Future<StoredBookSource?> build() async {
    final BookSource? source = stored;
    if (source == null) {
      return null;
    }

    return StoredBookSource(
      id: 1,
      source: source,
      isEnabled: source.isEnabled,
      customOrder: 0,
      importedAt: DateTime.utc(2026, 10, 22),
      groupName: source.group,
    );
  }
}
