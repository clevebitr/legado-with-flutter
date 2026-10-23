import 'dart:async';

import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_provider.g.dart';

/// Provides the application database (ADR-0003).
@Riverpod(keepAlive: true)
ReaderDatabase readerDatabase(Ref ref) {
  final ReaderDatabase database = ReaderDatabase(
    ref.watch(databaseExecutorProvider),
  );
  ref.onDispose(() => unawaited(database.close()));

  return database;
}

/// Provides the TTL cache for network payloads (C-NET-6).
@Riverpod(keepAlive: true)
CacheDao cacheDao(Ref ref) => CacheDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the DAO of the imported book sources (`docs/dev/roadmap.md` 5.1, ADR-0040).
@Riverpod(keepAlive: true)
BookSourceDao bookSourceDao(Ref ref) => BookSourceDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);

/// Provides the DAO of the shelf and the reading progress (`docs/dev/roadmap.md` 5.4).
@Riverpod(keepAlive: true)
BookshelfDao bookshelfDao(Ref ref) => BookshelfDao(
  ref.watch(readerDatabaseProvider),
  clock: ref.watch(clockProvider),
);
