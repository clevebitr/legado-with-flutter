import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/js_bridge_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_login_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_js_bridge.dart';

/// A source whose login form is [loginUi] and whose `login()` is [loginUrl].
BookSource _source({
  String? loginUi,
  String loginUrl = '@js:function login(){}',
}) => BookSource.fromLegadoJson(<String, Object?>{
  'bookSourceName': '示例源',
  'bookSourceUrl': 'https://a.test',
  'loginUrl': loginUrl,
  'loginUi': loginUi,
  'ruleSearch': <String, Object?>{},
  'ruleToc': <String, Object?>{},
  'ruleContent': <String, Object?>{},
});

/// Pumps the page over a repository holding [source].
Future<({FakeBookSourceRepository repository, FakeJsBridge js})> _pump(
  WidgetTester tester, {
  required BookSource source,
  FakeJsBridge? js,
}) async {
  final FakeBookSourceRepository repository = FakeBookSourceRepository()
    ..add(source: source);
  final FakeJsBridge bridge = js ?? FakeJsBridge();
  final int id = (await repository.getAll()).single.id;

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        bookSourceRepositoryProvider.overrideWithValue(repository),
        jsBridgeProvider.overrideWithValue(bridge),
        appLoggerProvider.overrideWithValue(AppLogger()),
        sourceVerificationProvider.overrideWithValue(
          const UnboundSourceVerification(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: BookSourceLoginPage(sourceId: id),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (repository: repository, js: bridge);
}

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(BookSourceLoginPage)));

void main() {
  group('BookSourceLoginPage', () {
    testWidgets('build_givenALiteralForm_rendersEveryRow', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        source: _source(
          loginUi: '''
[
  {"name":"账号","type":"text","viewName":"'账号'"},
  {"name":"密码","type":"password","viewName":"'密码'"},
  {"name":"记住","type":"toggle","viewName":"'记住我'"},
  {"name":"线路","type":"select","chars":["A","B"],"viewName":"'线路'"},
  {"name":"发送验证码","type":"button","viewName":"'发送验证码'","action":"sendCode()"}
]''',
        ),
      );

      expect(find.text('账号'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '发送验证码'), findsOneWidget);
      expect(find.text(_l10n(tester).actionSave), findsOneWidget);
    });

    testWidgets('submit_whenPressed_storesTheValuesAndRunsLogin', (
      WidgetTester tester,
    ) async {
      final ({FakeBookSourceRepository repository, FakeJsBridge js}) fixture =
          await _pump(
            tester,
            source: _source(
              loginUi:
                  '[{"name":"账号","viewName":"\'账号\'"},'
                  '{"name":"密码","type":"password","viewName":"\'密码\'"}]',
            ),
          );

      await tester.enterText(find.byType(TextField).first, 'reader');
      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.tap(find.text(_l10n(tester).actionSave));
      await tester.pumpAndSettle();

      expect(fixture.repository.loginInfos.values.single, <String, String>{
        '账号': 'reader',
        '密码': 'secret',
      });
      expect(fixture.js.jobs.single.result, <String, String>{
        '账号': 'reader',
        '密码': 'secret',
      });
      expect(find.text(_l10n(tester).bookSourceLoginDone), findsOneWidget);
    });

    testWidgets('build_givenAStoredLogin_prefillsTheFields', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source(loginUi: '[{"name":"账号"}]'));
      final int id = (await repository.getAll()).single.id;
      await repository.saveLoginInfo(id, <String, String>{'账号': '已保存'});

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            bookSourceRepositoryProvider.overrideWithValue(repository),
            jsBridgeProvider.overrideWithValue(FakeJsBridge()),
            appLoggerProvider.overrideWithValue(AppLogger()),
            sourceVerificationProvider.overrideWithValue(
              const UnboundSourceVerification(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildReaderTheme(fallbackLightColorScheme()),
            home: BookSourceLoginPage(sourceId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已保存'), findsOneWidget);
    });

    testWidgets('build_givenNoForm_explainsIt', (WidgetTester tester) async {
      await _pump(tester, source: _source(loginUrl: 'https://a.test/login'));

      expect(find.text(_l10n(tester).bookSourceLoginNoForm), findsOneWidget);
    });

    testWidgets('submit_whenTheScriptFails_showsTheFailure', (
      WidgetTester tester,
    ) async {
      final FakeJsBridge js = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'loginUrl',
        );
      await _pump(
        tester,
        source: _source(loginUi: '[{"name":"账号"}]'),
        js: js,
      );

      await tester.tap(find.text(_l10n(tester).actionSave));
      await tester.pumpAndSettle();

      expect(find.text(_l10n(tester).failureParseFailed), findsOneWidget);
    });
  });
}
