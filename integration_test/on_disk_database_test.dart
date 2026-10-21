import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_reader/core/di/database_path_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
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

  /// 订阅 [bookSourceDaoProvider] 并返回订阅句柄；理由同 [keepCacheDaoAlive]。
  ProviderSubscription<BookSourceDao> keepBookSourceDaoAlive(
    ProviderContainer container,
  ) => container.listen<BookSourceDao>(
    bookSourceDaoProvider,
    (BookSourceDao? previous, BookSourceDao next) {},
  );

  /// 订阅 [bookshelfDaoProvider] 并返回订阅句柄；理由同 [keepCacheDaoAlive]。
  ProviderSubscription<BookshelfDao> keepBookshelfDaoAlive(
    ProviderContainer container,
  ) => container.listen<BookshelfDao>(
    bookshelfDaoProvider,
    (BookshelfDao? previous, BookshelfDao next) {},
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

  testWidgets('bookSourceDao_givenAFileDatabase_persistsTheImportedSource', (
    WidgetTester tester,
  ) async {
    // docs/dev/roadmap.md 5.1：`book_sources` 是 v2 新增的表，与 cache 一样必须证明「真写进文件」，
    // 而不只是在内存库里跑通（ADR-0019 §2；每个新表都要在这里加一次真实写入）。
    const String sourceUrl = 'https://integration.test';
    const String fingerprint = 'integration-fingerprint';
    const String storedPayload = '{"bookSourceName":"集成用例书源"}';

    final ProviderContainer writer = ProviderContainer();
    final ProviderSubscription<BookSourceDao> writerDao =
        keepBookSourceDaoAlive(writer);
    late int id;
    try {
      id = await writer
          .read(bookSourceDaoProvider)
          .insertNew(
            url: sourceUrl,
            fingerprint: fingerprint,
            payload: storedPayload,
            name: '集成用例书源',
            groupName: null,
            sourceType: 0,
            isEnabled: true,
            customOrder: 0,
            weight: 0,
            lastUpdateTime: null,
            respondTime: null,
          );
      await writer
          .read(bookSourceDaoProvider)
          .setEnabled(id: id, isEnabled: false);
      // v4 新增的 `comment` 列（ADR-0043 §决策 1）也要真写进文件一次：批量校验的写回路径
      // 就是这一列 + `groupName` + `respondTime`。
      await writer
          .read(bookSourceDaoProvider)
          .writeCheckState(
            id: id,
            groupName: '搜索失效',
            comment: '// Error: 搜索失效',
            respondTime: 4321,
          );
    } finally {
      writerDao.close();
      writer.dispose();
    }

    expect(
      File(databasePath).existsSync(),
      isTrue,
      reason: '原生 SQLite 应已建库：$databasePath',
    );

    final ProviderContainer reader = ProviderContainer();
    final ProviderSubscription<BookSourceDao> readerDao =
        keepBookSourceDaoAlive(reader);
    try {
      final BookSourceRow? row = await reader
          .read(bookSourceDaoProvider)
          .findIdentity(url: sourceUrl, fingerprint: fingerprint);

      // 跨连接读回：证明行、负载与**用户态列**都落在文件里。`row` 为 null 时下面三条
      // 都会失败，所以不需要再单独断言非空（也避开 drift 与 matcher 同名的 `isNotNull`）。
      expect(row?.id, id);
      expect(row?.payload, storedPayload);
      expect(row?.isEnabled, isFalse);
      expect(row?.groupName, '搜索失效');
      expect(row?.comment, '// Error: 搜索失效');
      expect(row?.respondTime, 4321);
    } finally {
      readerDao.close();
      reader.dispose();
    }
  });

  testWidgets('bookshelfDao_givenAFileDatabase_persistsBooksAndProgress', (
    WidgetTester tester,
  ) async {
    // roadmap 5.4：`books` 与 `reading_progress` 是 v3 新增的两张表，同样必须证明「真写进文件」
    // （ADR-0019 §2：每个新表都要在这里加一次真实写入）。
    const String sourceUrl = 'https://integration.test';
    const String bookUrl = 'https://integration.test/book/1';
    const String chapterUrl = 'https://integration.test/book/1/2.html';

    final ProviderContainer writer = ProviderContainer();
    final ProviderSubscription<BookshelfDao> writerDao = keepBookshelfDaoAlive(
      writer,
    );
    late int id;
    try {
      id = await writer
          .read(bookshelfDaoProvider)
          .insertNew(
            sourceUrl: sourceUrl,
            bookUrl: bookUrl,
            name: '集成用例书',
            author: '集成用例作者',
            kind: null,
            coverUrl: null,
            intro: null,
            lastChapter: '第2章',
          );
      await writer
          .read(bookshelfDaoProvider)
          .upsertProgress(
            sourceUrl: sourceUrl,
            bookUrl: bookUrl,
            chapterUrl: chapterUrl,
            chapterName: '第2章',
            charOffset: 34,
          );
    } finally {
      writerDao.close();
      writer.dispose();
    }

    final ProviderContainer reader = ProviderContainer();
    final ProviderSubscription<BookshelfDao> readerDao = keepBookshelfDaoAlive(
      reader,
    );
    try {
      final List<BookshelfRow> rows = await reader
          .read(bookshelfDaoProvider)
          .findAll();

      // 跨连接读回：书、来源与进度都必须落在文件里。
      expect(rows, hasLength(1));
      expect(rows.single.book.id, id);
      expect(rows.single.book.name, '集成用例书');
      expect(rows.single.book.sourceUrl, sourceUrl);
      expect(rows.single.progress?.chapterUrl, chapterUrl);
      expect(rows.single.progress?.charOffset, 34);
    } finally {
      readerDao.close();
      reader.dispose();
    }
  });
}
