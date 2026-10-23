import 'package:flutter/material.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:flutter_reader/features/reader/presentation/pages/reading_records_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_reading_record_repository.dart';

/// One stored session.
ReadingRecord _record({
  int id = 1,
  DateTime? endedAt,
  int durationSeconds = 600,
}) {
  final DateTime end = endedAt ?? DateTime(2026, 10, 23, 20, 30);

  return ReadingRecord(
    id: id,
    sourceUrl: 'https://source.test',
    bookUrl: 'https://source.test/book/1',
    bookName: '剑来',
    chapterUrl: 'https://source.test/1.html',
    chapterName: '第1章 开端',
    startedAt: end.subtract(Duration(seconds: durationSeconds)),
    endedAt: end,
    durationSeconds: durationSeconds,
  );
}

/// Pumps the page on top of [store].
Future<void> _pump(
  WidgetTester tester,
  FakeReadingRecordRepository store,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        readingRecordRepositoryProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const ReadingRecordsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ReadingRecordsPage)));

void main() {
  group('ReadingRecordsPage', () {
    testWidgets('build_givenNoRecord_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FakeReadingRecordRepository());

      expect(find.text(_l10n(tester).readingRecordsEmpty), findsOneWidget);
    });

    testWidgets('build_givenTwoDays_showsOneSectionPerDay', (
      WidgetTester tester,
    ) async {
      final FakeReadingRecordRepository store = FakeReadingRecordRepository()
        ..records = <ReadingRecord>[
          _record(id: 1, endedAt: DateTime(2026, 10, 23, 20, 30)),
          _record(id: 2, endedAt: DateTime(2026, 10, 21, 9)),
        ];

      await _pump(tester, store);
      final MaterialLocalizations material = MaterialLocalizations.of(
        tester.element(find.byType(ReadingRecordsPage)),
      );

      expect(
        find.text(material.formatFullDate(DateTime(2026, 10, 23))),
        findsOneWidget,
      );
      expect(
        find.text(material.formatFullDate(DateTime(2026, 10, 21))),
        findsOneWidget,
      );
      // 一天的合计与单条会话各占一行：同一天的两条会合并成一行标题 + 两行会话。
      expect(find.text('剑来'), findsNWidgets(2));
    });
  });
}
