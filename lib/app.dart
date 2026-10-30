import 'dart:async';

import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_reader/app_reader_exit_guard.dart';
import 'package:flutter_reader/app_shell.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/di/user_messages_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/core/network/persistent_cookie_manager.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/platform/external_url_opener.dart';
import 'package:flutter_reader/core/platform/in_app_web_view_page_fetcher.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_reader/core/platform/user_messages.dart';
import 'package:flutter_reader/core/router/app_navigation.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/core/router/change_source_contract.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/backup/di.dart';
import 'package:flutter_reader/features/backup/domain/repositories/restore_completion_hook.dart';
import 'package:flutter_reader/features/backup/presentation/backup_route.dart';
import 'package:flutter_reader/features/backup/presentation/pages/backup_page.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_content.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/entities/manga_pages.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/purge_rules_port.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/switch_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_detail_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_check_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_debug_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_edit_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_import_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_list_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_login_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/cache_manage_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/explore_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/source_captcha_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/source_verification_page.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/change_source_sheet.dart';
import 'package:flutter_reader/features/bookshelf/data/shelf_cover_picker_impl.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_group.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/domain/repositories/bookshelf_repository.dart';
import 'package:flutter_reader/features/bookshelf/presentation/bookshelf_route.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/bookshelf_notifier.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_source_kind.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_page.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_track_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/manga_page_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/purge_rule_switches.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_source_kind_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/reader_route.dart';
import 'package:flutter_reader/features/rules/di.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/repositories/chapter_body_invalidator.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_repository.dart';
import 'package:flutter_reader/features/rules/presentation/pages/rule_edit_page.dart';
import 'package:flutter_reader/features/rules/presentation/pages/rules_import_page.dart';
import 'package:flutter_reader/features/rules/presentation/pages/rules_list_page.dart';
import 'package:flutter_reader/features/rules/presentation/rules_route.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter_reader/features/settings/presentation/notifiers/settings_notifier.dart';
import 'package:flutter_reader/features/settings/presentation/pages/cookie_manage_page.dart';
import 'package:flutter_reader/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter_reader/features/settings/presentation/settings_route.dart';
import 'package:flutter_reader/features/shell/presentation/pages/about_page.dart';
import 'package:flutter_reader/features/shell/presentation/pages/legal_notices_page.dart';
import 'package:flutter_reader/features/shell/presentation/shell_route.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:url_launcher/url_launcher.dart';

/// The composition root's provider overrides (ADR-0041 §决策 2, ADR-0042).
///
/// This is the **only** place that knows both sides of a cross-feature port: `book_source` declares
/// `BookshelfWriter` and `core` declares `AppNavigation`; the bindings below hand them the shelf's
/// and the settings' real implementations. Composing them here — and not inside either feature —
/// is what keeps `features/A` free of `features/B` imports (C-ARCH-2).
///
/// It is a function rather than a constant because two of the three bindings need a `Ref`.
List<Override> appProviderOverrides() => <Override>[
  appNavigationProvider.overrideWith(_RootNavigation.new),
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
  plainHttpSettingProvider.overrideWith(
    (Ref ref) => ref.watch(
      settingsProvider.select(
        (AsyncValue<AppSettings> value) => value.value?.allowPlainHttp ?? false,
      ),
    ),
  ),
  // 阅读器的三个端口（ADR-0041 §决策 2、ADR-0044 §决策 2）：`reader` 声明、这里绑定到
  // `book_source` 的规则链路与 `bookshelf` 的进度表，两个 feature 之间零 import。
  readerChapterListProvider.overrideWith(_ChapterListSource.new),
  readerChapterContentProvider.overrideWith(_ChapterContentSource.new),
  readerMangaPagesProvider.overrideWith(_MangaPageSource.new),
  readerSourceKindPortProvider.overrideWith(_SourceKindSource.new),
  readerProgressStoreProvider.overrideWith(_ProgressStore.new),
  // 音频链路（ADR-0054 §决策 1/2）：同样由装配根绑定，reader 仍然不认识 book_source。
  readerAudioTrackProvider.overrideWith(_AudioTrackSource.new),
  // `,{webView:…}` 的真实现（ADR-0061）：headless WebView 在 UI isolate 上跑，
  // 平台没有 WebView2 时退回普通 GET。
  webPageFetcherProvider.overrideWith(
    (Ref ref) => InAppWebViewPageFetcher(logger: ref.watch(appLoggerProvider)),
  ),
  // 人机验证需要推一个页面并等结果（ADR-0068 §决策 3）：绑定只能在这里，`core/` 不认识
  // `features/`，`domain/` 也不能碰 `BuildContext`。
  sourceVerificationProvider.overrideWith(_SourceVerification.new),
  // 替换净化（M20，ADR-0070 增补 §6）：`book_source` 声明「取启用的净化规则」端口，这里把它绑到
  // `rules` 的仓储；实体在装配根就地映射成消费方的 `PurgeRule`（ADR-0041 §决策 2）。
  purgeRuleSourceProvider.overrideWith(_PurgeRuleSource.new),
  // 反过来的一条：规则写入后要作废已缓存的成品正文，端口由 `rules` 声明、这里绑到 `book_source`
  // 的正文缓存（ADR-0070 增补 §7）。
  chapterBodyInvalidatorProvider.overrideWith(_ChapterBodyInvalidator.new),
  // 阅读内净化开关（ADR-0094）：`reader` 声明端口，这里绑到 `rules` 的仓储 + 这本书的正文缓存。
  purgeRuleSwitchesProvider.overrideWith(_PurgeRuleSwitches.new),
  // 恢复写过设置之后要让界面重读（ADR-0073 §决策 3）：端口由 `backup` 声明，这里绑到
  // settings 与 reader 的 keepAlive provider —— 它们不失效就会一直显示恢复前的主题与字号。
  restoreCompletionHookProvider.overrideWith(_RestoreHook.new),
  // `java.toast` / `java.longToast` 要贴到界面上（ADR-0076 §决策 1）：`core/` 不认识 widget，
  // 所以由装配根把它绑成一个 snack bar。规则永远不等这条消息。
  userMessagesProvider.overrideWith((Ref ref) => const _RootUserMessages()),
  // `java.openUrl` 要真的开浏览器（M25/S3b）：确认弹窗在 UI 层，`core/` 只认端口。
  externalUrlOpenerProvider.overrideWith(
    (Ref ref) => const _RootExternalUrlOpener(),
  ),
];

