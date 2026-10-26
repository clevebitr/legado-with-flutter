import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_login.dart';
import 'package:flutter_test/flutter_test.dart';

/// A source with only the fields the login guard reads.
BookSource _source({String? loginUrl, String? loginUi, String? loginCheckJs}) =>
    BookSource(
      name: '示例书源',
      url: 'https://example-novel.test',
      loginUrl: loginUrl,
      loginUi: loginUi,
      loginCheckJs: loginCheckJs,
      searchRule: const SearchRule(bookList: 'class.result'),
      tocRule: const TocRule(chapterList: 'class.c'),
      contentRule: const ContentRule(content: 'class.body'),
    );

void main() {
  group('SourceLoginGuard', () {
    test('givenNoField_isNotDeclared', () {
      const SourceLoginGuard guard = SourceLoginGuard.none();

      expect(guard.hasCheck, isFalse);
      expect(guard.canSignIn, isFalse);
      expect(guard.isDeclared, isFalse);
      expect(guard.checkScript, isNull);
    });

    test('givenABlankCheckScript_hasNoCheck', () {
      // 真实导出里空串极多（脱敏语料的三个字段都是 ''）：空白的脚本不是拦截器。
      const SourceLoginGuard guard = SourceLoginGuard(checkScript: '  \n ');

      expect(guard.hasCheck, isFalse);
      expect(guard.isDeclared, isFalse);
    });

    test('givenACheckScript_onlyTheCheckIsDeclared', () {
      const SourceLoginGuard guard = SourceLoginGuard(checkScript: 'result');

      expect(guard.hasCheck, isTrue);
      expect(guard.canSignIn, isFalse);
      expect(guard.isDeclared, isTrue);
    });

    test('givenLoginUrl_canSignIn', () {
      const SourceLoginGuard guard = SourceLoginGuard(
        loginUrl: 'https://example-novel.test/login',
      );

      expect(guard.canSignIn, isTrue);
      expect(guard.hasCheck, isFalse);
    });

    test('givenLoginUi_canSignIn', () {
      // `loginUi` 一个 JSON 串也算「声明了怎么登录」：登录表单 UI 归 M21b，但能力在这里就成立。
      const SourceLoginGuard guard = SourceLoginGuard(
        loginUi: '[{"name":"账号"}]',
      );

      expect(guard.canSignIn, isTrue);
    });

    test('givenBlankLoginFields_cannotSignIn', () {
      const SourceLoginGuard guard = SourceLoginGuard(
        loginUrl: '',
        loginUi: ' ',
      );

      expect(guard.canSignIn, isFalse);
    });

    test('BookSource_loginGuard_carriesTheThreeFields', () {
      final SourceLoginGuard guard = _source(
        loginUrl: 'https://example-novel.test/login',
        loginUi: '[]',
        loginCheckJs: 'result',
      ).loginGuard;

      expect(guard.hasCheck, isTrue);
      expect(guard.canSignIn, isTrue);
      expect(guard.loginUrl, 'https://example-novel.test/login');
      expect(guard.loginUi, '[]');
    });
  });

  group('readLoginCheckResult', () {
    ParseResult<LoginReplacement?> read(Object? value) =>
        readLoginCheckResult(value);

    test('givenNull_keepsTheResponse', () {
      final ParseResult<LoginReplacement?> result = read(null);

      expect(result, isA<ParseSuccess<LoginReplacement?>>());
      expect((result as ParseSuccess<LoginReplacement?>).data, isNull);
    });

    test('givenAString_replacesTheBodyButKeepsTheUrl', () {
      final ParseResult<LoginReplacement?> result = read('<div>正文</div>');

      final LoginReplacement replacement =
          (result as ParseSuccess<LoginReplacement?>).data!;
      expect(replacement.body, '<div>正文</div>');
      expect(replacement.url, isNull);
    });

    test('givenASandboxResponse_takesTheBodyAndUrl', () {
      // 沙箱原样 `return result` 时宿主收到的就是这一形（方法不可枚举，只剩数据）。
      final ParseResult<LoginReplacement?> result = read(<String, Object?>{
        '__strResponse': true,
        'body': '<div>after-login</div>',
        '__url': 'https://example-novel.test/book/1/after',
        '__code': 200,
      });

      final LoginReplacement replacement =
          (result as ParseSuccess<LoginReplacement?>).data!;
      expect(replacement.body, '<div>after-login</div>');
      expect(replacement.url, 'https://example-novel.test/book/1/after');
    });

    test('givenAPlainUrlBodyObject_takesTheUrlKey', () {
      // `java.startBrowserAwait` 答的是 `{url, body}`（上游 StrResponse 的两个字段）。
      final ParseResult<LoginReplacement?> result = read(<Object?, Object?>{
        'url': 'https://example-novel.test/after',
        'body': 'ok',
      });

      final LoginReplacement replacement =
          (result as ParseSuccess<LoginReplacement?>).data!;
      expect(replacement.url, 'https://example-novel.test/after');
    });

    test('givenABlankUrl_leavesTheAddressAlone', () {
      final ParseResult<LoginReplacement?> result = read(<String, Object?>{
        'body': 'ok',
        '__url': '  ',
      });

      expect((result as ParseSuccess<LoginReplacement?>).data?.url, isNull);
    });

    test('givenAnObjectWithoutABody_isNotAResponse', () {
      final ParseResult<LoginReplacement?> result = read(<String, Object?>{
        'url': 'https://example-novel.test/',
      });

      expect(result, isA<ParseFailure<LoginReplacement?>>());
      expect(
        (result as ParseFailure<LoginReplacement?>).kind,
        ParseFailureKind.parseFailed,
      );
      expect(result.rulePath, 'loginCheckJs');
    });

    test('givenABoolean_isNotAResponse', () {
      // 上游对此报 `loginCheckJs did not return StrResponse`；布尔不是响应。
      final ParseResult<LoginReplacement?> result = read(true);

      expect(result, isA<ParseFailure<LoginReplacement?>>());
    });

    test('givenAList_isNotAResponse', () {
      final ParseResult<LoginReplacement?> result = read(<Object?>['body']);

      expect(result, isA<ParseFailure<LoginReplacement?>>());
    });
  });
}
