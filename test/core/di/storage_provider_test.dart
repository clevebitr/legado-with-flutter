import 'dart:io';

import 'package:drift/drift.dart' show DatabaseAccessor, GeneratedDatabase;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/database_path_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/storage/bookmark_dao.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_reader/core/storage/local_image_store.dart';
import 'package:flutter_reader/core/storage/read_record_dao.dart';
import 'package:flutter_reader/core/storage/rule_dao.dart';
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

/// The DAO providers and the DAO type each one must build.
final Map<String, (Type, Object Function(ProviderContainer))> _daoProviders =
    <String, (Type, Object Function(ProviderContainer))>{
      'shelfGroupDao': (ShelfGroupDao, _shelfGroupDao),
      'bookmarkDao': (BookmarkDao, _bookmarkDao),
      'readRecordDao': (ReadRecordDao, _readRecordDao),
      'ruleDao': (RuleDao, _ruleDao),
      'cacheDao': (CacheDao, _cacheDao),
    };

Object _shelfGroupDao(ProviderContainer container) =>
    container.read(shelfGroupDaoProvider);
Object _bookmarkDao(ProviderContainer container) =>
    container.read(bookmarkDaoProvider);
Object _readRecordDao(ProviderContainer container) =>
    container.read(readRecordDaoProvider);
Object _ruleDao(ProviderContainer container) => container.read(ruleDaoProvider);
Object _cacheDao(ProviderContainer container) =>
    container.read(cacheDaoProvider);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

      final String path = await ProviderContainer.test().read(
        databaseFilePathProvider.future,
      );

      expect(File(path).parent.path, directory.path);
      expect(path, endsWith('reader.db'));
    },
  );

  test('readerDatabase_whenReadTwice_returnsTheSameInstance', () {
    final ProviderContainer container = _memoryContainer();

    expect(
      container.read(readerDatabaseProvider),
      same(container.read(readerDatabaseProvider)),
    );
  });

  test('daoProviders_whenRead_buildTheirDaoOnTheSharedDatabase', () {
    final ProviderContainer container = _memoryContainer();
    final Object database = container.read(readerDatabaseProvider);

    for (final MapEntry<String, (Type, Object Function(ProviderContainer))> dao
        in _daoProviders.entries) {
      final Object built = dao.value.$2(container);

      expect(built.runtimeType, dao.value.$1, reason: dao.key);
      // 所有 DAO 必须挂在同一个连接上，否则测试里会悄悄各建一个库。
      expect(
        (built as DatabaseAccessor<GeneratedDatabase>).attachedDatabase,
        same(database),
        reason: dao.key,
      );
    }
  });

  test('localImageStore_whenRead_answersTheStore', () {
    expect(
      ProviderContainer.test().read(localImageStoreProvider),
      isA<LocalImageStore>(),
    );
  });
}
