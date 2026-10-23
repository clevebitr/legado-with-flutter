import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// The HTTP verb a URL rule asks for.
enum UrlRequestMethod {
  /// A plain GET, which is what a bare URL template means.
  get,

  /// A POST with the suffix's `body` as the payload.
  post,
}

/// The options a Legado URL rule may append after its URL, `url,{…}`.
///
/// Only the fields this repository can honour are modelled; the rest are recorded in
/// [unsupported] so a caller can warn about them.
final class UrlRuleOptions {
  /// Creates an option set.
  const UrlRuleOptions({
    this.method = UrlRequestMethod.get,
    this.body,
    this.charset,
    this.headers = const <String, String>{},
    this.unsupported = const <String>[],
  });

  /// The verb the rule asks for.
  final UrlRequestMethod method;

  /// The raw request body, with its `{{…}}` templates still in place.
  final String? body;

  /// The charset declared for this request, e.g. `gbk`.
  ///
  /// It applies both to keyword encoding and to response decoding.
  final String? charset;

  /// Headers the option adds to this request on top of the source's own `header`.
  final Map<String, String> headers;

  /// Option fields this repository cannot honour, e.g. `webJs` / `retry`.
  final List<String> unsupported;
}

/// One parsed URL rule: the URL template plus its optional suffix.
final class UrlRule {
  /// Creates a parsed rule.
  const UrlRule({required this.template, this.options});

  /// The URL part, with its `{{…}}` templates untouched.
  final String template;

  /// The parsed `,{…}` suffix, or `null` when the rule has none.
  final UrlRuleOptions? options;
}

/// Matches the separator of a URL rule's option suffix, `,{`.
final RegExp _optionSeparator = RegExp(r'\s*,\s*(?=\{)');

/// The index in [rule] where the URL ends and the `,{…}` suffix begins, or `-1`.
///
/// A candidate is only accepted when a balanced object ends the rule, so a comma inside the
/// address is not mistaken for options.
int _optionSplitOf(String rule) {
  for (final RegExpMatch match in _optionSeparator.allMatches(rule)) {
    final int brace = rule.indexOf('{', match.start);
    if (brace < 0 || rule.startsWith('{{', brace)) {
      continue;
    }
    final String suffix = rule.substring(brace).trimRight();
    if (!suffix.startsWith('{') || !suffix.endsWith('}')) {
      continue;
    }

    return match.start;
  }

  return -1;
}

/// Splits [rule] into its URL part and its option suffix, and parses the suffix.
///
/// The suffix dialect is not strict JSON: single quotes, unquoted keys, trailing commas and
/// `{{…}}` templates are all accepted. An unreadable suffix is reported as
/// [ParseFailureKind.unsupportedRule] rather than silently truncated.
ParseResult<UrlRule> parseUrlRule(String rule, {required String rulePath}) {
  final int split = _optionSplitOf(rule);
  if (split < 0) {
    return ParseSuccess<UrlRule>(UrlRule(template: rule));
  }

  final String template = rule.substring(0, split).trimRight();
  // `_optionSplitOf` 只在后面跟着一个以 `}` 收尾的对象时才报位置。
  final String suffix = rule.substring(rule.indexOf('{', split)).trim();

  final _OptionScanner scanner = _OptionScanner(suffix);
  final _OptionNode node;
  try {
    node = scanner.parseDocument();
  } on FormatException {
    return failureAt<UrlRule>(
      kind: ParseFailureKind.unsupportedRule,
      rulePath: 'unsupported:url-options',
    );
  }

  return ParseSuccess<UrlRule>(
    UrlRule(template: template, options: _optionsOf(node)),
  );
}

