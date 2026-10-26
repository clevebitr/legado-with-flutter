import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/login_form.dart';
import 'package:flutter_reader/features/book_source/domain/login_script.dart';

/// Turns a source's `loginUi` into a renderable form
/// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
///
/// Three things are resolved here, because two of them may need the sandbox and the page must not
/// know about scripts at all:
///
/// 1. `loginUi` itself may be `@js:` / `<js>` — upstream evaluates it with the source's `login()`
///    script prepended and expects the JSON array back;
/// 2. every row's `viewName` is either a quoted literal or a script evaluated with `result` = the
///    current login info (so a title can say「剩余 3 次」);
/// 3. `type` decides the control, and upstream's `button` rows carry an `action` instead of a value.
///
/// Degradation: a row this build cannot read is **skipped**, and a document that is not an array
/// answers an empty form — a broken login form must not stop the user from using the source.
final class ResolveLoginForm {
  /// Creates the use case.
  const ResolveLoginForm({required this._js, required this._logger});

  final JsBridge _js;
  final AppLogger _logger;

  /// Resolves [source]'s form, with [loginInfo] as the current values.
  ///
  /// A source that declares no `loginUi` answers an empty form (the page then offers the browser
  /// route instead).
  Future<ParseResult<LoginForm>> execute(
    BookSource source, {
    Map<String, String> loginInfo = const <String, String>{},
    String bookName = '',
    String bookUrl = '',
  }) async {
    final String? raw = source.loginUi;
    if (raw == null || raw.trim().isEmpty) {
      return const ParseSuccess<LoginForm>(LoginForm(fields: <LoginField>[]));
    }

    final ParseResult<Object?> document = await _documentOf(
      raw,
      source: source,
      loginInfo: loginInfo,
      bookName: bookName,
      bookUrl: bookUrl,
    );
    final List<Object?> rows;
    switch (document) {
      case ParseFailure<Object?>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        _logger.warning('loginUi could not be resolved: ${kind.name}');

        return failureAt<LoginForm>(kind: kind, rulePath: failedAt);
      case ParseSuccess<Object?>(:final Object? data):
        rows = data is List<Object?> ? data : const <Object?>[];
    }

    final List<LoginField> fields = <LoginField>[];
    for (final Object? row in rows) {
      if (row is! Map<String, Object?>) {
        continue;
      }
      final LoginField? field = await _fieldOf(
        row,
        source: source,
        loginInfo: loginInfo,
        bookName: bookName,
        bookUrl: bookUrl,
      );
      if (field != null) {
        fields.add(field);
      }
    }

    return ParseSuccess<LoginForm>(LoginForm(fields: fields));
  }

  /// `loginUi` as a decoded list: literal JSON, or the output of its script.
  Future<ParseResult<Object?>> _documentOf(
    String raw, {
    required BookSource source,
    required Map<String, String> loginInfo,
    required String bookName,
    required String bookUrl,
  }) async {
    final ({String? script, String? literal}) split = _splitScript(raw);
    final String? literal = split.literal;
    if (literal != null) {
      return _decode(literal);
    }

    final ParseResult<Object?> evaluated = await _evaluate(
      script: '${loginScriptOf(source)}\n${split.script ?? ''}',
      rulePath: 'loginUi',
      source: source,
      loginInfo: loginInfo,
      bookName: bookName,
      bookUrl: bookUrl,
    );

    return switch (evaluated) {
      // 脚本可能直接给出数组，也可能给出数组的 JSON 文本（上游两种源都有）。
      ParseSuccess<Object?>(:final Object? data) => switch (data) {
        final String text => _decode(text),
        final Object? value => ParseSuccess<Object?>(value),
      },
      ParseFailure<Object?>(:final ParseFailureKind kind) => failureAt<Object?>(
        kind: kind,
        rulePath: 'loginUi',
      ),
    };
  }

