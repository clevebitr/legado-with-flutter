import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/text/charset_encoding.dart';

/// Characters upstream's `URLEncoder` leaves alone.
final RegExp _formSafe = RegExp(r'[A-Za-z0-9*._-]');

/// A two-digit hexadecimal escape body, e.g. the `20` of `%20`.
final RegExp _hexPair = RegExp(r'^[0-9A-Fa-f]{2}$');

/// One `{{name}}` placeholder of a URL template.
final RegExp _placeholder = RegExp(r'\{\{([^{}]*)\}\}');

/// Upstream's page list: `<1,2,3>` picks the entry for the page being fetched
/// (`AnalyzeUrl.pagePattern`, `:777`).
final RegExp _pageList = RegExp(r'<(.*?)>');

/// The characters a **query** may keep as-is when it is already encoded.
///
/// Upstream's `NetworkUtils.notNeedEncodingQuery` (`:64-79`): letters, digits and
/// `!$&()*+,-./:;=?@[]^_`{|}~`. `%` is handled by the escape check, not by the set.
const String _querySafe = r'!$&()*+,-./:;=?@[\]^_`{|}~';

/// The characters `AnalyzeUrl.encodeQueryParams` writes raw when it has to encode a query.
///
/// Upstream's set (`AnalyzeUrl.kt:779-782`) — the same as [_querySafe] plus `%`, `_`, `.` and
/// `-`; `#`, space and anything non-ASCII are always escaped.
const String _queryEncoderSafe = r'_.-~!$%&()*+,/:;=?@[\]^`{|}';

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
  int? page,
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

  return renderPageList(rendered, page);
}

/// Replaces every `<a,b,c>` page list in [url] with the entry for [page].
///
/// Upstream reads the list as `,`-separated entries and answers the `page`-th one — the **last**
/// entry when the page is past the end (`AnalyzeUrl.kt:203-213`). A `null` page leaves the URL
/// alone: the substitution only happens on a real page request.
///
/// The substitution runs **after** `{{…}}` (upstream's `replaceKeyPageJs` order: inner rules, then
/// the page list), and a rule's own JavaScript runs before both (`analyzeJs`).
String renderPageList(String url, int? page) {
  if (page == null || page < 1 || !url.contains('<')) {
    return url;
  }

  return url.replaceAllMapped(_pageList, (Match match) {
    final List<String> pages = (match.group(1) ?? '').split(',');
    final int index = page < pages.length ? page - 1 : pages.length - 1;

    return pages[index].trim();
  });
}

/// Percent-encodes a GET query the way upstream does when the rule declares a `charset`.
///
/// A declared `charset` means「this site reads its parameters in GBK」, which is why the **whole**
/// query is escaped — not only `{{key}}` — and why an already-encoded query is left alone
/// (`AnalyzeUrl.analyzeQuery` → `encodeParams` / `NetworkUtils.encodedQuery`).
///
/// `escape` is upstream's other dialect (`EncoderUtils.escape`, `%20` for a space); it is **not**
/// modelled (`book-source.md` §4.3), so the URL is answered unchanged and the keyword keeps the
/// form-encoded path.
String encodeUrlQuery(String url, String? charset) {
  if (charset == null || charset.trim().isEmpty) {
    return url;
  }
  if (charset.trim().toLowerCase() == 'escape') {
    return url;
  }
  final int mark = url.indexOf('?');
  if (mark < 0 || mark == url.length - 1) {
    return url;
  }
  final String query = url.substring(mark + 1);
  if (_isQueryEncoded(query)) {
    return url;
  }

  return '${url.substring(0, mark + 1)}${_encodeQuery(query, charset.trim())}';
}

/// Whether [query] already consists of safe characters and valid `%XX` escapes.
bool _isQueryEncoded(String query) {
  var index = 0;
  while (index < query.length) {
    final String character = query[index];
    if (_isSafeQueryCharacter(character)) {
      index++;
      continue;
    }
    if (character == '%' &&
        index + 2 < query.length &&
        _hexPair.hasMatch(query.substring(index + 1, index + 3))) {
      index += 3;
      continue;
    }

    return false;
  }

  return true;
}

String _encodeQuery(String query, String charset) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in query.runes) {
    final String character = String.fromCharCode(rune);
    if (rune < 0x80 && _isSafeQueryEncoderCharacter(character)) {
      buffer.write(character);
      continue;
    }
    for (final int byte in charsetBytes(character, charset: charset)) {
      buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }

  return buffer.toString();
}

bool _isSafeQueryCharacter(String character) {
  final int code = character.codeUnitAt(0);

  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A) ||
      _querySafe.contains(character);
}

bool _isSafeQueryEncoderCharacter(String character) {
  final int code = character.codeUnitAt(0);

  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A) ||
      _queryEncoderSafe.contains(character);
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