/// `PurgeRuleSource` bound to the rules feature, which owns the table (ADR-0070 §决策 3).
///
/// Only **enabled** `replace` rules travel: the pipeline has no use for a disabled rule or for the
/// other three kinds, and a payload this build cannot read is simply not a regex to run.
final class _PurgeRuleSource implements PurgeRuleSource {
  const _PurgeRuleSource(this._ref);

  final Ref _ref;

  @override
  Future<List<PurgeRule>> purgeRules() async {
    final RuleRepository repository = await _ref.read(
      ruleRepositoryProvider.future,
    );
    final List<Rule> rules = await repository.ofKind(RuleKind.replace);

    return <PurgeRule>[
      for (final Rule rule in rules)
        if (rule.isEnabled)
          if (rule.payload case final ReplacePayload payload)
            PurgeRule(
              pattern: payload.pattern,
              replacement: payload.replacement,
              isRegex: payload.isRegex,
              appliesToContent: payload.scopeContent,
              appliesToTitle: payload.scopeTitle,
              timeoutMs: payload.timeoutMs,
            ),
    ];
  }
}

/// `PurgeRuleSwitches` bound to the rules feature and the chapter cache (ADR-0094).
///
/// The reader may flip a replace rule while reading. Two things have to happen for that to be
/// visible: the rule row is written (rules feature) **and** the cached bodies of this book are
/// dropped, because they were purified with the old rules.
final class _PurgeRuleSwitches implements PurgeRuleSwitches {
  const _PurgeRuleSwitches(this._ref);

  final Ref _ref;

  @override
  Future<List<PurgeRuleSwitch>> list() async {
    final RuleRepository repository = await _ref.read(
      ruleRepositoryProvider.future,
    );
    final List<Rule> rules = await repository.ofKind(RuleKind.replace);

    return <PurgeRuleSwitch>[
      for (final Rule rule in rules)
        if (rule.payload case final ReplacePayload payload)
          PurgeRuleSwitch(
            id: rule.id,
            pattern: payload.pattern,
            replacement: payload.replacement,
            isEnabled: rule.isEnabled,
          ),
    ];
  }

  @override
  Future<bool> setEnabled({
    required int id,
    required bool enabled,
    required String sourceUrl,
    required String bookUrl,
  }) async {
    final RuleRepository repository = await _ref.read(
      ruleRepositoryProvider.future,
    );
    await repository.setEnabled(id: id, isEnabled: enabled);
    // 只清这本书：阅读中的开关不该让全库重新下载。
    await _ref
        .read(contentCacheProvider)
        .clearForBook(sourceId: sourceUrl, bookUrl: bookUrl);

    return true;
  }
}

/// `ChapterBodyInvalidator` bound to the chapter body cache in `book_source` (ADR-0070 增补 §7).
final class _ChapterBodyInvalidator implements ChapterBodyInvalidator {
  const _ChapterBodyInvalidator(this._ref);

