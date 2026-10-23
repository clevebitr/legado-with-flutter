import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_edit_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/offline_corpus.dart';

/// The corpus source under a name a test can assert on.
BookSource _source(String name) =>
    loadCorpusBookSource().copyWith(name: name, url: 'https://$name.test');

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(BookSourceEditPage));

/// Pumps the editor for [source] inside [repository].
Future<void> _pump(
  WidgetTester tester,
  FakeBookSourceRepository repository,
  StoredBookSource source,
) => pumpSourceManagementPage(
  tester,
  page: BookSourceEditPage(sourceId: source.id),
  repository: repository,
);

void main() {
  group('BookSourceEditPage', () {
    testWidgets('build_givenAStoredSource_fillsTheFields', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final StoredBookSource stored = repository.add(
        source: _source('原名'),
        weight: 7,
      );

      await _pump(tester, repository, stored);

      expect(find.text('原名'), findsOneWidget);
      expect(find.text('https://原名.test'), findsOneWidget);
    });

    testWidgets('save_givenAChangedName_writesItAndKeepsUserState', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final StoredBookSource stored = repository.add(
        source: _source('原名'),
        isEnabled: false,
      );
      await _pump(tester, repository, stored);

      await tester.enterText(find.widgetWithText(TextField, '原名').first, '新名');
      await tester.pump();
      await tester.tap(find.text(_l10n(tester).actionSave));
      await tester.pumpAndSettle();

      final StoredBookSource saved = (await repository.getAll()).single;
      expect(saved.source.name, '新名');
      // 用户态不被编辑重置（ADR-0050 §决策 3）。
      expect(saved.isEnabled, isFalse);
    });

    testWidgets('save_givenAnUnreadableRuleBlock_refusesToWrite', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final StoredBookSource stored = repository.add(source: _source('原名'));
      await _pump(tester, repository, stored);
      final AppLocalizations l10n = _l10n(tester);

      // 「搜索规则」是 JSON 文本域：写坏它就不许保存（ADR-0022 的模型裁决）。
      final Finder searchRuleField = find.widgetWithText(
        TextField,
        l10n.bookSourceFieldSearchRule,
      );
      await tester.enterText(searchRuleField, '{oops');
      await tester.pump();
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect((await repository.getAll()).single.source.name, '原名');
      expect(find.text(l10n.bookSourceEditInvalidFields), findsWidgets);
    });

    testWidgets('save_givenAnIdentityThatDuplicatesAnotherRow_reportsIt', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('甲'))
        ..add(source: _source('乙'));
      final StoredBookSource first = (await repository.getAll()).first;

      await _pump(tester, repository, first);
      final AppLocalizations l10n = _l10n(tester);
      // 把甲改成与乙完全一致（名称与 URL 都改）：指纹重合 → 显式失败。
      await tester.enterText(
        find.widgetWithText(TextField, l10n.bookSourceFieldName),
        '乙',
      );
      await tester.enterText(
        find.widgetWithText(TextField, l10n.bookSourceFieldUrl),
        'https://乙.test',
      );
      await tester.pump();
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceEditIdentityConflict), findsOneWidget);
      expect(await repository.getAll(), hasLength(2));
    });
  });
}
