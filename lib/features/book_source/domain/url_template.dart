import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/text/charset_encoding.dart';

/// Characters upstream's `URLEncoder` leaves alone.
final RegExp _formSafe = RegExp(r'[A-Za-z0-9*._-]');

/// A two-digit hexadecimal escape body, e.g. the `20` of `%20`.
final RegExp _hexPair = RegExp(r'^[0-9A-Fa-f]{2}$');

/// One `{{name}}` placeholder of a URL template.
final RegExp _placeholder = RegExp(r'\{\{([^{}]*)\}\}');

/// The placeholder whose value is the search keyword.
const String _keywordVariable = 'key';

/// Renders a Legado URL template such as `/search?q={{key}}&page={{page}}`.
///
/// [params] carries raw values: `key` is form-encoded exactly once, and a value that is
/// already encoded is kept as is. An undefined placeholder renders empty and is reported
/// through [logger] by name only, never with the template.
String renderUrlTemplate(
  String template,
  Map<String, String> params, {
  required AppLogger logger,
  String? charset,
}) {
  final List<String> unresolved = <String>[];

  final String rendered = template.replaceAllMapped(_placeholder, (
    Match match,
  ) {
    final String name = (match.group(1) ?? '').trim();
    final String? value = params[name];

    if (value == null) {
      unresolved.add(name);

      return '';
    }

    return name == _keywordVariable ? _encodeFormValue(value, charset) : value;
  });

  if (unresolved.isNotEmpty) {
    logger.warning(
      'Unresolved URL template variables: ${unresolved.join(', ')}',
    );
  }

  return rendered;
}

/// Resolves [url] against the page it was found on.
///
/// An unparsable value is returned unchanged instead of throwing.
String resolveAbsoluteUrl(String url, String baseUrl) {
  final Uri? reference = Uri.tryParse(url);
  final Uri? base = Uri.tryParse(baseUrl);
  if (reference == null || base == null) {
    return url;
  }

  return base.resolveUri(reference).toString();
}

/// [resolveAbsoluteUrl] for an optional value, or `null` when it is absent or empty.
String? resolveAbsoluteUrlOrNull(String? url, String baseUrl) =>
    url == null || url.isEmpty ? null : resolveAbsoluteUrl(url, baseUrl);

/// Form-encodes [value] the way upstream does (`URLEncoder.encode`).
///
/// Only `[A-Za-z0-9*._-]` stay raw, a space becomes `+`, and everything else is escaped
/// from its [charset] bytes — an unknown label falls back to UTF-8.
String _encodeFormValue(String value, [String? charset]) {
  if (_isFormEncoded(value)) {
    return value;
  }

  final StringBuffer buffer = StringBuffer();
  for (final int rune in value.runes) {
    final String character = String.fromCharCode(rune);
    if (rune < 0x80 && _formSafe.hasMatch(character)) {
      buffer.write(character);
      continue;
    }
    if (rune == 0x20) {
      buffer.write('+');
      continue;
    }
    // 逐字符编码：一个字符在声明编码里可能是 1–4 字节。
    for (final int byte in charsetBytes(character, charset: charset)) {
      buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }

  return buffer.toString();
}

/// Whether [value] is already form-encoded.
///
/// True when every character is a safe character or part of a valid `%XX` escape.
bool _isFormEncoded(String value) {
  var index = 0;
  while (index < value.length) {
    if (_formSafe.hasMatch(value[index])) {
      index++;
      continue;
    }
    if (value[index] == '%' &&
        index + 2 < value.length &&
        _hexPair.hasMatch(value.substring(index + 1, index + 3))) {
      index += 3;
      continue;
    }

    return false;
  }

  return true;
}
