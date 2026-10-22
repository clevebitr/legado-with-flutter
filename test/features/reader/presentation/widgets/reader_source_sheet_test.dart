import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/repositories/book_source_switcher.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_source_sheet.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://a.test',
  bookUrl: 'https://a.test/book/0',
  name: '剑来',
  tocUrl: 'https://a.test/book/0',
);

/// A switcher whose candidate list is canned.
final class _FakeSwitcher implements BookSourceSwitcher {
  _FakeSwitcher(this.result);

  final ParseResult<List<ReaderSourceCandidate>> result;

  @override
  Future<ParseResult<List<ReaderSourceCandidate>>> candidates(
    ReaderBook book,
  ) async => result;

  @override
  Future<ParseResult<ReaderSourceSwitch>> switchTo({
    required ReaderBook book,
    required ReaderSourceCandidate candidate,
    required String currentChapterName,
    required int currentChapterIndex,
  }) async => failureAt<ReaderSourceSwitch>(
    kind: ParseFailureKind.unsupportedRule,
    rulePath: 'test.unused',
  );
}

/// Pumps the sheet over [result] and answers the taps it received.
Future<List<Object?>> _pump(
  WidgetTester tester,
  ParseResult<List<ReaderSourceCandidate>> result,
) async {
  final List<Object?> picked = <Object?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        bookSourceSwitcherProvider.overrideWithValue(_FakeSwitcher(result)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                picked.add(
                  await showModalBottomSheet<Object?>(
                    context: context,
                    builder: (BuildContext context) =>
                        const ReaderSourceSheet(book: _book),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return picked;
}

void main() {
  group('ReaderSourceSheet', () {
    testWidgets('build_givenCandidates_listsThemAndAnswersThePick', (
      WidgetTester tester,
    ) async {
      final List<Object?> picked = await _pump(
        tester,
        const ParseSuccess<List<ReaderSourceCandidate>>(<ReaderSourceCandidate>[
          ReaderSourceCandidate(
            sourceUrl: 'https://b.test',
            sourceName: 'B 源',
            bookUrl: 'https://b.test/book/1',
            author: '作者乙',
          ),
        ]),
      );

      expect(find.text('B 源'), findsOneWidget);
      await tester.tap(find.text('B 源'));
      await tester.pumpAndSettle();

      expect(picked.single, isA<ReaderSourceCandidate>());
    });

    testWidgets('build_givenNoCandidate_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ParseSuccess<List<ReaderSourceCandidate>>(
          <ReaderSourceCandidate>[],
        ),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(ReaderSourceSheet)),
      );

      expect(find.text(l10n.readerSourceEmpty), findsOneWidget);
    });

    testWidgets('build_givenAFailingSwitchPort_showsTheFailure', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        failureAt<List<ReaderSourceCandidate>>(
          kind: ParseFailureKind.networkFailed,
          rulePath: 'reader.changeSource',
        ),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(ReaderSourceSheet)),
      );

      expect(find.text(l10n.failureNetworkFailed), findsOneWidget);
    });
  });
}