  final Ref _ref;

  @override
  Future<void> invalidateChapterBodies() =>
      _ref.read(contentCacheProvider).clearAll();
}

/// The theme seed the user picked, as a [Color], or `null` for the project default.
Color? _seedOf(AppSettings settings) => switch (settings.seedColor) {
  final int argb => Color(argb),
  null => null,
};

/// `RestoreCompletionHook` bound to the two providers that cache `shared_preferences`
/// (ADR-0073 §决策 3).
///
/// Both are `keepAlive`, so a restore would otherwise leave the app on the theme and text scale it
/// had before until the next launch. Nothing else is invalidated: the rows the restore wrote are read
/// by pages that are rebuilt when they are opened, and the shelf was already rebuilt by the
/// navigation that got the user here.
final class _RestoreHook implements RestoreCompletionHook {
  const _RestoreHook(this._ref);

  final Ref _ref;

  @override
  void onRestored() {
    _ref.invalidate(settingsProvider);
    _ref.invalidate(readerSettingsProvider);
  }
}

/// `ExternalUrlOpener` bound to a confirmation dialog plus the platform browser.
///
/// Upstream's `java.openUrl` starts a confirmation screen before anything is opened
/// (`JsExtensions.kt:1162-1185`), and a book source must not be able to launch anything behind the
/// user's back — so the address is shown in full, and only 「打开」 reaches `url_launcher`.
///
/// The dialog is shown through [appNavigatorKey] because the request arrives from a plain object
/// (the JS bridge) that has no `BuildContext`; that is the same reason the verification page is
/// pushed from there (ADR-0068 §决策 3).
final class _RootExternalUrlOpener implements ExternalUrlOpener {
  const _RootExternalUrlOpener();