/// Reads the modelled fields out of the parsed suffix object.
UrlRuleOptions _optionsOf(_OptionNode node) {
  final Map<String, _OptionNode> members = node.members ?? const {};
  final List<String> unsupported = <String>[];

  final String? methodText = members['method']?.text?.trim().toUpperCase();
  final UrlRequestMethod method = switch (methodText) {
    'POST' => UrlRequestMethod.post,
    null || 'GET' => UrlRequestMethod.get,
    _ => UrlRequestMethod.get,
  };
  if (methodText != null && methodText != 'GET' && methodText != 'POST') {
    // `HEAD` 等动词本仓没有消费方：按 GET 发并留痕，而不是整条源判死。
    unsupported.add('method:$methodText');
  }

  final String? charset = members['charset']?.text?.trim();
  final String? body = members['body']?.raw;
  final Map<String, String> headers = <String, String>{};
  final _OptionNode? headerNode = members['headers'];
  if (headerNode != null) {
    final Map<String, _OptionNode>? direct = headerNode.members;
    final Map<String, _OptionNode>? nested = direct == null
        ? _parseLooseObjectOrNull(headerNode.text)
        : null;
    final Map<String, _OptionNode> pairs = direct ?? nested ?? const {};
    for (final MapEntry<String, _OptionNode> entry in pairs.entries) {
      final String? value = entry.value.text;
      if (value != null) {
        headers[entry.key] = value;
      }
    }
    if (pairs.isEmpty && headerNode.text != null) {
      unsupported.add('headers');
    }
  }

  for (final MapEntry<String, _OptionNode> entry in members.entries) {
    const Set<String> modelled = <String>{
      'method',
      'body',
      'charset',
      'headers',
    };
    if (!modelled.contains(entry.key) && entry.value.raw.trim().isNotEmpty) {
      // `webView` / `webJs` / `retry` / `origin` / `type` / `js`：本仓没有对应实现。
      unsupported.add(entry.key);
    }
  }
  if (body != null && method == UrlRequestMethod.get) {
    // 上游也只在 POST 时用 body，GET 时丢掉。
    unsupported.add('body');
  }

  return UrlRuleOptions(
    method: method,
    body: method == UrlRequestMethod.post ? _bodyTextOf(members['body']) : null,
    charset: charset == null || charset.isEmpty ? null : charset,
    headers: headers,
    unsupported: unsupported,
  );
}

/// The body a POST sends: a quoted string as written, a JSON object as its source text.
String? _bodyTextOf(_OptionNode? node) {
  if (node == null) {
    return null;
  }

  return node.text ?? node.raw;
}

/// A parsed value of the option suffix.
final class _OptionNode {
  const _OptionNode({required this.raw, this.text, this.members});

  /// The source text of the value, exactly as written.
  final String raw;

  /// The decoded value when it is a scalar that has one.
  final String? text;

  /// The members of an object value.
  final Map<String, _OptionNode>? members;
}

/// Reads [text] as a loose option object, or answers `null` when it is not one.
///
/// `headers` is written both as an object and as a string holding one in real exports, so
/// both forms are understood.
Map<String, _OptionNode>? _parseLooseObjectOrNull(String? text) {
  final String source = text?.trim() ?? '';
  if (!source.startsWith('{')) {
    return null;
  }
  try {
    return _OptionScanner(source).parseDocument().members;
  } on FormatException {
    return null;
  }
}

/// A tolerant scanner for the option suffix.
///
/// Besides what GSON's lenient mode accepts, it keeps a `{{…}}` template as a raw token so a
/// body like `{"keyword":{{key}}}` survives.
final class _OptionScanner {
  _OptionScanner(this._source);

  final String _source;
  int _index = 0;

  _OptionNode parseDocument() {
    final _OptionNode value = _parseValue();
    _skipWhitespace();
    if (_index < _source.length) {
      throw const FormatException('Trailing characters in URL options');
    }

    return value;
  }

  _OptionNode _parseValue() {
    _skipWhitespace();
    if (_index >= _source.length) {
      throw const FormatException('Unexpected end of URL options');
    }
    final String char = _source[_index];
    if (char == '{') {
      if (_peek(1) == '{') {
        return _parseTemplate();
      }

      return _parseObject();
    }
    if (char == '[') {
      return _parseUntilBalanced('[', ']');
    }
    if (char == '"' || char == "'") {
      return _parseString();
    }

    return _parseBare();
  }

  _OptionNode _parseObject() {
    final int start = _index;
    _index++; // {
    final Map<String, _OptionNode> members = <String, _OptionNode>{};
    while (true) {
      _skipWhitespace();
      if (_index >= _source.length) {
        throw const FormatException('Unterminated object in URL options');
      }
      if (_source[_index] == '}') {
        _index++;

        return _OptionNode(
          raw: _source.substring(start, _index),
          members: members,
        );
      }
      final String key = _parseKey();
      _skipWhitespace();
      if (_index >= _source.length || _source[_index] != ':') {
        throw const FormatException('Missing ":" in URL options');
      }
      _index++;
      members[key] = _parseValue();
      _skipWhitespace();
      if (_index < _source.length && _source[_index] == ',') {
        _index++;
      }
    }
  }

