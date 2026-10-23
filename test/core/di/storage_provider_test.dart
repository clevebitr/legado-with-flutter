import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/database_path_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/storage/bookmark_dao.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/read_record_dao.dart';
import 'package:flutter_reader/core/storage/shelf_group_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Channel `path_provider` uses when no platform implementation registered
/// itself, which is the case inside `flutter test`.
const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

/// Overrides the on-disk executor with an in-memory one, so provider tests never
/// touch the filesystem (`docs/dev/testing.md` §4).
///
/// A *file* database cannot be opened here at all: `drift_flutter` runs SQLite in
/// a background isolate, which `flutter test` cannot reach — that is why
/// `database_executor_provider.dart` is exempt from the coverage gate (ADR-0019).
ProviderContainer _memoryContainer() => ProviderContainer.test(
  overrides: <Override>[
    databaseExecutorProvider.overrideWithValue(NativeDatabase.memory()),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('databaseFilePath', () {
    test(
      'databaseFilePath_whenPlatformDirectoryIsKnown_endsWithReaderDb',
      () async {
        final Directory directory = Directory.systemTemp.createTempSync(
          'reader_db_test',
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(_pathProviderChannel, null);
          if (directory.existsSync()) {
            directory.deleteSync(recursive: true);
          }
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              _pathProviderChannel,
              (MethodCall call) async => directory.path,
            );
        final ProviderContainer container = ProviderContainer.test();

        final String path = await container.read(
          databaseFilePathProvider.future,
        );

        expect(File(path).parent.path, directory.path);
        expect(path, endsWith('reader.db'));
      },
    );
  });

  group('readerDatabase', () {
    test('readerDatabase_whenReadTwice_returnsTheSameInstance', () {
      final ProviderContainer container = _memoryContainer();

      expect(
        container.read(readerDatabaseProvider),
        same(container.read(readerDatabaseProvider)),
      );
    });
  });

  group('shelfGroupDao', () {
    test('shelfGroupDao_whenRead_returnsADaoOnTheSharedDatabase', () {
      final ProviderContainer container = _memoryContainer();

      expect(container.read(shelfGroupDaoProvider), isA<ShelfGroupDao>());
      expect(
        container.read(shelfGroupDaoProvider).attachedDatabase,
        same(container.read(readerDatabaseProvider)),
      );
    });
  });

  group('bookmarkDao', () {
    test('bookmarkDao_whenRead_returnsADaoOnTheSharedDatabase', () {
      final ProviderContainer container = _memoryContainer();

      expect(container.read(bookmarkDaoProvider), isA<BookmarkDao>());
      expect(
        container.read(bookmarkDaoProvider).attachedDatabase,
        same(container.read(readerDatabaseProvider)),
      );
    });
  });

  group('readRecordDao', () {
    test('readRecordDao_whenRead_returnsADaoOnTheSharedDatabase', () {
      final ProviderContainer container = _memoryContainer();

      expect(container.read(readRecordDaoProvider), isA<ReadRecordDao>());
      expect(
        container.read(readRecordDaoProvider).attachedDatabase,
        same(container.read(readerDatabaseProvider)),
      );
    });
  });

  group('cacheDao', () {
    test('cacheDao_whenRead_returnsADaoOnTheSharedDatabase', () {
      final ProviderContainer container = _memoryContainer();

      expect(container.read(cacheDaoProvider), isA<CacheDao>());
      expect(
        container.read(cacheDaoProvider).attachedDatabase,
        same(container.read(readerDatabaseProvider)),
      );
    });
  });
}