  @override
  Future<bool> open(String url, {String sourceName = ''}) async {
    final BuildContext? context = appNavigatorKey.currentContext;
    if (context == null) {
      return false;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(l10n.externalLinkTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (sourceName.isNotEmpty)
                  Text(l10n.externalLinkFrom(sourceName)),
                const SizedBox(height: 8),
                // 地址可能很长：可选可复制，不折行看不出内容时用户还能拿走它。
                SelectableText(url),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.externalLinkCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.externalLinkOpen),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return false;
    }
    final Uri? uri = Uri.tryParse(url);

    return uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// `UserMessages` bound to the root `ScaffoldMessenger`.
///
/// A snack bar is the desktop-and-mobile answer to Android's `Toast`: it shows the text a rule asked
/// the user to read and disappears on its own. When no messenger is mounted (a headless test, the
/// app before the first frame) the message is dropped — the bridge already logged it, and a toast
/// must never fail a rule.
final class _RootUserMessages implements UserMessages {
  const _RootUserMessages();

  @override
  void show(String message) {
    final ScaffoldMessengerState? messenger =
        appScaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The root navigator key (`docs/dev/roadmap.md` M21a, ADR-0068 §决策 3).
///
/// The verification page is pushed from code that has no `BuildContext`: a JS rule
/// (`java.startBrowser`) reaches the host through the bridge, and the adapter that answers it is a
/// plain object in this file. A `navigatorKey` is the smallest way to give it the root navigator;
/// everything the UI itself starts keeps going through `Navigator` / `AppRouter`.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// The messenger key `java.toast` / `java.longToast` show through (`ADR-0076 §决策 1`).
///
/// Same reason as [appNavigatorKey]: the message is raised from a plain object that has no
/// `BuildContext`, so the root `MaterialApp` is handed this key and the port reads its state.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

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
    BookSourceCheckRoute(:final Set<int>? sourceIds, :final String? group) =>
      BookSourceCheckPage(
        initialSourceIds: sourceIds ?? const <int>{},
        initialGroup: group,
      ),
    final BookSourceDebugRoute route => BookSourceDebugPage(
      sourceId: route.sourceId,
    ),
    final BookSourceEditRoute route => BookSourceEditPage(
      sourceId: route.sourceId,
    ),
    final BookshelfRoute route => bookshelfPageFor(route),
    SettingsPageRoute() => const SettingsPage(),
    final BookDetailRoute route => BookDetailPage(book: route.book),
    final ReaderReadRoute route => ReaderExitGuard(
      book: route.book,
      child: readerPageFor(route),
    ),
    final ReaderRoute route => readerPageFor(route),
    AboutRoute() => const AboutPage(),
    LegalNoticesRoute() => const LegalNoticesPage(),
    final RulesListRoute route => RulesListPage(kind: route.kind),
    final RulesEditRoute route => RuleEditPage(
      kind: route.kind,
      ruleId: route.ruleId,
    ),
    RulesImportRoute() => const RulesImportPage(),
    BookSourceCacheRoute() => const CacheManagePage(),
    final BookSourceLoginRoute route => BookSourceLoginPage(
      sourceId: route.sourceId,
    ),
    SettingsCookiesRoute() => const CookieManagePage(),
    BackupPageRoute() => const BackupPage(),
    // 落地页就是外壳（ADR-0055 §决策 5）：未知参数回落到它，而不是搜索页。
    _ => const AppShell(),
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
    navigatorKey: appNavigatorKey,
    scaffoldMessengerKey: appScaffoldMessengerKey,
    onGenerateTitle: (BuildContext context) =>
        AppLocalizations.of(context).appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // 用户选的种子色只在「平台没有动态取色」时生效（ADR-0075 §决策 1）。
    theme: buildReaderTheme(
      lightDynamic ?? fallbackLightColorScheme(seedColor: _seedOf(settings)),
    ),
    darkTheme: buildReaderTheme(
      darkDynamic ?? fallbackDarkColorScheme(seedColor: _seedOf(settings)),
    ),
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
  const _RootNavigation(this._ref);

  final Ref _ref;

  @override
  void openBookshelf(BuildContext context) =>
      pushBookshelfRoute(context, const BookshelfRoute.shelf());

  @override
  void openSettings(BuildContext context) =>
      pushSettingsRoute(context, const SettingsRoute.settings());

  @override
  void openBookSources(BuildContext context) =>
      pushBookSourceRoute(context, const BookSourceListRoute());

  @override
  void openAbout(BuildContext context) =>
      pushShellRoute(context, const ShellRoute.about());

  @override
  void openShelfBookEdit(BuildContext context, int bookId) {
    // 行是本 feature 的对象：先按 id 找到它，再把整行交给编辑器（ADR-0092）。
    unawaited(_openShelfBookEdit(context, bookId));
  }

  Future<void> _openShelfBookEdit(BuildContext context, int bookId) async {
    for (final ShelvedBook book
        in await _ref.read(bookshelfRepositoryProvider).getAll()) {
      if (book.id != bookId) {
        continue;
      }
      if (!context.mounted) {
        return;
      }
      pushBookshelfRoute(context, BookshelfRoute.editBook(book: book));

      return;
    }
  }

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
    ReaderRoute.read(
      book: ReaderBook(
        sourceUrl: sourceUrl,
        bookUrl: bookUrl,
        name: bookName,
        tocUrl: tocUrl,
      ),
      chapterUrl: chapterUrl,
    ),
  );

  /// Opens the change-source page and applies the picked source (`docs/dev/roadmap.md` §3.12).
  ///
  /// Everything that crosses two features happens here (ADR-0041 §决策 3): the page answers a
  /// candidate + chapter, this binding rewrites the shelf identity, moves the selected source, and
  /// answers primitives the reader can use (C-ARCH-2).
  ///
  /// The author comes from the shelf row when the caller did not know it: the reader only carries
  /// the title, and a book whose title rule failed needs the author to be found at all
  /// (ADR-0091 §决策 3).
  @override
  Future<ChangeSourceOutcome?> openChangeSource(
    BuildContext context,
    ChangeSourceLaunch launch,
  ) async {
    String? author = launch.author;
    final BookshelfRepository shelf = _ref.read(bookshelfRepositoryProvider);
    final List<ShelvedBook> shelfRows = await shelf.getAll();
    ShelvedBook? current;
    for (final ShelvedBook row in shelfRows) {
      if (row.sourceUrl == launch.sourceUrl && row.bookUrl == launch.bookUrl) {
        current = row;
        break;
      }
    }
    if (author == null || author.trim().isEmpty) {
      author = current?.author;
    }
    if (!context.mounted) {
      return null;
    }

    final ChangeSourceSelection? selection = await showChangeSourceSheet(
      context,
      target: (
        sourceUrl: launch.sourceUrl,
        bookUrl: launch.bookUrl,
        name: launch.bookName,
        author: author,
        chapterName: launch.chapterName,
        chapterIndex: launch.chapterIndex,
      ),
    );
    if (selection == null) {
      return null;
    }

    final BookSource? target = await _sourceByUrl(
      _ref,
      selection.candidate.sourceUrl,
    );
    if (target == null) {
      return null;
    }
    final SourceSwitchResult switched = _ref
        .read(switchBookSourceProvider)
        .withChapters(target: target, selection: selection);
    for (final StoredBookSource row in await _ref.read(
      bookSourceListProvider.future,
    )) {
      if (row.source.url == switched.sourceUrl) {
        await _ref.read(selectedBookSourceProvider.notifier).select(row.id);
        break;
      }
    }
    if (current != null) {
      final bool migrated = await shelf.migrateIdentity(
        id: current.id,
        sourceUrl: switched.sourceUrl,
        bookUrl: switched.bookUrl,
        tocUrl: switched.tocUrl,
        name: switched.bookName,
        author: switched.author,
        coverUrl: switched.coverUrl,
        lastChapter: switched.lastChapter,
      );
      // 书架是 keepAlive 的：不改写它，退出阅读器时守护还会拿旧身份判断「在不在书架」。
      if (migrated) {
        _ref.invalidate(bookshelfProvider);
      }
    }

    return ChangeSourceOutcome(
      sourceUrl: switched.sourceUrl,
      bookUrl: switched.bookUrl,
      tocUrl: switched.tocUrl,
      bookName: switched.bookName,
      chapterUrl: switched.chapterUrl,
      chapterName: switched.chapterName,
      chapterIndex: switched.chapterIndex,
    );
  }

  @override
  void openBookmarks(BuildContext context) =>
      pushReaderRoute(context, const ReaderRoute.bookmarks());

  @override
  void openCacheManage(BuildContext context) =>
      pushBookSourceRoute(context, const BookSourceRoute.cacheManage());

  @override
  void openCookies(BuildContext context) =>
      pushSettingsRoute(context, const SettingsRoute.cookies());

  @override
  void openBackup(BuildContext context) =>
      pushBackupRoute(context, const BackupRoute.page());

  @override
  void openReplaceRules(BuildContext context) =>
      pushRulesRoute(context, const RulesRoute.list(kind: RuleKind.replace));

  @override
  void openTocRules(BuildContext context) =>
      pushRulesRoute(context, const RulesRoute.list(kind: RuleKind.toc));

  @override
  void openDictRules(BuildContext context) =>
      pushRulesRoute(context, const RulesRoute.list(kind: RuleKind.dict));

  @override
  void openHighlightRules(BuildContext context) =>
      pushRulesRoute(context, const RulesRoute.list(kind: RuleKind.highlight));

  @override
  void openReadingRecords(BuildContext context) =>
      pushReaderRoute(context, const ReaderRoute.records());

  @override
  void openBookReadingRecords(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
  }) => pushReaderRoute(
    context,
    ReaderRoute.bookRecords(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
      bookName: bookName,
    ),
  );
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

  @override
  Future<ShelfMembership> membership({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    final BookshelfRepository repository = _ref.read(
      bookshelfRepositoryProvider,
    );
    final ShelvedBook? book = await repository.findByUrl(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
    );
    final List<ShelfGroup> groups = await repository.getGroups();
    final List<ShelfGroupOption> options = groups
        .map(
          (ShelfGroup group) =>
              ShelfGroupOption(id: group.id, name: group.name),
        )
        .toList();
    if (book == null) {
      // 不在书架上的书没有分组与封面可言：页面据此把那几个动作置灰。
      return ShelfMembership.absent;
    }

    return ShelfMembership(
      onShelf: true,
      id: book.id,
      groupId: book.groupId,
      customCoverPath: book.customCoverPath,
      customIntro: book.customIntro,
      progressChapterName: book.progress?.chapterName,
      groups: options,
    );
  }

  @override
  Future<ParseResult<void>> assignGroup({
    required String sourceUrl,
    required String bookUrl,
    required int? groupId,
  }) async {
    final BookshelfRepository repository = _ref.read(
      bookshelfRepositoryProvider,
    );
    final ShelvedBook? book = await repository.findByUrl(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
    );
    if (book == null) {
      return const ParseFailure<void>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'shelf.writer.group',
      );
    }
    await repository.setGroupFor(ids: <int>[book.id], groupId: groupId);
    // 书架是 keepAlive 的：不主动失效的话，切回 tab 还显示旧分组。
    _ref.invalidate(bookshelfProvider);

    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<String?>> chooseCustomCover({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    final BookshelfRepository repository = _ref.read(
      bookshelfRepositoryProvider,
    );
    final ShelvedBook? book = await repository.findByUrl(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
    );
    if (book == null) {
      return const ParseFailure<String?>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'shelf.writer.cover',
      );
    }
    final String? path = await _ref
        .read(shelfCoverPickerProvider)
        .pickAndStore();
    if (path == null) {
      // 取消不是失败（platform.md §2）：页面什么都不做。
      return const ParseSuccess<String?>(null);
    }
    await repository.saveCustomCover(id: book.id, path: path);
    _ref.invalidate(bookshelfProvider);

    return ParseSuccess<String?>(path);
  }

  @override
  Future<ParseResult<void>> resetCustomCover({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    final BookshelfRepository repository = _ref.read(
      bookshelfRepositoryProvider,
    );
    final ShelvedBook? book = await repository.findByUrl(
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
    );
    final String? path = book?.customCoverPath;
    if (book == null || path == null) {
      return const ParseResult<void>.success(null);
    }
    await repository.saveCustomCover(id: book.id, path: null);
    await _ref.read(shelfCoverPickerProvider).delete(path);
    _ref.invalidate(bookshelfProvider);

    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<void>> migrateIdentity({
    required String sourceUrl,
    required String bookUrl,
    required String newSourceUrl,
    required String newBookUrl,
    required String newTocUrl,
    required String newName,
    String? newAuthor,
    String? newCoverUrl,
    String? newLastChapter,
  }) async {
    try {
      final BookshelfRepository repository = _ref.read(
        bookshelfRepositoryProvider,
      );
      final ShelvedBook? book = await repository.findByUrl(
        sourceUrl: sourceUrl,
        bookUrl: bookUrl,
      );
      if (book == null) {
        return const ParseSuccess<void>(null);
      }
      await repository.migrateIdentity(
        id: book.id,
        sourceUrl: newSourceUrl,
        bookUrl: newBookUrl,
        tocUrl: newTocUrl,
        name: newName,
        author: newAuthor,
        coverUrl: newCoverUrl,
        lastChapter: newLastChapter,
      );
      // 书架与「我的」里的分组/封面入口都读 keepAlive 的书架：身份变了要重读。
      _ref.invalidate(bookshelfProvider);

      return const ParseSuccess<void>(null);
    } on Exception catch (error, stackTrace) {
      _ref
          .read(appLoggerProvider)
          .warning('Migrating the shelf identity failed.', error, stackTrace);

      return const ParseFailure<void>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'shelf.migrateIdentity',
      );
    }
  }
}

/// `SourceVerification` bound to the visible WebView pages (`docs/dev/roadmap.md` M21a).
///
/// It is the one place that knows both sides: a rule asks for a human, and this adapter pushes the
/// page on the root navigator, waits for the outcome, and — when the rule asked for it — re-fetches
/// the address over HTTP so the answer already carries the cookies the user just earned
/// (ADR-0068 §决策 3/5).
final class _SourceVerification implements SourceVerification {
  /// Creates the binding.
  const _SourceVerification(this._ref);

  final Ref _ref;

  @override
  bool get isSupported {
    final PlatformInfo platform = _ref.read(platformInfoProvider);

    return platform.isMobile || platform.isDesktop;
  }

  @override
  Future<ParseResult<SourceVerificationOutcome>> verify(
    SourceVerificationRequest request,
  ) async {
    final NavigatorState? navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      // 没有 navigator 就没有人去点验证：报「已取消」，让上层当成一次未完成的验证。
      return const ParseFailure<SourceVerificationOutcome>(
        kind: ParseFailureKind.cancelled,
        rulePath: 'java.startBrowser',
      );
    }
    final PersistentCookieManager jar = _ref.read(cookieManagerProvider);
    final List<StoredCookie> cookies = jar.cookiesFor(Uri.parse(request.url));
    final SourceVerificationOutcome? outcome = await navigator
        .push<SourceVerificationOutcome>(
          MaterialPageRoute<SourceVerificationOutcome>(
            builder: (BuildContext context) => SourceVerificationPage(
              request: request,
              cookies: cookies,
              cookieJar: jar,
            ),
          ),
        );
    if (outcome == null) {
      // 用户明确关掉页面：`cancelled` 是既有 kind，页面会显示「已取消验证」。
      return const ParseFailure<SourceVerificationOutcome>(
        kind: ParseFailureKind.cancelled,
        rulePath: 'java.startBrowser',
      );
    }
    if (!request.refetchAfterSuccess) {
      return ParseSuccess<SourceVerificationOutcome>(outcome);
    }

    // 重取走统一的请求层（C-NET-1）：此刻 cookie jar 已经收下用户过盾得到的 cookie。
    final ParseResult<HttpResponse> refetched = await _ref
        .read(httpClientProvider)
        .get(
          request.url,
          rulePath: 'java.startBrowser',
          headers: request.headers,
          sourceId: request.sourceUrl,
        );

    return switch (refetched) {
      ParseSuccess<HttpResponse>(:final HttpResponse data) =>
        ParseSuccess<SourceVerificationOutcome>(
          SourceVerificationOutcome(url: request.url, body: data.body),
        ),
      ParseFailure<HttpResponse>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        ParseFailure<SourceVerificationOutcome>(kind: kind, rulePath: rulePath),
    };
  }

  @override
  Future<ParseResult<String>> imageCode({
    required String sourceUrl,
    required String sourceName,
    required String imageUrl,
    required String title,
  }) async {
    final NavigatorState? navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return const ParseFailure<String>(
        kind: ParseFailureKind.cancelled,
        rulePath: 'java.getVerificationCode',
      );
    }
    // 验证码图必须拿**原始字节**（C-NET-1 的字节门）：按文本解码会把图片弄坏。
    final ParseResult<Uint8List> image = await _ref
        .read(httpClientProvider)
        .getBytes(
          imageUrl,
          rulePath: 'java.getVerificationCode',
          sourceId: sourceUrl,
        );
    switch (image) {
      case ParseFailure<Uint8List>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return ParseFailure<String>(kind: kind, rulePath: rulePath);
      case ParseSuccess<Uint8List>(:final Uint8List data):
        final String? code = await navigator.push<String>(
          MaterialPageRoute<String>(
            builder: (BuildContext context) =>
                SourceCaptchaPage(image: data, sourceName: sourceName),
          ),
        );

        return code == null
            ? const ParseFailure<String>(
                kind: ParseFailureKind.cancelled,
                rulePath: 'java.getVerificationCode',
              )
            : ParseSuccess<String>(code);
    }
  }
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
    String bookUrl = '',
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
        .execute(source, tocUrl, bookName: bookName, bookUrl: bookUrl);

    return switch (result) {
      ParseSuccess<List<Chapter>>(:final List<Chapter> data) =>
        ParseSuccess<List<ReadingChapter>>(
          await _purifiedChapters(data, source: source, tocUrl: tocUrl),
        ),
      ParseFailure<List<Chapter>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<List<ReadingChapter>>(kind: kind, rulePath: rulePath),
    };
  }
}

