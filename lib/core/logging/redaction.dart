import 'dart:convert';

import 'package:crypto/crypto.dart';

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

const String _mask = '***';

// `Bearer <token>` 没有赋值号，只靠赋值规则会留下凭据。
final RegExp _authScheme = RegExp(
  r'\b(bearer|basic)\s+\S+',
  caseSensitive: false,
);

// 值故意吞掉斜杠并止于 `@`：宁可多掩，也不能漏掉 `/token/abc123` 这类路径形式。
final RegExp _sensitiveAssignment = RegExp(
  '(${_sensitiveKeys.join('|')})'
  r'''(["']?\s*[:=/]\s*["']?)([^"'&\s,;}@]+)''',
  caseSensitive: false,
);

/// Returns a copy of [headers] with the values of sensitive headers masked.
Map<String, String> redactHeaders(Map<String, String> headers) =>
    <String, String>{
      for (final MapEntry<String, String> header in headers.entries)
        header.key: _isSensitiveKey(header.key) ? _mask : header.value,
    };

/// Returns a log-safe form of [url].
///
/// Keeps the scheme, host, path structure and parameter names; masks userinfo,
/// values of sensitive path segments and every query value.
String redactUrl(String url, {String? keyword}) {
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException {
    return '<unparsable-url>';
  }

  // queryParameters 遇到非法百分号编码会抛异常；日志不能因此失败，改为在原始文本上逐对掩码。
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

/// Returns a log-safe stand-in for a search [keyword]: length and digest only.
String describeKeyword(String keyword) => _describe('keyword', keyword);

/// Returns a log-safe stand-in for a page [payload]: length and digest only.
String describePayload(String payload) => _describe('payload', payload);

/// Returns a log-safe stand-in for [error]: type, text length and digest only.
String describeError(Object error) {
  final String text = error.toString();

  return '<${error.runtimeType}: ${text.length} chars, sha256=${_digest(text)}>';
}

/// Masks secrets that appear in a free-form [message].
String redactMessage(String message) => message
    // 先处理认证方案，否则只掩掉 scheme 而把凭据留在日志里。
    .replaceAllMapped(_authScheme, (Match match) => '${match[1]} $_mask')
    .replaceAllMapped(
      _sensitiveAssignment,
      (Match match) => '${match[1]}${match[2]}$_mask',
    );

bool _isSensitiveKey(String name) =>
    _sensitiveKeys.contains(name.trim().toLowerCase());

// 只掩敏感名后的一段；整条路径套用消息正则会把后面的内容一起吞掉。
List<String> _maskPathSegments(List<String> segments, String? keyword) {
  final List<String> masked = <String>[];
  for (int index = 0; index < segments.length; index++) {
    final String segment = segments[index];
    if (_isSensitiveKey(segment) && index + 1 < segments.length) {
      masked.add(segment);
      masked.add(_mask);
      // 跳过被掩掉的原值，避免它作为下一个敏感名再次参与判断。
      index++;
      continue;
    }
    masked.add(_maskKeyword(segment, keyword));
  }

  return masked;
}

// 只搜索路径段：整条 URL 会连域名一起改写，反而破坏定位信息。
String _maskKeyword(String segment, String? keyword) =>
    keyword == null || keyword.trim().isEmpty
    ? segment
    : segment.replaceAll(keyword, _mask);

String _maskQuery(Iterable<String> names) => names
    .map((String name) => '${Uri.encodeQueryComponent(name)}=$_mask')
    .join('&');

// 无法解码的 query 在原始文本上按 `&` 拆分，避免掩码过程中再次抛异常。
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

String _describe(String label, String text) =>
    '<$label: ${text.length} chars, sha256=${_digest(text)}>';

String _digest(String text) =>
    sha256.convert(utf8.encode(text)).toString().substring(0, 8);
