import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Names whose values must never reach a log (ADR-0006 §5).
///
/// Used for header redaction, for the free-form message safety net and for
/// path-segment masking. `user` and `pass` cover URL userinfo credentials
/// (`https://user:pass@host/…`).
///
/// The order below is for readability only: the regex engine tries the
/// alternatives at every position and the matched name is kept in the
/// replacement, so `x-token=1` is masked either way. Do not reorder this list
/// expecting a behaviour change.
const List<String> _sensitiveKeys = <String>[
  'authorization',
  'proxy-authorization',
  'set-cookie',
  'cookie',
  'access_token',
  'refresh_token',
  'x-auth-token',
  'x-api-key',
  'x-token',
  'api_key',
  'api-key',
  'apikey',
  'signature',
  'password',
  'passwd',
  'secret',
  'token',
  'auth',
  'user',
  'pass',
  'key',
  'sign',
  'pwd',
];

/// Mask written in place of a redacted value.
const String _mask = '***';

/// Matches an authentication scheme followed by its credential.
///
/// `Authorization: Bearer eyJ…` carries no `=` or `:`, so the assignment rule
/// below would mask only the scheme word and leave the credential in the log.
final RegExp _authScheme = RegExp(
  r'\b(bearer|basic)\s+\S+',
  caseSensitive: false,
);

/// Matches `<sensitive name><separator><value>` in free-form text.
///
/// Separators cover `name=value`, `"name": "value"` and path forms such as
/// `/token/abc123`, because a raw URL interpolated into a message is the most
/// common way a secret escapes (C-SEC-4). The value swallows slashes on purpose
/// and stops at `@`, so over-masking the tail of a message is accepted while
/// leaking is not.
final RegExp _sensitiveAssignment = RegExp(
  '(${_sensitiveKeys.join('|')})'
  r'''(["']?\s*[:=/]\s*["']?)([^"'&\s,;}@]+)''',
  caseSensitive: false,
);

/// Returns a copy of [headers] with the values of sensitive headers masked.
///
/// Header names are matched case-insensitively and may carry padding; every
/// other header is copied unchanged.
Map<String, String> redactHeaders(Map<String, String> headers) =>
    <String, String>{
      for (final MapEntry<String, String> header in headers.entries)
        header.key: _isSensitiveKey(header.key) ? _mask : header.value,
    };

/// Returns a log-safe summary of [url].
///
/// Kept: scheme, host, path structure and parameter names, so failures stay
/// locatable (C-ERR-8). Masked: URL userinfo credentials, the value of every
/// path segment that follows a sensitive name (`/token/abc123`) and every query
/// value, because a credential or a keyword may hide in any of them (C-SEC-4).
///
/// Pass [keyword] when [url] was rendered from a search template: Legado
/// templates embed the keyword in the path. Only path segments are searched, so
/// a keyword that also occurs in the host (`com`) can no longer damage it; a
/// blank keyword is ignored.
///
/// Returns `<unparsable-url>` when [url] cannot be parsed; the raw input is
/// never returned, because it may contain a secret.
String redactUrl(String url, {String? keyword}) {
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException {
    return '<unparsable-url>';
  }

  // `queryParameters` **throws** on a value that is not valid percent-encoded UTF-8, and a rule
  // can produce exactly that (a site that encodes the keyword in GBK, a JS template that pastes
  // a raw byte). Logging must never be the thing that fails a request, so an undecodable query is
  // masked pair by pair on the **raw** text instead of being decoded: every value is replaced
  // anyway, so nothing is lost but the crash (C-SEC-4 is still honoured).
  String? maskedQuery;
  try {
    final List<String> names = uri.queryParameters.keys.toList(growable: false);
    maskedQuery = uri.query.isEmpty ? null : _maskQuery(names);
  } on FormatException {
    maskedQuery = uri.query.isEmpty ? null : _maskRawQuery(uri.query);
  }

  return uri
      .replace(
        userInfo: uri.userInfo.isEmpty ? null : _mask,
        pathSegments: _maskPathSegments(uri.pathSegments, keyword),
        query: maskedQuery,
      )
      .toString();
}

/// Returns a log-safe stand-in for a search [keyword].
///
/// Only the length and a truncated SHA-256 digest survive, so logs can still
/// correlate identical searches without recording what the user typed
/// (ADR-0006 §5). Example: `<keyword: 3 chars, sha256=ba7816bf>`.
String describeKeyword(String keyword) => _describe('keyword', keyword);