/// The chapters with the user's **title** purge rules applied.
///
/// This is the one place the reader's titles come from, so purifying here makes the 目录 sheet, the
/// chapter header, the stored progress name and a search hit agree on one title (ADR-0071 §决策 4).
/// The detail page's TOC preview and the shelf's 「最新章节」 read `book_source`'s own cache instead
/// and stay unpurified — registered in `roadmap.md` §3.7.
extension on _ChapterListSource {
  Future<List<ReadingChapter>> _purifiedChapters(
    List<Chapter> chapters, {
    required BookSource source,
    required String tocUrl,
  }) async {
    final List<String> titles = await _ref
        .read(contentPurifierProvider)
        .purgeTitles(
          <String>[for (final Chapter chapter in chapters) chapter.name],
          // 标题规则读到的是**目录页**：`baseUrl` 就是 tocUrl，`@js:` 标题脚本靠它取上下文。
          context: JsPageContext(baseUrl: tocUrl, source: source.jsSourceInfo),
        );

    return <ReadingChapter>[
      for (var index = 0; index < chapters.length; index++)
        ReadingChapter(
          title: titles[index],
          url: chapters[index].url,
          // 阅读端自己不用它们，但正文阶段的 `chapter` 绑定要用（M25/S3b）。
          isVip: chapters[index].isVip,
          isPay: chapters[index].isPay,
          isVolume: chapters[index].isVolume,
          updateTime: chapters[index].updateTime,
        ),
    ];
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
    String bookUrl = '',
    String tocUrl = '',
    String nextChapterUrl = '',
    bool isVip = false,
    bool isPay = false,
    bool isVolume = false,
    String? updateTime,
  }) async {
    final BookSource? source = await _sourceByUrl(_ref, sourceUrl);
    if (source == null) {
      return failureAt<String>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'reader.chapterContent',
      );
    }

    // 在架书的正文不自动过期（ADR-0097 §决策 1）：只有装配根同时认识书架与书源，所以这条判定
    // 放在这里，并且**每次**都查——一条错判成「永久」的缓存只有用户手动清理才会消失。
    final bool onShelf =
        bookUrl.isNotEmpty &&
        await _ref
                .read(bookshelfRepositoryProvider)
                .findByUrl(sourceUrl: sourceUrl, bookUrl: bookUrl) !=
            null;

    // 阅读器端口只要正文：正文页标题（`contentRule.title`）与歌词属于领域结果，阅读端还没消费
    // （登记在 `engine-parity.md` 3.1），所以在这里按 `body` 收口，不把两边的类型串在一起。
    final ParseResult<ChapterContent> content = await _ref
        .read(fetchContentProvider)
        .execute(
          source,
          ChapterRequest(
            url: chapterUrl,
            title: chapterTitle,
            bookName: bookName,
            bookUrl: bookUrl,
            tocUrl: tocUrl,
            nextChapterUrl: nextChapterUrl,
            isVip: isVip,
            isPay: isPay,
            isVolume: isVolume,
            updateTime: updateTime,
            persistCache: onShelf,
          ),
        );

    return switch (content) {
      ParseFailure<ChapterContent>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<String>(kind: kind, rulePath: rulePath),
      ParseSuccess<ChapterContent>(:final ChapterContent data) =>
        ParseSuccess<String>(data.body),
    };
  }
}