  /// One row as a field, or `null` when it is unusable.
  Future<LoginField?> _fieldOf(
    Map<String, Object?> row, {
    required BookSource source,
    required Map<String, String> loginInfo,
    required String bookName,
    required String bookUrl,
  }) async {
    final String name = _text(row['name']);
    if (name.isEmpty) {
      return null;
    }

    final LoginFieldType type = _typeOf(_text(row['type']));
    final String title = await _titleOf(
      row,
      name: name,
      source: source,
      loginInfo: loginInfo,
      bookName: bookName,
      bookUrl: bookUrl,
    );

    return LoginField(
      name: name,
      title: title,
      type: type,
      options: <String>[
        for (final Object? option
            in row['chars'] is List<Object?>
                ? row['chars']! as List<Object?>
                : const <Object?>[])
          if (option != null) '$option',
      ],
      initialValue: _text(row['default']).isEmpty
          ? (loginInfo[name] ?? '')
          : _text(row['default']),
      action: type == LoginFieldType.button ? _text(row['action']) : null,
    );
  }

  /// The row's title: `'literal'`, a script, or the name.
  Future<String> _titleOf(
    Map<String, Object?> row, {
    required String name,
    required BookSource source,
    required Map<String, String> loginInfo,
    required String bookName,
    required String bookUrl,
  }) async {
    final String viewName = _text(row['viewName']);
    if (viewName.isEmpty) {
      return name;
    }
    // 上游：引号包起来的是字面量，其余当脚本求值（`SourceLoginViewModel.resolveTitle`）。
    if (viewName.length >= 2 &&
        viewName.startsWith("'") &&
        viewName.endsWith("'")) {
      return viewName.substring(1, viewName.length - 1);
    }

    final ParseResult<Object?> title = await _evaluate(
      script: '${loginScriptOf(source)}\n$viewName',
      rulePath: 'loginUi.viewName',
      source: source,
      loginInfo: loginInfo,
      bookName: bookName,
      bookUrl: bookUrl,
    );
    final String? resolved = switch (title) {
      ParseSuccess<Object?>(:final Object? data) => data?.toString(),
      ParseFailure<Object?>() => null,
    };

    return resolved == null || resolved.isEmpty ? name : resolved;
  }

  /// Runs one script with the login info as `result` and the source in scope.
  Future<ParseResult<Object?>> _evaluate({
    required String script,
    required String rulePath,
    required BookSource source,
    required Map<String, String> loginInfo,
    required String bookName,
    required String bookUrl,
  }) => _js.evaluate(
    JsJob(
      script: script,
      rulePath: rulePath,
      baseUrl: source.url,
      page: 1,
      source: source.jsSourceInfo,
      bookName: bookName.isEmpty ? null : bookName,
      book: JsBookInfo(name: bookName, bookUrl: bookUrl),
      // 登录表单的脚本读 `result`（上游把 loginInfo 绑在 result 上）。
      result: loginInfo,
      // 也让 `source.getLoginInfo()` / `getLoginInfoMap()` 读得到同一份快照（ADR-0072 §决策 3）。
      loginInfo: loginInfo,
    ),
  );

  /// Splits `@js:` / `<js>…</js>` off a field; anything else is a literal.
  ({String? script, String? literal}) _splitScript(String raw) {
    final String text = raw.trim();
    if (text.startsWith('@js:')) {
      return (script: text.substring(4), literal: null);
    }
    if (text.startsWith('<js>')) {
      final int end = text.lastIndexOf('<');
      return (
        script: text.substring(4, end <= 4 ? text.length : end),
        literal: null,
      );
    }
    // `loginUrl` 也可能是一段裸 JS（上游 `getLoginJs()` 直接返回原文）；对 `loginUi` 来说，
    // 能解析成 JSON 的才是字面量，否则按脚本处理。
    return (script: text, literal: _isJson(text) ? text : null);
  }

  bool _isJson(String text) => text.startsWith('[') || text.startsWith('{');

  ParseResult<Object?> _decode(String text) {
    try {
      return ParseSuccess<Object?>(jsonDecode(text));
    } on FormatException {
      _logger.warning('loginUi is not JSON');

      return failureAt<Object?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'loginUi',
      );
    }
  }

  LoginFieldType _typeOf(String type) => switch (type) {
    'password' => LoginFieldType.password,
    'toggle' => LoginFieldType.toggle,
    'select' => LoginFieldType.select,
    'button' => LoginFieldType.button,
    // 上游缺省就是 text；看不懂的也退到它，没有理由藏掉一栏。
    _ => LoginFieldType.text,
  };

  String _text(Object? value) => value is String ? value : '';
}
