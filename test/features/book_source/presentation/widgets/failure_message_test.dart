import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/failure_message.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveFailureMessage', () {
    testWidgets(
      'resolveFailureMessage_givenEveryDisplayableKind_returnsDistinctText',
      (WidgetTester tester) async {
        final AppLocalizations l10n = await _l10n(tester);
        final List<String> messages = <String>[];

        for (final ParseFailureKind kind in ParseFailureKind.values) {
          final String message = resolveFailureMessage(l10n, kind);
          if (kind == ParseFailureKind.cancelled) {
            // 取消是静默的（`book-source.md` §7）：没有文案键，也就没有文案。
            expect(message, isEmpty);
            continue;
          }
          expect(message, isNotEmpty, reason: '${kind.name} needs a message.');
          messages.add(message);
        }

        expect(messages, hasLength(8));
        expect(
          messages.toSet(),
          hasLength(8),
          reason: 'Every kind needs its own message (C-ERR-7).',
        );
      },
    );

    testWidgets(
      'resolveFailureMessage_givenUnsupportedRule_showsThatKindText',
      (WidgetTester tester) async {
        final AppLocalizations l10n = await _l10n(tester);

        expect(
          resolveFailureMessage(l10n, ParseFailureKind.unsupportedRule),
          l10n.failureUnsupportedRule,
        );
      },
    );
  });

  group('FailureMessage', () {
    testWidgets('build_givenARetryCallback_showsTheRetryAction', (
      WidgetTester tester,
    ) async {
      var retried = 0;

      await tester.pumpWidget(
        _shell(
          FailureMessage(
            kind: ParseFailureKind.parseFailed,
            onRetry: () => retried++,
          ),
        ),
      );

      final AppLocalizations l10n = _localization(tester);

      expect(find.text(l10n.failureParseFailed), findsOneWidget);
      await tester.tap(find.text(l10n.actionRetry));
      expect(retried, 1);
    });

    testWidgets('build_givenNoRetryCallback_hidesTheRetryAction', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _shell(const FailureMessage(kind: ParseFailureKind.notFound)),
      );

      expect(
        find.text(_localization(tester).actionRetry),
        findsNothing,
        reason: '搜索页用搜索按钮重试，因此不给失败块加重试动作。',
      );
    });
  });
}

Widget _shell(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Future<AppLocalizations> _l10n(WidgetTester tester) async {
  await tester.pumpWidget(_shell(const SizedBox.shrink()));

  return _localization(tester);
}

AppLocalizations _localization(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold)));
