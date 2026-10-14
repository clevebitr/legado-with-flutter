import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/offline_corpus.dart';

/// A stored source built from the offline corpus with a distinct name.
BookSource _source(String name) =>
    loadCorpusBookSource().copyWith(name: name, url: 'https://$name.test');

void main() {
  group('SelectedBookSource', () {
    late FakeBookSourceRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeBookSourceRepository();
      container = ProviderContainer(
        overrides: [bookSourceRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    /// Settles the selection and returns it.
    Future<StoredBookSource?> settle() =>
        container.read(selectedBookSourceProvider.future);

    test('build_givenSeveralSources_selectsTheFirstEnabledOne', () async {
      // ADR-0040 §决策 3 的顺序（启用位 → customOrder → id）就是「默认源」的口径。
      repository
        ..add(source: _source('disabled'), isEnabled: false, customOrder: 1)
        ..add(source: _source('later'), customOrder: 5)
        ..add(source: _source('first'), customOrder: 2);

      expect((await settle())?.source.name, 'first');
      expect(container.read(currentBookSourceProvider)?.name, 'first');
    });

    test('build_givenOnlyDisabledSources_selectsNothing', () async {
      repository.add(source: _source('disabled'), isEnabled: false);

      expect(await settle(), isNull);
      expect(container.read(currentBookSourceProvider), isNull);
    });

    test('select_givenAStoredSource_changesTheProjection', () async {
      final StoredBookSource first = repository.add(source: _source('a'));
      final StoredBookSource second = repository.add(source: _source('b'));
      await settle();

      await container
          .read(selectedBookSourceProvider.notifier)
          .select(second.id);

      expect(container.read(currentBookSourceProvider)?.name, 'b');
      expect(first.id, isNot(second.id));
    });

    test('select_givenAnUnknownId_keepsTheCurrentSelection', () async {
      repository
        ..add(source: _source('a'))
        ..add(source: _source('b'));
      await settle();

      await container.read(selectedBookSourceProvider.notifier).select(404);

      expect(container.read(currentBookSourceProvider)?.name, 'a');
    });

    test('remove_givenTheSelectedSource_fallsBackToTheDefault', () async {
      final StoredBookSource first = repository.add(source: _source('a'));
      final StoredBookSource second = repository.add(source: _source('b'));
      await settle();
      await container
          .read(selectedBookSourceProvider.notifier)
          .select(second.id);

      await container
          .read(selectedBookSourceProvider.notifier)
          .remove(second.id);

      // 悬空选择是禁止的：选中的行没了就必须回落到默认源（PLAN.md 5.1）。
      expect(container.read(currentBookSourceProvider)?.name, 'a');
      expect(first.id, isNot(second.id));
    });

    test('remove_givenTheLastSource_leavesNothingSelected', () async {
      final StoredBookSource only = repository.add(source: _source('only'));
      await settle();

      await container.read(selectedBookSourceProvider.notifier).remove(only.id);

      expect(container.read(currentBookSourceProvider), isNull);
    });

    test('remove_givenANonSelectedSource_keepsTheSelection', () async {
      final StoredBookSource first = repository.add(source: _source('a'));
      final StoredBookSource second = repository.add(source: _source('b'));
      await settle();
      await container
          .read(selectedBookSourceProvider.notifier)
          .select(second.id);

      await container
          .read(selectedBookSourceProvider.notifier)
          .remove(first.id);

      expect(container.read(currentBookSourceProvider)?.name, 'b');
    });

    test('toggleEnabled_givenTheSelectedSource_keepsItSelected', () async {
      final StoredBookSource first = repository.add(source: _source('a'));
      await settle();

      await container
          .read(selectedBookSourceProvider.notifier)
          .toggleEnabled(id: first.id, isEnabled: false);

      // 关掉自己不是「删除」：用户的选择保留，列表里那一行显示为已禁用。
      expect(container.read(currentBookSourceProvider)?.name, 'a');
      expect(
        (await container.read(bookSourceListProvider.future)).single.isEnabled,
        isFalse,
      );
    });
  });
}
