import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/login_form.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/resolve_login_form.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// A source whose `loginUrl` / `loginUi` are the ones under test.
BookSource _source({String? loginUrl, String? loginUi}) =>
    BookSource.fromLegadoJson(<String, Object?>{
      'bookSourceName': '示例',
      'bookSourceUrl': 'https://a.test',
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'ruleSearch': <String, Object?>{},
      'ruleToc': <String, Object?>{},
      'ruleContent': <String, Object?>{},
    });

/// Resolves [source]'s form with [js] and unwraps it.
Future<LoginForm> _resolve(
  BookSource source, {
  JsBridge? js,
  Map<String, String> loginInfo = const <String, String>{},
}) async {
  final ParseResult<LoginForm> resolved = await ResolveLoginForm(
    js: js ?? FakeJsBridge(),
    logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
  ).execute(source, loginInfo: loginInfo);

  return switch (resolved) {
    ParseSuccess<LoginForm>(:final LoginForm data) => data,
    ParseFailure<LoginForm>(:final ParseFailureKind kind) => fail(
      'the form should resolve ($kind)',
    ),
  };
}

void main() {
  group('ResolveLoginForm', () {
    test('execute_givenLiteralLoginUi_rendersEveryRowType', () async {
      // 上游 `RowUi`：text / password / toggle / select / button，`chars` 是选项，
      // `button` 的 `action` 不属于取值（ADR-0072 §决策 3）。
      final LoginForm form = await _resolve(
        _source(
          loginUrl: 'https://a.test/login',
          loginUi: '''
[
  {"name":"账号","type":"text","viewName":"'账号'","default":"n"},
  {"name":"密码","type":"password"},
  {"name":"记住","type":"toggle"},
  {"name":"线路","type":"select","chars":["A","B"]},
  {"name":"登录","type":"button","action":"doLogin()"}
]''',
        ),
      );

      expect(
        form.fields.map((LoginField field) => field.type),
        <LoginFieldType>[
          LoginFieldType.text,
          LoginFieldType.password,
          LoginFieldType.toggle,
          LoginFieldType.select,
          LoginFieldType.button,
        ],
      );
      expect(form.fields.first.title, '账号');
      expect(form.fields.first.initialValue, 'n');
      expect(form.fields[3].options, <String>['A', 'B']);
      expect(form.fields.last.action, 'doLogin()');
      expect(form.hasInputs, isTrue);
    });

    test('execute_givenStoredValues_seedsTheFormFromThem', () async {
      final LoginForm form = await _resolve(
        _source(loginUi: '[{"name":"账号"}]'),
        loginInfo: <String, String>{'账号': '已保存'},
      );

      expect(form.fields.single.initialValue, '已保存');
    });

    test('execute_givenAQuotedViewName_usesItAsTheTitle', () async {
      final LoginForm form = await _resolve(
        _source(loginUi: '[{"name":"user","viewName":"\'用户名\'"}]'),
      );

      expect(form.fields.single.title, '用户名');
    });

    test('execute_givenAScriptViewName_evaluatesIt', () async {
      final FakeJsBridge js = FakeJsBridge()..result = '动态标题';
      final LoginForm form = await _resolve(
        _source(loginUi: '[{"name":"user","viewName":"titleOf()"}]'),
        js: js,
      );

      expect(form.fields.single.title, '动态标题');
      // 上游把 `login()` 脚本拼在表单脚本前面：`loginUrl` 里的函数才看得见。
      expect(js.jobs.single.script, contains('titleOf()'));
    });

    test('execute_givenAScriptLoginUi_parsesWhatTheScriptAnswers', () async {
      final FakeJsBridge js = FakeJsBridge()..result = '[{"name":"token"}]';
      final LoginForm form = await _resolve(
        _source(loginUrl: '@js:function login(){}', loginUi: '@js:buildForm()'),
        js: js,
      );

      expect(form.fields.single.name, 'token');
      expect(js.jobs.single.script, startsWith('function login(){}'));
    });

    test('execute_givenAScriptAnsweringAList_usesItDirectly', () async {
      // 有的源让脚本直接返回数组（不是 JSON 文本）；两种都认。
      final FakeJsBridge js = FakeJsBridge()
        ..result = <Object?>[
          <String, Object?>{'name': 'token'},
        ];
      final LoginForm form = await _resolve(
        _source(loginUrl: '@js:function login(){}', loginUi: '@js:buildForm()'),
        js: js,
      );

      expect(form.fields.single.name, 'token');
    });

    test('execute_givenAnAngleBracketLoginUi_readsItAsAScript', () async {
      final FakeJsBridge js = FakeJsBridge()..result = '[{"name":"t"}]';
      final LoginForm form = await _resolve(
        _source(
          loginUrl: '<js>function login(){}</js>',
          loginUi: '<js>build()</js>',
        ),
        js: js,
      );

      expect(form.fields.single.name, 't');
      expect(js.jobs.single.script, contains('function login(){}'));
      expect(js.jobs.single.script, contains('build()'));
    });

    test('execute_givenAFailingTitleScript_fallsBackToTheName', () async {
      // 标题只是展示：脚本挂了就用 `name`，不该让整张表单不可用。
      final JsBridge failing = _TitleFirstBridge();

      final LoginForm form = await _resolve(
        _source(loginUi: '[{"name":"user","viewName":"titleOf()"}]'),
        js: failing,
      );

      expect(form.fields.single.title, 'user');
    });

    test('execute_givenNoLoginUi_answersAnEmptyForm', () async {
      final LoginForm form = await _resolve(
        _source(loginUrl: 'https://a.test/login'),
      );

      expect(form.isEmpty, isTrue);
    });

    test('execute_givenARowWithoutAName_skipsIt', () async {
      final LoginForm form = await _resolve(
        _source(loginUi: '[{"type":"text"},{"name":"ok"}]'),
      );

      expect(form.fields.single.name, 'ok');
    });

    test('execute_givenAnUnknownType_fallsBackToText', () async {
      final LoginForm form = await _resolve(
        _source(loginUi: '[{"name":"x","type":"slider"}]'),
      );

      expect(form.fields.single.type, LoginFieldType.text);
    });

    test('execute_givenABrokenScript_failsWithItsPath', () async {
      final FakeJsBridge js = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'js.error',
        );

      final ParseResult<LoginForm> resolved = await ResolveLoginForm(
        js: js,
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ).execute(_source(loginUi: '@js:buildForm()'));

      expect(
        resolved,
        isA<ParseFailure<LoginForm>>().having(
          (ParseFailure<LoginForm> failure) => failure.rulePath,
          'rulePath',
          'loginUi',
        ),
      );
    });

    test('execute_givenTextThatIsNotJson_failsWithItsPath', () async {
      final ParseResult<LoginForm> resolved = await ResolveLoginForm(
        js: FakeJsBridge(),
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ).execute(_source(loginUi: '[oops'));

      expect(resolved, isA<ParseFailure<LoginForm>>());
    });
  });
}

/// A bridge whose **first** job (the title script) fails and whose second (the document) succeeds.
final class _TitleFirstBridge implements JsBridge {
  int _calls = 0;

  @override
  Future<ParseResult<Object?>> evaluate(JsJob job) async {
    _calls++;
    if (_calls == 1) {
      return failureAt<Object?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'loginUi.viewName',
      );
    }

    return const ParseSuccess<Object?>(
      '[{"name":"user","viewName":"titleOf()"}]',
    );
  }

  @override
  Future<void> dispose() async {}
}
