import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/di.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/usecases/auto_backup.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/explore_page.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/search_books_page.dart';
import 'package:flutter_reader/features/bookshelf/presentation/pages/bookshelf_page.dart';
import 'package:flutter_reader/features/shell/presentation/pages/my_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app shell: four tabs and the bottom navigation bar
/// (`docs/dev/roadmap.md` §3.11 M18, ADR-0055 §决策 2).
///
/// It lives at the **composition root** (`lib/app_shell.dart`) because it is the one place allowed
/// to know four features' pages (C-ARCH-2); `features/shell/` itself only holds the 「我的」/
/// 「关于」/「法律声明」 pages, which compose nothing.
///
/// Two behaviours are deliberate:
///
/// * **the tabs stay alive** (`IndexedStack`): switching away and back keeps the shelf loaded and
///   the search results on screen instead of re-fetching them;
/// * **there is no per-tab navigator**: pushes go to the root navigator (ADR-0011), so back from a
///   book detail / the reader returns to the tab the user came from. Per-tab stacks would need
///   their own ADR, and no screen asks for them yet.
class AppShell extends StatefulWidget {
  /// Creates the shell.
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// The visible tab; the app opens on the shelf (ADR-0055 §决策 2).
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 每天一次的自动备份（ADR-0074 §决策 2）：首帧之后跑，不阻塞启动；到期与否由用例判断。
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_runAutoBackup()),
    );
  }

  /// Runs the daily backup when it is due, and only logs when it fails.
  ///
  /// Failure stays out of the UI on purpose: the user did not ask for this backup, so a toast at
  /// start-up would be noise. The page shows 「上次自动备份」 from the settings, and the next start
  /// retries because the timestamp only advances after a successful write.
  Future<void> _runAutoBackup() async {
    try {
      final AutoBackup autoBackup = await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(autoBackupProvider.future);
      final ParseResult<StoredBackup?> result = await autoBackup.execute();
      if (result is ParseFailure<StoredBackup?>) {
        // 拿不到 `ref`（这是一个 State，不是 ConsumerState）：装配根的容器在启动时一定在。
        if (!mounted) {
          return;
        }
        ProviderScope.containerOf(context, listen: false)
            .read(appLoggerProvider)
            .warning('The automatic backup failed: ${result.rulePath}');
      }
    } on Exception catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      ProviderScope.containerOf(context, listen: false)
          .read(appLoggerProvider)
          .warning('The automatic backup failed', error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return PopScope(
      // 安卓返回键在非首个 tab 上回到书架，而不是直接退出应用
      // （与上游 MainScreen 的 back 处理一致，M18）。
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        setState(() => _index = 0);
      },
      child: Scaffold(
        // 四个 tab 同时存活：切走再回来不重拉书架、不丢搜索结果。
        body: IndexedStack(
          index: _index,
          children: const <Widget>[
            BookshelfPage(),
            ExplorePage(),
            SearchBooksPage(),
            MyPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (int index) => setState(() => _index = index),
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: const Icon(Icons.library_books_outlined),
              selectedIcon: const Icon(Icons.library_books),
              label: l10n.shellTabBookshelf,
            ),
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore),
              label: l10n.shellTabExplore,
            ),
            NavigationDestination(
              icon: const Icon(Icons.search),
              selectedIcon: const Icon(Icons.manage_search),
              label: l10n.shellTabSearch,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: l10n.shellTabMy,
            ),
          ],
        ),
      ),
    );
  }
}
