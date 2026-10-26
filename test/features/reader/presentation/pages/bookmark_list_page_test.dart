import 'package:flutter/material.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:flutter_reader/features/reader/presentation/pages/bookmark_list_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_bookmark_repository.dart';

/// One stored bookmark, defaulting everything but the offset.
Bookmark _bookmark({int id = 1, int charOffset = 0, String? excerpt}) =>
    Bookmark(
      id: id,
      sourceUrl: 'https://source.test',
      bookUrl: 'https://source.test/book/1',
      bookName: '剑来',
      tocUrl: 'https://source.test/book/1/toc',
      chapterUrl: 'https://source.test/1.html',
      chapterName: '第1章 开端',
      charOffset: charOffset,
      excerpt: excerpt,
      createdAt: DateTime(2026, 10, 23, 20),
    );

/// Pumps the page on top of [store].
Future<void> _pump(WidgetTester tester, FakeBookmarkRepository store) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        bookmarkRepositoryProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const BookmarkListPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(BookmarkListPage)));

void main() {
  group('BookmarkListPage', () {
    testWidgets('build_givenNoBookmark_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FakeBookmarkRepository());

      expect(find.text(_l10n(tester).bookmarkEmpty), findsOneWidget);
    });

    testWidgets('build_givenABookmark_showsBookChapterAndExcerpt', (
      WidgetTester tester,
    ) async {
      final FakeBookmarkRepository store = FakeBookmarkRepository()
        ..bookmarks.add(_bookmark(excerpt: '正文摘录'));

      await _pump(tester, store);

      expect(find.text('剑来'), findsOneWidget);
      expect(find.textContaining('第1章 开端'), findsOneWidget);
      expect(find.textContaining('正文摘录'), findsOneWidget);
    });

    testWidgets('tapDelete_whenTheRowIsDeleted_removesAndReloads', (
      WidgetTester tester,
    ) async {
      final FakeBookmarkRepository store = FakeBookmarkRepository()
        ..bookmarks.add(_bookmark());

      await _pump(tester, store);
      await tester.tap(find.byTooltip(_l10n(tester).bookmarkDeleteAction));
      await tester.pumpAndSettle();

      expect(store.removed, <int>[1]);
      expect(find.text(_l10n(tester).bookmarkEmpty), findsOneWidget);
    });
  });
}
