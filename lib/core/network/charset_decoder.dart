import 'dart:convert';
import 'dart:typed_data';

import 'package:betto_charset_detector/betto_charset_detector.dart';
import 'package:charset/charset.dart';
import 'package:enough_convert/big5.dart' show Big5Codec;

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

/// A response body decoded by [decodeBody].
final class DecodedBody {
  /// Creates a decoded body.
  const DecodedBody({
    required this.text,
    required this.charset,
    required this.malformedByteCount,
    this.isDetected = false,
  });

  /// The decoded text.
  final String text;

  /// The charset the body was decoded with: the **declared** label when the page
  /// declared one (ADR-0031), otherwise the label byte detection chose.
  final String charset;

  /// Whether [charset] came from **byte detection** rather than from a declaration.
  ///
  /// It is what tells a caller whether [charset] is worth caching (`book-source.md` §5
  /// caches the detection result per book source and URL, so the second request for the
  /// same page does not sniff again). A declared label is free to read on every response
  /// — the header and the 2 KB meta scan cost nothing next to the detector — so it is
  /// never cached and always wins.
  final bool isDetected;

  /// How many U+FFFD replacements the decode inserted, i.e. how much of the byte stream
  /// was illegal for [charset]. `0` means the strict decode succeeded.
  ///
  /// A truncated multi-byte sequence collapses into one replacement, so this counts
  /// **replacements**, each of which stands for at least one illegal byte; it is what the
  /// mandatory warning of ADR-0031 §决策 2 reports.
  final int malformedByteCount;

  /// Whether the decode had to replace illegal bytes (ADR-0031).
  ///
  /// True means the page still decoded and is usable, but the caller has to record it:
  /// a silent replacement is exactly what C-NET-3 forbids.
  bool get toleratedMalformedBytes => malformedByteCount > 0;
}

/// Decodes [bytes] using the charset that `docs/dev/book-source.md` §5 selects.
///
/// The order is: the `charset` parameter of [contentType], then an HTML
/// `<meta>` declaration, then byte detection with `betto_charset_detector`. A
/// label that no decoder knows falls back to UTF-8, which is that section's last
/// step; detection itself never fails, so the fallback only triggers for an
/// unknown declaration.
///
/// Throws [FormatException] when the bytes are invalid for the chosen charset **and**
/// that charset was not declared. For the two declared lanes — `Content-Type` and
/// `<meta>` — it retries tolerantly and reports that through
/// [DecodedBody.toleratedMalformedBytes] instead (ADR-0031): a real page with one bad
/// byte out of a hundred thousand must not cost the whole book, while a **sniffed**
/// charset stays strict, because there “the encoding was guessed wrong” and “the bytes
/// are broken” cannot be told apart and replacing bytes would silently produce garbage.
///
/// Big5 pages cannot be decoded at all: neither the detector nor the decoder
/// knows that family, which is recorded as a known gap in
/// `docs/dev/book-source.md` §5.1.
///
/// [sniffedCharset] is the label a **previous** request for the same book source and URL
/// detected (`book-source.md` §5). When the page declares nothing it replaces the sniff,
/// which is the expensive step; a declaration still wins over it, exactly as it does over
/// a fresh sniff, so the two decoding lanes of ADR-0031 cannot change because of a cache.
///
/// [declaredCharset] is the label the **book source** declared for this request
/// (`url,{“charset”:“gbk”}`, `book-source.md` §4.3). It comes first: the source author
/// knows the site, and a GBK-era site routinely serves no `Content-Type` charset and a
/// `<meta>` the detector reads wrong. Because it is a declaration, it uses the tolerant lane
/// of ADR-0031 (a stray byte is reported, not fatal), unlike the sniff lane.
DecodedBody decodeBody(
  List<int> bytes, {
  String? contentType,
  String? sniffedCharset,
  String? declaredCharset,
}) {
  final String? declared =
      _normalizeLabel(declaredCharset) ??
      _charsetFromContentType(contentType) ??
      _charsetFromMeta(bytes);

  // 声明优先：服务端显式说了编码就用它，没说才去嗅探（book-source.md §5 的顺序）。
  if (declared == null) {
    final String detected =
        sniffedCharset ?? detectCharset(Uint8List.fromList(bytes));

    return DecodedBody(
      text: _decodeWith(detected, bytes),
      charset: detected,
      malformedByteCount: 0,
      isDetected: true,
    );
  }

  try {
    return DecodedBody(
      text: _decodeWith(declared, bytes),
      charset: declared,
      malformedByteCount: 0,
    );
  } on FormatException {
    final String? tolerant = _decodeTolerantly(declared, bytes);
    if (tolerant == null) {
      rethrow;
    }

    return DecodedBody(
      text: tolerant,
      charset: declared,
      malformedByteCount: _replacementsIn(tolerant),
    );
  }
}