/// Returns a log-safe stand-in for a page [payload].
///
/// Page bodies must never be logged (C-SEC-4), so only the length and a
/// truncated SHA-256 digest survive. Example:
/// `<payload: 15234 chars, sha256=9f8e7d6c>`.
String describePayload(String payload) => _describe('payload', payload);

/// Returns a log-safe stand-in for [error].
///
/// Exceptions routinely embed the failing URL — query values, userinfo — in
/// their `toString()` (`DioException`, `SocketException`), so logging one
/// verbatim would bypass every other helper here (C-SEC-4). Only the runtime
/// type, the text length and a truncated SHA-256 digest survive, which still
/// correlates identical failures: `<DioException: 152 chars, sha256=9f8e7d6c>`.
///
/// The failure *kind* belongs in the log message (see `ParseFailureKind`), not
/// in the exception text.
String describeError(Object error) {
  final String text = error.toString();

  return '<${error.runtimeType}: ${text.length} chars, sha256=${_digest(text)}>';
}

/// Masks secrets inside a free-form [message].
///
/// This is the safety net that the `AppLogger` facade applies to every message
/// and to every `String` error, covering interpolated strings such as
/// `'GET $url?token=abc failed'`, `'GET https://host/token/abc failed'` and
/// `'Authorization: Bearer abc123'`. Over-masking is acceptable here; leaking
/// is not.
///
/// It cannot recognise a page body or a bare keyword, so callers must still use
/// [describePayload] and [describeKeyword] for those (C-SEC-4).
String redactMessage(String message) => message
    // 先处理认证方案：`Bearer <token>` 没有赋值号，晚处理会把 scheme 掩掉而留下凭据。
    .replaceAllMapped(_authScheme, (Match match) => '${match[1]} $_mask')
    .replaceAllMapped(
      _sensitiveAssignment,
      (Match match) => '${match[1]}${match[2]}$_mask',
    );

/// Returns whether [name] is a value that must not be logged.
bool _isSensitiveKey(String name) =>
    _sensitiveKeys.contains(name.trim().toLowerCase());

/// Masks sensitive path segments and keyword occurrences.
///
/// `/token/abc123/book/1` becomes `/token/***/book/1`; running the message regex
/// over the whole path instead would swallow everything after the secret, and
/// C-ERR-8 wants the remaining path for locating a broken rule.
List<String> _maskPathSegments(List<String> segments, String? keyword) {
  final List<String> masked = <String>[];
  for (int index = 0; index < segments.length; index++) {
    final String segment = segments[index];
    if (_isSensitiveKey(segment) && index + 1 < segments.length) {
      masked.add(segment);
      masked.add(_mask);
      // 跳过被掩掉的原值，避免它作为「下一个敏感名」再次参与判断。
      index++;
      continue;
    }
    masked.add(_maskKeyword(segment, keyword));
  }

  return masked;
}

/// Replaces every occurrence of [keyword] inside one path [segment].
///
/// Segments arrive decoded, so the raw keyword matches even when the URL
/// carries it percent-encoded. Only the path is searched: masking the whole URL
/// would also rewrite the host (`com` → `example.***`) and destroy the very
/// locator C-ERR-8 asks for.
String _maskKeyword(String segment, String? keyword) =>
    keyword == null || keyword.trim().isEmpty
    ? segment
    : segment.replaceAll(keyword, _mask);

/// Builds `<name>=***&<name>=***` from [names], preserving the parameter names.
String _maskQuery(Iterable<String> names) => names
    .map((String name) => '${Uri.encodeQueryComponent(name)}=$_mask')
    .join('&');

/// [_maskQuery] for a query whose percent-encoding cannot be decoded.
///
/// `name=value` pairs are split on the raw text, so a malformed byte can no longer throw on the
/// way to the mask; a pair without `=` keeps its name and is otherwise masked whole.
String _maskRawQuery(String rawQuery) => rawQuery
    .split('&')
    .map((String pair) {
      final int equals = pair.indexOf('=');
      if (equals < 0) {
        return _mask;
      }
      return '${pair.substring(0, equals)}=$_mask';
    })
    .join('&');

/// Builds the `<label: N chars, sha256=xxxxxxxx>` summary.
String _describe(String label, String text) =>
    '<$label: ${text.length} chars, sha256=${_digest(text)}>';

/// Returns the first eight hex characters of the SHA-256 digest of [text].
String _digest(String text) =>
    sha256.convert(utf8.encode(text)).toString().substring(0, 8);
