import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/presentation/bookshelf_route.dart';
import 'package:flutter_reader/features/bookshelf/presentation/pages/bookshelf_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_bookshelf_repository.dart';
import '../../../../support/offline_corpus.dart';

void main() {
  group('BookshelfRoute', () {
    test('path_whenShelf_isTheShelfPath', () {
      expect(const BookshelfRoute.shelf().path, '/shelf');
    });
  });

  group('BookshelfPage', () {
    late FakeBookshelfRepository repository;

    setUp(() => repository = FakeBookshelfRepository());

    /// Pumps the page against [repository].
    Future<void> pump(WidgetTester tester) => pumpShelfPage(
      tester,
      page: const BookshelfPage(),
      repository: repository,
    );

    testWidgets('page_whenTheShelfIsEmpty_showsTheEntryHint', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expect(
        find.text(
          localizationOf(tester, find.byType(BookshelfPage)).shelfEmpty,
        ),
        findsOneWidget,
      );
    });

    testWidgets('page_givenBooks_listsThemWithTheirProgress', (
      WidgetTester tester,
    ) async {
      repository
        ..seed(name: '剑来')
        ..seed(
          name: '雪中悍刀行',
          progress: ReadingProgressPosition(
            chapterUrl: 'https://source.test/book/2/3.html',
            chapterName: '第三章',
            updatedAt: DateTime(2026, 10, 20),
          ),
        );

      await pump(tester);

      expect(find.text('剑来'), findsOneWidget);
      expect(find.text('雪中悍刀行'), findsOneWidget);
      // 读过的书显示进度，未读的回落到「在追」（下文用 ARB 文案断言，不写死中文）。
      expect(find.textContaining('第三章'), findsOneWidget);
    });

    testWidgets('page_givenACoveredBook_showsTheCoverAndTheReadBadge', (
      WidgetTester tester,
    ) async {
      // S1（roadmap §3.9）：封面取代了原来的图标位，所以「已读」要变成封面上的角标。
      repository.seed(
        name: '剑来',
        coverUrl: 'https://source.test/covers/1.jpg',
        status: ShelfStatus.read,
      );

      await pump(tester);

      expect(find.byType(CoverImage), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('page_whenTheReadFails_showsTheLoadFailure', (
      WidgetTester tester,
    ) async {
      repository.failReads = true;

      await pump(tester);

      expect(
        find.text(
          localizationOf(tester, find.byType(BookshelfPage)).shelfLoadFailed,
        ),
        findsOneWidget,
      );
    });

    testWidgets('page_whenPinIsChosen_pinsTheEntry', (
      WidgetTester tester,
    ) async {
      repository
        ..seed(name: '剑来')
        ..seed(name: '雪中悍刀行');

      await pump(tester);
      await tester.tap(find.byTooltip('剑来'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          localizationOf(tester, find.byType(BookshelfPage)).shelfActionPin,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        repository.entries
            .singleWhere((ShelvedBook book) => book.name == '剑来')
            .isPinned,
        isTrue,
      );
    });

    testWidgets('page_whenMarkReadIsChosen_movesTheEntry', (
      WidgetTester tester,
    ) async {
      repository.seed(name: '剑来');

      await pump(tester);
      await tester.tap(find.byTooltip('剑来'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          localizationOf(
            tester,
            find.byType(BookshelfPage),
          ).shelfActionMarkRead,
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.entries.single.status, ShelfStatus.read);
    });

    testWidgets('page_whenRemoveIsConfirmed_deletesTheEntry', (
      WidgetTester tester,
    ) async {
      repository.seed(name: '剑来');

      await pump(tester);
      await tester.tap(find.byTooltip('剑来'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          localizationOf(tester, find.byType(BookshelfPage)).shelfActionRemove,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          localizationOf(tester, find.byType(BookshelfPage)).actionDelete,
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.entries, isEmpty);
    });

    testWidgets('page_whenRemoveIsCancelled_keepsTheEntry', (
      WidgetTester tester,
    ) async {
      repository.seed(name: '剑来');

      await pump(tester);
      await tester.tap(find.byTooltip('剑来'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          localizationOf(tester, find.byType(BookshelfPage)).shelfActionRemove,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          localizationOf(tester, find.byType(BookshelfPage)).actionCancel,
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.entries, hasLength(1));
    });

    testWidgets('page_whenAWriteFails_showsTheWriteFailure', (
      WidgetTester tester,
    ) async {
      repository.seed(name: '剑来');

      await pump(tester);
      repository.failWrites = true;
      await tester.tap(find.byTooltip('剑来'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          localizationOf(tester, find.byType(BookshelfPage)).shelfActionPin,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(
          localizationOf(tester, find.byType(BookshelfPage)).shelfWriteFailed,
        ),
        findsOneWidget,
      );
    });
  });
}
