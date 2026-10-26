import 'package:drift/native.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/features/bookshelf/data/bookshelf_repository_impl.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bookshelfRepository_whenRead_wiresTheDriftDao', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseExecutorProvider.overrideWithValue(NativeDatabase.memory()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(bookshelfRepositoryProvider),
      isA<BookshelfRepositoryImpl>(),
    );
  });
}
