import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/login_form.dart';
import 'package:flutter_reader/features/book_source/domain/login_script.dart';

/// Runs a source's own sign-in script (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
///
/// Two entry points, both upstream's:
///
/// * **confirm** — after the form's values are stored, `<login() script>` plus
///   `if (typeof login == 'function') { login.apply(this) } else { throw ... }`. The script reads the
///   values as `result` (a map) and does whatever signing in means for this site: a `http.post`, a
///   `java.startBrowserAwait` for a captcha, or nothing but a header write.
/// * **a button row's `action`** — the same script followed by the action's own script, so
///   「发送验证码」-style buttons work without a second mechanism.
///
/// The values are also on the job's `loginInfo`, so `source.getLoginInfo()` / `getLoginInfoMap()`
/// answer the same snapshot the form was filled with.
final class SignIn {
  /// Creates the use case.
  const SignIn({required this._js, required this._logger});

  final JsBridge _js;
  final AppLogger _logger;

  /// Runs the source's `login()` with [info] as its values.
  Future<ParseResult<Object?>> execute(
    BookSource source, {
    required Map<String, String> info,
    String bookName = '',
    String bookUrl = '',
  }) => _run(
    source,
    info: info,
    tail: _confirmTail,
    rulePath: 'loginUrl',
    bookName: bookName,
    bookUrl: bookUrl,
  );

  /// Runs one button row's `action`.
  ///
  /// An `action` that is an absolute address is **not** run here: the page opens it in the browser
  /// (a JS `open` from the sandbox cannot show a page), so this use case only sees scripts.
  Future<ParseResult<Object?>> runAction(
    LoginField field, {
    required BookSource source,
    required Map<String, String> info,
    String bookName = '',
    String bookUrl = '',
  }) {
    final String action = field.action ?? '';

    return _run(
      source,
      info: info,
      tail: action,
      rulePath: 'loginUi.action',
      bookName: bookName,
      bookUrl: bookUrl,
    );
  }

  /// Upstream's exact tail: a source that declares `loginUrl` but no `login()` is an error there too.
  static const String _confirmTail =
      "if (typeof login=='function'){ login.apply(this); } "
      "else { throw 'Function login not implements!!!' }";

  Future<ParseResult<Object?>> _run(
    BookSource source, {
    required Map<String, String> info,
    required String tail,
    required String rulePath,
    required String bookName,
    required String bookUrl,
  }) async {
    final String script = loginScriptOf(source);
    if (script.isEmpty) {
      // `loginUi` 有表单、`loginUrl` 却不是脚本：上游同样到这一步才发现没人能登录。
      _logger.warning('The source declares no login() script: ${source.name}');

      return failureAt<Object?>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: rulePath,
      );
    }

    return _js.evaluate(
      JsJob(
        script: '$script\n$tail',
        rulePath: rulePath,
        baseUrl: source.url,
        page: 1,
        source: source.jsSourceInfo,
        bookName: bookName.isEmpty ? null : bookName,
        book: JsBookInfo(name: bookName, bookUrl: bookUrl),
        result: info,
        loginInfo: info,
      ),
    );
  }
}