/// `MangaPageProvider` bound to `book_source`'s `FetchMangaPages`
/// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053 §决策 2).
///
/// The mapping `MangaPages` → `List<ReadingPage>` happens here, the one place allowed to know both
/// features' types (ADR-0041 §决策 3). The source's headers travel with every page because the image
/// host may check the same `Referer` the rule chain used.
final class _MangaPageSource implements MangaPageProvider {
  const _MangaPageSource(this._ref);

  final Ref _ref;

  @override
  Future<ParseResult<List<ReadingPage>>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
  }) async {
    final BookSource? source = await _sourceByUrl(_ref, sourceUrl);
    if (source == null) {
      return failureAt<List<ReadingPage>>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'reader.mangaPages',
      );
    }

    final ParseResult<MangaPages> result = await _ref
        .read(fetchMangaPagesProvider)
        .execute(
          source,
          ChapterRequest(
            url: chapterUrl,
            title: chapterTitle,
            bookName: bookName,
          ),
        );

    return switch (result) {
      ParseSuccess<MangaPages>(:final MangaPages data) =>
        ParseSuccess<List<ReadingPage>>(<ReadingPage>[
          for (final String url in data.urls)
            ReadingPage(
              url: url,
              headers: data.headers ?? const <String, String>{},
              style: _mangaStyleOf(data.imageStyle),
            ),
        ]),
      ParseFailure<MangaPages>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<List<ReadingPage>>(kind: kind, rulePath: rulePath),
    };
  }
}