/// The number of U+FFFD replacements [text] carries (ADR-0031 §决策 2).
int _replacementsIn(String text) => '\uFFFD'.allMatches(text).length;

/// [label] trimmed and lower-cased, or `null` when it names nothing.
///
/// A URL rule writes its encoding as free text (`url,{“charset”:“GBK”}`); the decoder's
/// lookup is case-insensitive, but an empty string would otherwise win over the response's
/// own declaration and force the fallback lane.
String? _normalizeLabel(String? label) {
  final String trimmed = label?.trim().toLowerCase() ?? '';

  return trimmed.isEmpty ? null : trimmed;
}

/// The labels `charset` does not know but `enough_convert` does (ADR-0048).
///
/// Big5 is the one family `charset 2.0.1` ships no decoder for, and real collections do contain
/// Traditional-Chinese sources. `big5-hkscs` is decoded with the same table: the HKSCS extension
///区 falls back to U+FFFD, which is the registered partial support (`book-source.md` §5.1).
const Set<String> _big5Labels = <String>{
  'big5',
  'big5-hkscs',
  'cp950',
  'csbig5',
};

/// The decoder for [label], or `null` when no codec knows it.
///
/// `charset` stays the primary source (it covers UTF-8/16/32, the GBK family, latin-1/2/15,
/// windows-1252, shift-jis, euc-jp/kr, us-ascii), and `enough_convert` only fills the Big5 hole.
/// Keeping the two lookups in one function is what makes the strict and tolerant lanes agree on
/// which labels are decodable at all.
Encoding? _encodingOf(String label) {
  final Encoding? known = Charset.getByName(label);
  if (known != null) {
    return known;
  }

  return _big5Labels.contains(label) ? const Big5Codec() : null;
}

/// Decodes [bytes] with [label], falling back to UTF-8 for unknown labels.
String _decodeWith(String label, List<int> bytes) =>
    (_encodingOf(label) ?? utf8).decode(bytes);

/// Decodes [bytes] with the declared [label], replacing malformed sequences, or
/// returns `null` when that label has no reachable tolerant path.
///
/// `dart:convert`'s [Encoding] interface has no `allowMalformed` switch, so the tolerant
/// path exists only on the concrete codec. Two of the labels `book-source.md` §5.1
/// supports have a reachable one, and both were **measured** (2026-10-12,
/// `charset 2.0.1`) to insert U+FFFD without dropping or shifting the following bytes —
/// which is what `book-source.md` §5 requires:
///
/// * `utf-8`: `Utf8Decoder(allowMalformed: true)`;
/// * `gbk`: `GbkCodec(allowMalformed: true)` (`[0xCC,0xEC,0x81]` → `天�`, the 0x81 replaced).
///
/// The other families cannot be listed, for measured reasons:
///
/// * the single-byte codecs (`latin1` family, `windows-1252`) map every byte, so they
///   never reach this path;
/// * `euc-kr`'s decoder never fails — it drops invalid bytes silently — so there is no
///   failure to tolerate;
/// * `shift-jis` and `euc-jp` raise a `RangeError` on a stray lead byte instead of a
///   `FormatException` (`shift_jis.dart:26`), so this path is unreachable for them and
///   catching the `Error` is forbidden (ADR-0022). The escape is registered in
///   `docs/dev/roadmap.md` §3.7;
/// * `us-ascii` / `utf-16` / `utf-32` are left out on purpose: a page that declares them
///   and then fails to decode has a wrong declaration, not a stray byte, and per
///   ADR-0031 §决策 3 those keep failing loudly.
String? _decodeTolerantly(String label, List<int> bytes) => switch (_encodingOf(
  label,
)) {
  final Utf8Codec _ => const Utf8Decoder(allowMalformed: true).convert(bytes),
  final GbkCodec _ => const GbkCodec(allowMalformed: true).decode(bytes),
  final Big5Codec _ => const Big5Codec(allowInvalid: true).decode(bytes),
  _ => null,
};

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
