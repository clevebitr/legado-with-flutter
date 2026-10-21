import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_book_source_repository.dart';
import '../../support/offline_corpus.dart';

void main() {
  group('currentBookSource', () {
    test(
      'read_givenNoStoredSource_returnsNullSoThePagesShowAnEmptyState',
      () async {
        // 接缝在 5.1 之后由仓储填充（ADR-0021 复审注记）；库是空的时它必须仍然是 null，
        // 页面因此走空态，而不是拿一个空规则集去请求（docs/dev/roadmap.md 2.5）。
        final ProviderContainer container = ProviderContainer(
          overrides: [
            bookSourceRepositoryProvider.overrideWithValue(
              FakeBookSourceRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(selectedBookSourceProvider.future);

        expect(container.read(currentBookSourceProvider), isNull);
      },
    );

    test('read_givenAStoredSource_projectsItAsTheCurrentOne', () async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: loadCorpusBookSource());
      final ProviderContainer container = ProviderContainer(
        overrides: [bookSourceRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(selectedBookSourceProvider.future);

      expect(container.read(currentBookSourceProvider)?.url, isNotEmpty);
      expect(
        container.read(currentBookSourceProvider)?.name,
        loadCorpusBookSource().name,
      );
    });
  });
}
