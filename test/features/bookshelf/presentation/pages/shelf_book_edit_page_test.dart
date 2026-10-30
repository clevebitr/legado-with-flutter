import 'package:flutter/material.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/presentation/pages/shelf_book_edit_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_bookshelf_repository.dart';
import '../../../../support/offline_corpus.dart';

void main() {
  group('ShelfBookEditPage', () {
    late FakeBookshelfRepository repository;
    late ShelvedBook book;

    setUp(() {
      repository = FakeBookshelfRepository();
      book = repository.seed(name: '朝花夕拾（错名）', groupId: null);
    });

    /// Pumps the editor over the seeded row.
    Future<void> pump(WidgetTester tester) => pumpShelfPage(
      tester,
      page: ShelfBookEditPage(book: book),
      repository: repository,
    );

    testWidgets('save_whenTheTitleIsBlank_keepsThePageAndSaysWhy', (
      WidgetTester tester,
    ) async {
      // 空书名会让书架出现一行「没有名字」——与「书源抓不到标题」是同一个坑。
      await pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(ShelfBookEditPage)),
      );

      await tester.enterText(find.byType(TextFormField).first, '   ');
      await tester.tap(find.text(l10n.shelfEditSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.shelfEditNameRequired), findsOneWidget);
      expect(find.byType(ShelfBookEditPage), findsOneWidget);
      expect(repository.entries.single.name, '朝花夕拾（错名）');
    });

    testWidgets('save_whenFilled_writesTitleAuthorAndIntro', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(ShelfBookEditPage)),
      );

      await tester.enterText(find.byType(TextFormField).at(0), '朝花夕拾');
      await tester.enterText(find.byType(TextFormField).at(1), '鲁迅');
      await tester.enterText(find.byType(TextFormField).at(2), '我自己的简介');
      await tester.tap(find.text(l10n.shelfEditSave));
      await tester.pumpAndSettle();

      final ShelvedBook saved = repository.entries.single;
      expect(saved.name, '朝花夕拾');
      expect(saved.author, '鲁迅');
      expect(saved.customIntro, '我自己的简介');
      // 保存成功就回到书架（这里是根路由，页面消失即为关闭）。
      expect(find.byType(ShelfBookEditPage), findsNothing);
    });

    testWidgets('save_whenTheIntroIsCleared_storesNullSoTheSnapshotShows', (
      WidgetTester tester,
    ) async {
      await repository.updateDetails(
        id: book.id,
        name: book.name,
        author: '旧作者',
        customIntro: '旧简介',
      );
      await pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(ShelfBookEditPage)),
      );

      // 简介留空 = 回到书源简介：存 null，而不是空串。
      await tester.enterText(find.byType(TextFormField).at(2), '');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.tap(find.text(l10n.shelfEditSave));
      await tester.pumpAndSettle();

      expect(repository.entries.single.customIntro, isNull);
      expect(repository.entries.single.author, isNull);
    });
  });
}
