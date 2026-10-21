import 'dart:convert';

import 'package:flutter_reader/core/logging/app_logger.dart';

/// Characters upstream's `URLEncoder` leaves alone.
///
/// `NetworkUtils.notNeedEncodingForm` allows exactly `[a-zA-Z0-9*._-]` plus valid
/// `%XX` escapes, and that set is what decides whether a value is already encoded.
final RegExp _formSafe = RegExp(r'[A-Za-z0-9*._-]');

/// A two-digit hexadecimal escape body, e.g. the `20` of `%20`.
final RegExp _hexPair = RegExp(r'^[0-9A-Fa-f]{2}$');

/// One `{{name}}` placeholder of a URL template.
final RegExp _placeholder = RegExp(r'\{\{([^{}]*)\}\}');

/// The placeholder whose value is the search keyword.
///
/// Its value is the only one that gets form-encoded; `page` and `baseUrl` are
/// inserted as they are (`docs/dev/book-source.md` §4).
const String _keywordVariable = 'key';

/// Renders a Legado URL template, e.g. `/search?q={{key}}&page={{page}}`
/// (C-SRC-5).
///
/// [params] carries the **raw** values: `key` is the raw search keyword and is
/// form-encoded here, exactly once. A keyword that is already encoded (only
/// `[A-Za-z0-9*._-]` and valid `%XX` escapes) is passed through untouched, so the
/// caller must not encode it beforehand either — that is the "encode once, never
/// twice" rule of `docs/dev/book-source.md` §4, which upstream implements as
/// `AnalyzeUrl.appendEncoded` + `NetworkUtils.encodedForm`.
///
/// Well-known names: `key`, `page`, `baseUrl`. A placeholder that [params] does not
/// define renders as an **empty string** and is reported through [logger] as a
/// warning, so `{{...}}` never leaks into a request. Nested rules inside `{{}}`
/// (matrix #18) are M1 and are therefore treated as undefined variables for now;
/// `docs/dev/roadmap.md` records that boundary.
///
/// The warning deliberately names only the variables, never the template: the
/// template may already carry the keyword, and a search keyword must not reach the
/// logs (C-ERR-8, C-SEC-4).
String renderUrlTemplate(
  String template,
  Map<String, String> params, {
  required AppLogger logger,
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

    return name == _keywordVariable ? _encodeFormValue(value) : value;
  });

  if (unresolved.isNotEmpty) {
    logger.warning(
      'Unresolved URL template variables: ${unresolved.join(', ')}',
    );
  }

  return rendered;
}

/// Resolves [url] against the page it was found on (`docs/dev/book-source.md` §4).
///
/// A relative target (`/book/1`, `2.html`) becomes absolute, so the next stage can
/// request it; an already absolute URL is returned unchanged. A value that cannot be
/// parsed is returned as it is instead of throwing, because a malformed rule output
/// is a data problem the caller reports, not a crash (C-ERR-1).
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
/// Only `[A-Za-z0-9*._-]` stay raw, a space becomes `+`, and every other character
/// is percent-encoded from its UTF-8 bytes with upper-case hex. A `+` is encoded
/// again (`%2B`), which upstream does as well, because its already-encoded check
/// does not accept `+`; callers therefore pass the raw keyword.
String _encodeFormValue(String value) {
  if (_isFormEncoded(value)) {
    return value;
  }

  final StringBuffer buffer = StringBuffer();
  for (final int byte in utf8.encode(value)) {
    if (byte == 0x20) {
      buffer.write('+');
    } else if (_formSafe.hasMatch(String.fromCharCode(byte))) {
      buffer.write(String.fromCharCode(byte));
    } else {
      buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }

  return buffer.toString();
}

/// Whether [value] is already form-encoded, mirroring upstream `encodedForm`.
///
/// True when every character is either `[A-Za-z0-9*._-]` or part of a valid `%XX`
/// escape; anything else means the value still has to be encoded.
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