/// The reader's layout enum for a source's `ruleContent.imageStyle` (ADR-0069 G5).
///
/// Upstream compares the value case-insensitively and lets an unknown one fall through to the
/// centered default, which is what this does. `left` / `right` / `centered` still render like
/// `full` — the alignment branch is registered in `docs/dev/roadmap.md` §3.7.
MangaImageStyle _mangaStyleOf(String? imageStyle) =>
    switch (imageStyle?.trim().toLowerCase()) {
      'full' => MangaImageStyle.full,
      'single' => MangaImageStyle.single,
      'left' => MangaImageStyle.left,
      'right' => MangaImageStyle.right,
      _ => MangaImageStyle.centered,
    };

/// `AudioTrackProvider` bound to `book_source`'s `FetchAudioTracks` (ADR-0054 §决策 2).
final class _AudioTrackSource implements AudioTrackProvider {
  const _AudioTrackSource(this._ref);

  final Ref _ref;

  @override
  Future<ParseResult<List<ReaderAudioTrack>>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
    String bookUrl = '',
    String tocUrl = '',
  }) async {
    final BookSource? source = await _sourceByUrl(_ref, sourceUrl);
    if (source == null) {
      return failureAt<List<ReaderAudioTrack>>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'reader.audioTracks',
      );
    }

    final ParseResult<List<AudioTrack>> result = await _ref
        .read(fetchAudioTracksProvider)
        .execute(
          source,
          ChapterRequest(
            url: chapterUrl,
            title: chapterTitle,
            bookName: bookName,
            bookUrl: bookUrl,
            tocUrl: tocUrl,
          ),
        );

    return switch (result) {
      ParseSuccess<List<AudioTrack>>(:final List<AudioTrack> data) =>
        ParseSuccess<List<ReaderAudioTrack>>(<ReaderAudioTrack>[
          for (final AudioTrack track in data)
            ReaderAudioTrack(url: track.url, headers: track.headers),
        ]),
      ParseFailure<List<AudioTrack>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<List<ReaderAudioTrack>>(kind: kind, rulePath: rulePath),
    };
  }
}

/// `ReaderSourceKindProvider` bound to the stored source's `bookSourceType`
/// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053 §决策 1).
///
/// A source whose row is gone answers text: the reader then shows the ordinary failure/empty path
/// instead of a manga page for a source that does not exist.
final class _SourceKindSource implements ReaderSourceKindProvider {
  const _SourceKindSource(this._ref);

  final Ref _ref;

  @override
  Future<ParseResult<ReaderSourceKind>> of(String sourceUrl) async {
    final BookSource? source = await _sourceByUrl(_ref, sourceUrl);
    if (source == null) {
      return const ParseSuccess<ReaderSourceKind>(ReaderSourceKind.text);
    }

    return ParseSuccess<ReaderSourceKind>(switch (source.sourceType) {
      BookSourceType.image => ReaderSourceKind.image,
      BookSourceType.audio => ReaderSourceKind.audio,
      _ => ReaderSourceKind.text,
    });
  }
}
