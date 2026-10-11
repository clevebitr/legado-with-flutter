import 'dart:convert';
import 'dart:typed_data';

import 'package:betto_charset_detector/betto_charset_detector.dart';
import 'package:charset/charset.dart';

/// Number of leading bytes scanned for an HTML `<meta>` charset declaration.
///
/// The declaration must sit in `<head>`, so scanning the whole body would only
/// waste time on large pages (`docs/dev/book-source.md` §5).
const int metaScanLimit = 2048;

/// Matches `<meta charset=…>` and the `charset=…` inside a `<meta>` content
/// attribute; both spellings are common in the wild.
final RegExp _metaCharset = RegExp(
  r'''<meta[^>]+charset\s*=\s*["']?([^"'>/\s;]+)''',
  caseSensitive: false,
);

/// Matches the `charset` parameter of a `Content-Type` header value.
final RegExp _charsetParameter = RegExp(
  r'''charset\s*=\s*["']?([^"';\s]+)''',
  caseSensitive: false,
);

/// Decodes [bytes] using the charset that `docs/dev/book-source.md` §5 selects.
///
/// The order is: the `charset` parameter of [contentType], then an HTML
/// `<meta>` declaration, then byte detection with `betto_charset_detector`. A
/// label that no decoder knows falls back to UTF-8, which is that section's last
/// step; detection itself never fails, so the fallback only triggers for an
/// unknown declaration.
///
/// Throws [FormatException] when the bytes are invalid for the chosen charset.
/// Callers map that to `ParseFailureKind.encodingFailed` and must not hide it
/// behind `allowMalformed` (C-NET-3).
///
/// Big5 pages cannot be decoded at all: neither the detector nor the decoder
/// knows that family, which is recorded as a known gap in
/// `docs/dev/book-source.md` §5.1.
String decodeBody(List<int> bytes, {String? contentType}) {
  final String? declared =
      _charsetFromContentType(contentType) ?? _charsetFromMeta(bytes);

  // 声明优先：服务端显式说了编码就用它，没说才去嗅探（book-source.md §5 的顺序）。
  return declared == null
      ? _decodeWith(detectCharset(Uint8List.fromList(bytes)), bytes)
      : _decodeWith(declared, bytes);
}

/// Decodes [bytes] with [label], falling back to UTF-8 for unknown labels.
String _decodeWith(String label, List<int> bytes) =>
    (Charset.getByName(label) ?? utf8).decode(bytes);

/// Extracts the `charset` parameter from a `Content-Type` header value.
String? _charsetFromContentType(String? contentType) => contentType == null
    ? null
    : _charsetParameter.firstMatch(contentType)?.group(1);

/// Reads an HTML `<meta>` charset declaration from the head of [bytes].
///
/// The head is decoded as latin1 because that mapping never fails and keeps
/// ASCII markup intact, so the regex can run without guessing an encoding first.
String? _charsetFromMeta(List<int> bytes) {
  final List<int> head = bytes.length <= metaScanLimit
      ? bytes
      : bytes.sublist(0, metaScanLimit);

  return _metaCharset.firstMatch(latin1.decode(head))?.group(1);
}
