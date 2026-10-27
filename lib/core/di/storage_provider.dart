import 'dart:async';

import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/js/source_login_header.dart';
import 'package:flutter_reader/core/js/source_login_info.dart';
import 'package:flutter_reader/core/js/source_variables.dart';
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
import 'package:flutter_reader/core/storage/source_login_header_dao_repository.dart';
import 'package:flutter_reader/core/storage/source_login_info_dao_repository.dart';
import 'package:flutter_reader/core/storage/source_variable_dao.dart';
import 'package:flutter_reader/core/storage/source_variable_dao_repository.dart';
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

/// Provides the DAO of the per-source variables (`source.getVariable`, ADR-0076 §决策 1).
@Riverpod(keepAlive: true)
SourceVariableDao sourceVariableDao(Ref ref) => SourceVariableDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the per-source variable store the rule engine seeds jobs from and the bridge writes
/// through.
///
/// `keepAlive` matters: the store holds an in-memory copy per source, and a rebuild between two
/// stages (search → detail → toc) would read the table again for no reason.
@Riverpod(keepAlive: true)
SourceVariableStore sourceVariableStore(Ref ref) => SourceVariableStore(
  repository: SourceVariableDaoRepository(
    ref.watch(sourceVariableDaoProvider),
    logger: ref.watch(appLoggerProvider),
  ),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the login header store (`source.putLoginHeader`, M25/S3b).
///
/// The bridge writes it through and the page fetcher merges it into every request's headers, so both
/// must see the same instance. `keepAlive` matters for the same reason as the variables above: the
/// value is hydrated once per source and reused across stages.
@Riverpod(keepAlive: true)
SourceLoginHeaderStore sourceLoginHeaderStore(Ref ref) =>
    SourceLoginHeaderStore(
      repository: SourceLoginHeaderDaoRepository(
        ref.watch(bookSourceDaoProvider),
        logger: ref.watch(appLoggerProvider),
      ),
      logger: ref.watch(appLoggerProvider),
    );

/// Provides the writer behind `source.putLoginInfo` / `source.removeLoginInfo` (M25/S5a).
///
/// Write-only on purpose: a job still receives the login form's values as a snapshot
/// (ADR-0072 §决策 3), so nothing has to be read back per source — the write goes straight to the
/// column the login form reads.
@Riverpod(keepAlive: true)
SourceLoginInfoWriter sourceLoginInfoWriter(Ref ref) =>
    SourceLoginInfoDaoRepository(
      ref.watch(bookSourceDaoProvider),
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
