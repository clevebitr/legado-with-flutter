import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_reader/core/di/database_path_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 设备级验证：文件型 Drift 数据库（原生 SQLite + 后台 isolate）真能建库、落盘、读回。
///
/// `lib/core/di/database_executor_provider.dart` 在 `flutter test` 的宿主 VM 里必然抛
/// `Channel was closed before receiving a response`，因此按 ADR-0019 第二类登记在
/// `tool/coverage_allowlist.txt` 中豁免覆盖率。**本文件是它唯一的自动化验证入口**：
/// 只有真实设备（Windows 桌面 / Android 模拟器）才提供原生 SQLite 与后台 isolate，
/// 所以「文件型数据库」这一 PLAN 遗留缺口由这里闭环。运行方式见
/// `docs/dev/test-environment.md`。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String sourceId = 'integration-source';
  const String ruleField = 'contentRule.content';
  const String url = 'https://example.com/book/integration';
  const int page = 1;
  const String payload = '<html>integration payload</html>';

  late String databasePath;

  /// 订阅 [cacheDaoProvider] 并返回订阅句柄。
  ///
  /// `@riverpod` 生成的是 **autoDispose** provider（`storage_provider.g.dart` 里
  /// `isAutoDispose: true`）：只 `read` 不 `listen` 时，provider 会在本轮事件循环结束时被
  /// 销毁，`readerDatabaseProvider` 的 `ref.onDispose` 随即 `database.close()`，正在进行的
  /// 写入会被 `ConnectionClosedException`（"Channel was closed before receiving a response"）
  /// 打断。测试里没有 widget tree 帮忙 `watch`，必须显式持有订阅保活。
  ProviderSubscription<CacheDao> keepCacheDaoAlive(
    ProviderContainer container,
  ) => container.listen<CacheDao>(
    cacheDaoProvider,
    (CacheDao? previous, CacheDao next) {},
  );

  setUpAll(() {
    // 本用例故意在同一进程里开两条连接（第二条用来证明数据真的落在文件而不是内存里）。
    // drift 的「ReaderDatabase 被创建多次」警告是调试期提示，在这个场景下是预期噪音；
    // 两条连接各自持有独立的 QueryExecutor，不存在该警告所说的竞态。
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    // 库路径必须由平台给出（C-PLT-3）。
    final ProviderContainer container = ProviderContainer();
    try {
      databasePath = await container.read(databaseFilePathProvider.future);
    } finally {
      container.dispose();
    }

    // 清掉上次运行留下的库文件：否则「跨连接读回」可能读到旧数据而假通过。
    // SQLite 的 WAL 与共享内存文件同样要删，路径由数据库路径派生。
    for (final String suffix in <String>['', '-wal', '-shm']) {
      final File file = File('$databasePath$suffix');
      // `existsSync`：`avoid_slow_async_io` 要求同步版本，这里只在设备上检查几个文件。
      if (file.existsSync()) {
        await file.delete();
      }
    }
  });

  testWidgets('cacheDao_givenAFileDatabase_persistsTheEntryAcrossConnections', (
    WidgetTester tester,
  ) async {
    final ProviderContainer writer = ProviderContainer();
    final ProviderSubscription<CacheDao> writerCache = keepCacheDaoAlive(
      writer,
    );
    try {
      await writer
          .read(cacheDaoProvider)
          .put(
            sourceId: sourceId,
            ruleField: ruleField,
            url: url,
            page: page,
            payload: payload,
            ttl: const Duration(minutes: 5),
          );
    } finally {
      // 退订并销毁容器：让下一条断言检验「落盘」而不是同一连接的内存缓存。
      writerCache.close();
      writer.dispose();
    }

    expect(
      File(databasePath).existsSync(),
      isTrue,
      reason: '原生 SQLite 应已建库：$databasePath',
    );

    final ProviderContainer reader = ProviderContainer();
    final ProviderSubscription<CacheDao> readerCache = keepCacheDaoAlive(
      reader,
    );
    try {
      expect(
        await reader
            .read(cacheDaoProvider)
            .get(
              sourceId: sourceId,
              ruleField: ruleField,
              url: url,
              page: page,
            ),
        payload,
      );
    } finally {
      readerCache.close();
      reader.dispose();
    }
  });
}
