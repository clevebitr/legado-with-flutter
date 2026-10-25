import 'dart:async';

import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/network/cookie_store.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/bookmark_dao.dart';
import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/cookie_dao.dart';
import 'package:flutter_reader/core/storage/cookie_dao_store.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/local_image_store.dart';
import 'package:flutter_reader/core/storage/read_record_dao.dart';
import 'package:flutter_reader/core/storage/rule_dao.dart';
import 'package:flutter_reader/core/storage/shelf_group_dao.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_provider.g.dart';

/// Provides the application database.
@Riverpod(keepAlive: true)
ReaderDatabase readerDatabase(Ref ref) {
  final ReaderDatabase database = ReaderDatabase(
    ref.watch(databaseExecutorProvider),
  );
  ref.onDispose(() => unawaited(database.close()));

  return database;
}

/// Provides the TTL cache for network payloads.
@Riverpod(keepAlive: true)
CacheDao cacheDao(Ref ref) => CacheDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the DAO of the imported book sources.
@Riverpod(keepAlive: true)
BookSourceDao bookSourceDao(Ref ref) => BookSourceDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the DAO of the shelf and the reading progress.
@Riverpod(keepAlive: true)
BookshelfDao bookshelfDao(Ref ref) => BookshelfDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the DAO of the shelf groups.
@Riverpod(keepAlive: true)
ShelfGroupDao shelfGroupDao(Ref ref) => ShelfGroupDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the DAO of the bookmarks.
@Riverpod(keepAlive: true)
BookmarkDao bookmarkDao(Ref ref) => BookmarkDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the DAO of the persisted cookie jar.
@Riverpod(keepAlive: true)
CookieDao cookieDao(Ref ref) => CookieDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the storage behind the cookie jar.
@Riverpod(keepAlive: true)
CookieStore cookieStore(Ref ref) => CookieDaoStore(
  ref.watch(cookieDaoProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the DAO of the reading records.
@Riverpod(keepAlive: true)
ReadRecordDao readRecordDao(Ref ref) =>
    ReadRecordDao(ref.watch(readerDatabaseProvider));

/// Provides the DAO of the user-editable rules (替换净化 / 目录 / 字典 / 高亮).
@Riverpod(keepAlive: true)
RuleDao ruleDao(Ref ref) => RuleDao(ref.watch(readerDatabaseProvider));

/// Provides the store user-picked images are copied into (`ADR-0075` §决策 1).
@Riverpod(keepAlive: true)
LocalImageStore localImageStore(Ref ref) =>
    const LocalImageStore(supportDirectory: getApplicationSupportDirectory);