  String _parseKey() {
    _skipWhitespace();
    if (_index >= _source.length) {
      throw const FormatException('Missing key in URL options');
    }
    final String char = _source[_index];
    if (char == '"' || char == "'") {
      final _OptionNode key = _parseString();

      return key.text ?? '';
    }
    final int start = _index;
    while (_index < _source.length &&
        !',:{}[]"\' \t\r\n'.contains(_source[_index])) {
      _index++;
    }
    if (start == _index) {
      throw const FormatException('Empty key in URL options');
    }

    return _source.substring(start, _index);
  }

  _OptionNode _parseString() {
    final String quote = _source[_index];
    final int start = _index;
    _index++;
    final StringBuffer buffer = StringBuffer();
    while (true) {
      if (_index >= _source.length) {
        throw const FormatException('Unterminated string in URL options');
      }
      final String char = _source[_index];
      if (char == r'\') {
        if (_index + 1 >= _source.length) {
          throw const FormatException('Dangling escape in URL options');
        }
        buffer.write(_unescape(_source[_index + 1]));
        _index += 2;
        continue;
      }
      if (char == quote) {
        _index++;

        return _OptionNode(
          raw: _source.substring(start, _index),
          text: buffer.toString(),
        );
      }
      buffer.write(char);
      _index++;
    }
  }

  // `{{…}}` 是模板不是 JSON，原样保留。
  _OptionNode _parseTemplate() {
    final int start = _index;
    final int end = _source.indexOf('}}', _index);
    if (end < 0) {
      throw const FormatException('Unterminated template in URL options');
    }
    _index = end + 2;

    return _OptionNode(raw: _source.substring(start, _index));
  }

  _OptionNode _parseUntilBalanced(String open, String close) {
    final int start = _index;
    var depth = 0;
    var inString = false;
    var quote = '';
    while (_index < _source.length) {
      final String char = _source[_index];
      if (inString) {
        if (char == r'\') {
          _index += 2;
          continue;
        }
        if (char == quote) {
          inString = false;
        }
      } else if (char == '"' || char == "'") {
        inString = true;
        quote = char;
      } else if (char == open) {
        depth++;
      } else if (char == close) {
        depth--;
        if (depth == 0) {
          _index++;

          return _OptionNode(raw: _source.substring(start, _index));
        }
      }
      _index++;
    }
    throw const FormatException('Unbalanced value in URL options');
  }

  _OptionNode _parseBare() {
    final int start = _index;
    while (_index < _source.length && !',}]\r\n'.contains(_source[_index])) {
      _index++;
    }
    final String raw = _source.substring(start, _index).trim();

    return _OptionNode(raw: raw, text: raw);
  }

  String? _peek(int offset) =>
      _index + offset < _source.length ? _source[_index + offset] : null;

  void _skipWhitespace() {
    while (_index < _source.length && ' \t\r\n'.contains(_source[_index])) {
      _index++;
    }
  }

  String _unescape(String char) => switch (char) {
    'n' => '\n',
    'r' => '\r',
    't' => '\t',
    _ => char,
  };
}

/// Resolves the URL part of [rule] against [baseUrl], keeping any `,{…}` suffix verbatim.
///
/// Resolving the whole rule would percent-encode the braces and turn the suffix into part of
/// the request path.
String resolveUrlRule(String rule, String baseUrl) {
  final int split = _optionSplitOf(rule);
  if (split < 0) {
    return resolveAbsoluteUrl(rule, baseUrl);
  }
  final String template = rule.substring(0, split).trimRight();
  final String suffix = rule.substring(split);

  return '${resolveAbsoluteUrl(template, baseUrl)}$suffix';
}

/// The URL part of [rule] when its option suffix cannot be read, or [rule] unchanged.
String stripUnreadableUrlOptions(String rule) {
  final int split = _optionSplitOf(rule);

  return split < 0 ? rule : rule.substring(0, split).trimRight();
}
