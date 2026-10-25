import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/login_form.dart';
import 'package:flutter_reader/features/book_source/domain/login_script.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// A source whose `loginUrl` is [loginUrl].
BookSource _source(String? loginUrl) =>
    BookSource.fromLegadoJson(<String, Object?>{
      'bookSourceName': '示例',
      'bookSourceUrl': 'https://a.test',
      'loginUrl': loginUrl,
      'ruleSearch': <String, Object?>{},
      'ruleToc': <String, Object?>{},
      'ruleContent': <String, Object?>{},
    });

/// A sign-in runner over [js].
SignIn _signIn(FakeJsBridge js) => SignIn(
  js: js,
  logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
);

void main() {
  group('loginScriptOf', () {
    test('loginScriptOf_givenEachUpstreamForm_answersTheScriptOnly', () {
      expect(
        loginScriptOf(_source('@js:function login(){}')),
        'function login(){}',
      );
      expect(
        loginScriptOf(_source('<js>function login(){}</js>')),
        'function login(){}',
      );
      expect(
        loginScriptOf(_source('function login(){}')),
        'function login(){}',
      );
      // 纯地址不是脚本：那是浏览器那条路。
      expect(loginScriptOf(_source('https://a.test/login')), isEmpty);
      expect(loginScriptOf(_source(null)), isEmpty);
    });
  });

  group('SignIn', () {
    test('execute_givenAScript_runsLoginWithTheValuesAsResult', () async {
      // 上游确认时跑的正是 `<login()>\nif (typeof login=='function'){ login.apply(this) }`
      // （ADR-0072 §决策 3），值绑在 `result` 上。
      final FakeJsBridge js = FakeJsBridge();
      final ParseResult<Object?> result = await _signIn(js).execute(
        _source('@js:function login(){ return "ok" }'),
        info: <String, String>{'账号': 'n', '密码': 'p'},
      );

      expect(result, isA<ParseSuccess<Object?>>());
      expect(js.jobs.single.script, startsWith('function login(){'));
      expect(js.jobs.single.script, contains('login.apply(this)'));
      expect(js.jobs.single.result, <String, String>{'账号': 'n', '密码': 'p'});
      // 同一份快照也喂给 `source.getLoginInfo*`（ADR-0072 §决策 3）。
      expect(js.jobs.single.loginInfo, <String, String>{'账号': 'n', '密码': 'p'});
    });

    test('execute_givenNoScript_failsInsteadOfRunningNothing', () async {
      final FakeJsBridge js = FakeJsBridge();
      final ParseResult<Object?> result = await _signIn(js).execute(
        _source('https://a.test/login'),
        info: const <String, String>{},
      );

      expect(
        result,
        isA<ParseFailure<Object?>>().having(
          (ParseFailure<Object?> failure) => failure.kind,
          'kind',
          ParseFailureKind.unsupportedRule,
        ),
      );
      expect(js.jobs, isEmpty);
    });

    test('runAction_givenAScriptButton_runsItOnTopOfLogin', () async {
      final FakeJsBridge js = FakeJsBridge();

      await _signIn(js).runAction(
        const LoginField(
          name: '发送验证码',
          title: '发送验证码',
          type: LoginFieldType.button,
          action: 'sendCode()',
        ),
        source: _source('@js:function login(){}'),
        info: <String, String>{'账号': 'n'},
      );

      expect(js.jobs.single.script, contains('function login(){}'));
      expect(js.jobs.single.script, contains('sendCode()'));
      expect(js.jobs.single.rulePath, 'loginUi.action');
    });

    test('execute_givenABrokenScript_answersTheFailure', () async {
      final FakeJsBridge js = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'js.error',
        );

      final ParseResult<Object?> result = await _signIn(js).execute(
        _source('@js:function login(){}'),
        info: const <String, String>{},
      );

      expect(result, isA<ParseFailure<Object?>>());
    });
  });
}
